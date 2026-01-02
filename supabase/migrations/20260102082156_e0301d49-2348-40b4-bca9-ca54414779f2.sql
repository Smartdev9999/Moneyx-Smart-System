-- Add ea_status column to track EA running status
ALTER TABLE public.mt5_accounts 
ADD COLUMN IF NOT EXISTS ea_status TEXT DEFAULT 'offline';

-- Add comment for documentation
COMMENT ON COLUMN public.mt5_accounts.ea_status IS 'Current EA status: working, paused, suspended, expired, invalid, offline';