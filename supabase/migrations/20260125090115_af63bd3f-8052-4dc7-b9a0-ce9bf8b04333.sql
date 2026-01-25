-- Create customer_users table to link auth users with customers
CREATE TABLE public.customer_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  approved_by uuid REFERENCES auth.users(id),
  approved_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id),
  UNIQUE(customer_id)
);

-- Enable RLS on customer_users
ALTER TABLE public.customer_users ENABLE ROW LEVEL SECURITY;

-- RLS Policies for customer_users
CREATE POLICY "Users can view own customer_users" ON public.customer_users
FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Admins can manage customer_users" ON public.customer_users
FOR ALL USING (is_admin(auth.uid()));

-- Create is_customer function
CREATE OR REPLACE FUNCTION public.is_customer(_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = 'customer'
  )
$$;

-- Create is_approved_customer function
CREATE OR REPLACE FUNCTION public.is_approved_customer(_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.customer_users
    WHERE user_id = _user_id AND status = 'approved'
  )
$$;

-- Get customer_id for a user
CREATE OR REPLACE FUNCTION public.get_customer_id_for_user(_user_id uuid)
RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT customer_id FROM public.customer_users
  WHERE user_id = _user_id AND status = 'approved'
  LIMIT 1
$$;

-- Add RLS policy for customers to view their own data
CREATE POLICY "Customers can view own customer data" ON public.customers
FOR SELECT USING (
  id = get_customer_id_for_user(auth.uid())
);

-- Add RLS policy for customers to view their own mt5_accounts
CREATE POLICY "Customers can view own mt5_accounts" ON public.mt5_accounts
FOR SELECT USING (
  customer_id = get_customer_id_for_user(auth.uid())
);

-- Add RLS policy for customers to view their own account_history
CREATE POLICY "Customers can view own account_history" ON public.account_history
FOR SELECT USING (
  mt5_account_id IN (
    SELECT id FROM public.mt5_accounts 
    WHERE customer_id = get_customer_id_for_user(auth.uid())
  )
);

-- Add RLS policy for customers to view their own account_summary
CREATE POLICY "Customers can view own account_summary" ON public.account_summary
FOR SELECT USING (
  mt5_account_id IN (
    SELECT id FROM public.mt5_accounts 
    WHERE customer_id = get_customer_id_for_user(auth.uid())
  )
);

-- Add RLS policy for customers to view their own trade_history
CREATE POLICY "Customers can view own trade_history" ON public.trade_history
FOR SELECT USING (
  mt5_account_id IN (
    SELECT id FROM public.mt5_accounts 
    WHERE customer_id = get_customer_id_for_user(auth.uid())
  )
);

-- Fund wallets table
CREATE TABLE public.fund_wallets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  wallet_address text NOT NULL,
  network text NOT NULL CHECK (network IN ('bsc', 'tron')),
  label text,
  is_active boolean DEFAULT true,
  last_sync timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(wallet_address, network)
);

-- Enable RLS on fund_wallets
ALTER TABLE public.fund_wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage fund_wallets" ON public.fund_wallets
FOR ALL USING (is_admin(auth.uid()));

CREATE POLICY "Customers can view own wallets" ON public.fund_wallets
FOR SELECT USING (
  customer_id = get_customer_id_for_user(auth.uid())
);

-- Wallet transactions table
CREATE TABLE public.wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id uuid NOT NULL REFERENCES public.fund_wallets(id) ON DELETE CASCADE,
  tx_hash text NOT NULL,
  tx_type text NOT NULL CHECK (tx_type IN ('in', 'out')),
  amount numeric NOT NULL,
  token_symbol text DEFAULT 'USDT',
  from_address text,
  to_address text,
  block_time timestamptz NOT NULL,
  
  -- Admin classification
  classification text CHECK (classification IN ('fund_deposit', 'fund_withdraw', 'profit_transfer', 'invest_transfer', 'dividend')),
  classified_by uuid REFERENCES auth.users(id),
  classified_at timestamptz,
  target_system_id uuid REFERENCES public.trading_systems(id),
  notes text,
  
  -- Raw data from blockchain
  raw_data jsonb,
  created_at timestamptz DEFAULT now(),
  UNIQUE(tx_hash, wallet_id)
);

-- Enable RLS on wallet_transactions
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage wallet_transactions" ON public.wallet_transactions
FOR ALL USING (is_admin(auth.uid()));

CREATE POLICY "Customers can view own transactions" ON public.wallet_transactions
FOR SELECT USING (
  wallet_id IN (
    SELECT id FROM public.fund_wallets 
    WHERE customer_id = get_customer_id_for_user(auth.uid())
  )
);

-- Fund allocations table
CREATE TABLE public.fund_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  trading_system_id uuid NOT NULL REFERENCES public.trading_systems(id),
  mt5_account_id uuid REFERENCES public.mt5_accounts(id),
  
  allocated_amount numeric NOT NULL DEFAULT 0,
  current_value numeric NOT NULL DEFAULT 0,
  profit_loss numeric NOT NULL DEFAULT 0,
  roi_percent numeric DEFAULT 0,
  
  allocation_date timestamptz DEFAULT now(),
  last_updated timestamptz DEFAULT now(),
  notes text,
  
  UNIQUE(customer_id, trading_system_id)
);

-- Enable RLS on fund_allocations
ALTER TABLE public.fund_allocations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage fund_allocations" ON public.fund_allocations
FOR ALL USING (is_admin(auth.uid()));

CREATE POLICY "Customers can view own allocations" ON public.fund_allocations
FOR SELECT USING (
  customer_id = get_customer_id_for_user(auth.uid())
);

-- Customers can view active trading_systems (for display purposes)
CREATE POLICY "Customers can view trading systems" ON public.trading_systems
FOR SELECT USING (is_customer(auth.uid()) AND is_active = true);

-- Update trigger for customer_users
CREATE TRIGGER update_customer_users_updated_at
BEFORE UPDATE ON public.customer_users
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Update trigger for fund_wallets
CREATE TRIGGER update_fund_wallets_updated_at
BEFORE UPDATE ON public.fund_wallets
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Update trigger for fund_allocations
CREATE TRIGGER update_fund_allocations_updated_at
BEFORE UPDATE ON public.fund_allocations
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();