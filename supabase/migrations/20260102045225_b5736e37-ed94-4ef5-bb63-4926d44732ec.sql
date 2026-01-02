-- 1. Add new columns to mt5_accounts for real-time trading data
ALTER TABLE mt5_accounts 
  ADD COLUMN IF NOT EXISTS open_orders integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS floating_pl numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_profit numeric DEFAULT 0;

-- 2. Create account_summary table for daily summaries (data retention)
CREATE TABLE IF NOT EXISTS public.account_summary (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mt5_account_id uuid NOT NULL,
  summary_date date NOT NULL,
  avg_balance numeric DEFAULT 0,
  avg_equity numeric DEFAULT 0,
  max_balance numeric DEFAULT 0,
  min_balance numeric DEFAULT 0,
  total_profit numeric DEFAULT 0,
  avg_drawdown numeric DEFAULT 0,
  sync_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  UNIQUE(mt5_account_id, summary_date)
);

-- 3. Enable RLS on account_summary
ALTER TABLE public.account_summary ENABLE ROW LEVEL SECURITY;

-- 4. RLS policies for account_summary (admin only)
CREATE POLICY "Admins can view account_summary" 
  ON public.account_summary FOR SELECT 
  USING (is_admin(auth.uid()));

CREATE POLICY "Admins can manage account_summary" 
  ON public.account_summary FOR ALL 
  USING (is_admin(auth.uid()));

-- 5. Add CASCADE DELETE constraints
-- First drop existing constraints if they exist, then recreate with CASCADE
ALTER TABLE account_history 
  DROP CONSTRAINT IF EXISTS account_history_mt5_account_id_fkey;

ALTER TABLE account_history 
  ADD CONSTRAINT account_history_mt5_account_id_fkey 
  FOREIGN KEY (mt5_account_id) REFERENCES mt5_accounts(id) ON DELETE CASCADE;

ALTER TABLE mt5_accounts 
  DROP CONSTRAINT IF EXISTS mt5_accounts_customer_id_fkey;

ALTER TABLE mt5_accounts 
  ADD CONSTRAINT mt5_accounts_customer_id_fkey 
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE;

-- 6. Add foreign key for account_summary with CASCADE
ALTER TABLE account_summary 
  ADD CONSTRAINT account_summary_mt5_account_id_fkey 
  FOREIGN KEY (mt5_account_id) REFERENCES mt5_accounts(id) ON DELETE CASCADE;

-- 7. Create cleanup function for data retention (60 days)
CREATE OR REPLACE FUNCTION public.cleanup_old_history()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cutoff_date timestamptz := now() - interval '60 days';
BEGIN
  -- 1. Summarize old data into daily summaries
  INSERT INTO account_summary (
    mt5_account_id, summary_date, 
    avg_balance, avg_equity, max_balance, min_balance,
    total_profit, avg_drawdown, sync_count
  )
  SELECT 
    mt5_account_id,
    DATE(recorded_at) as summary_date,
    AVG(balance),
    AVG(equity),
    MAX(balance),
    MIN(balance),
    AVG(profit_loss),
    AVG(drawdown),
    COUNT(*)
  FROM account_history
  WHERE recorded_at < cutoff_date
  GROUP BY mt5_account_id, DATE(recorded_at)
  ON CONFLICT (mt5_account_id, summary_date) DO NOTHING;

  -- 2. Delete detailed history older than 60 days
  DELETE FROM account_history 
  WHERE recorded_at < cutoff_date;
END;
$$;