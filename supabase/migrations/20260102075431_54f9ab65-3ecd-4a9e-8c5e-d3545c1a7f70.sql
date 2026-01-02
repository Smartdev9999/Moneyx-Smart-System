-- Create trade_history table for storing complete trading history
CREATE TABLE public.trade_history (
    id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    mt5_account_id UUID NOT NULL REFERENCES public.mt5_accounts(id) ON DELETE CASCADE,
    deal_ticket BIGINT NOT NULL,
    order_ticket BIGINT,
    symbol TEXT NOT NULL,
    deal_type TEXT NOT NULL, -- 'buy', 'sell', 'balance', 'credit', etc.
    entry_type TEXT NOT NULL, -- 'in', 'out', 'inout'
    volume NUMERIC DEFAULT 0,
    open_price NUMERIC DEFAULT 0,
    close_price NUMERIC,
    sl NUMERIC,
    tp NUMERIC,
    profit NUMERIC DEFAULT 0,
    swap NUMERIC DEFAULT 0,
    commission NUMERIC DEFAULT 0,
    comment TEXT,
    open_time TIMESTAMP WITH TIME ZONE,
    close_time TIMESTAMP WITH TIME ZONE,
    magic_number INTEGER,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    UNIQUE(mt5_account_id, deal_ticket)
);

-- Enable RLS
ALTER TABLE public.trade_history ENABLE ROW LEVEL SECURITY;

-- Create policies for admin access
CREATE POLICY "Admins can manage trade_history" 
ON public.trade_history 
FOR ALL 
USING (is_admin(auth.uid()));

CREATE POLICY "Admins can view trade_history" 
ON public.trade_history 
FOR SELECT 
USING (is_admin(auth.uid()));

-- Create index for faster queries
CREATE INDEX idx_trade_history_mt5_account ON public.trade_history(mt5_account_id);
CREATE INDEX idx_trade_history_close_time ON public.trade_history(close_time DESC);
CREATE INDEX idx_trade_history_deal_ticket ON public.trade_history(deal_ticket);

-- Add initial_balance and initial_deposit columns to mt5_accounts for portfolio tracking
ALTER TABLE public.mt5_accounts 
ADD COLUMN IF NOT EXISTS initial_balance NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_deposit NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_withdrawal NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS max_drawdown NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS win_trades INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS loss_trades INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS total_trades INTEGER DEFAULT 0;