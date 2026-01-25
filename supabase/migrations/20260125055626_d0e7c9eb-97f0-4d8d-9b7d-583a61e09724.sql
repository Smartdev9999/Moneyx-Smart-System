-- Add account_type column to mt5_accounts table for Real/Demo separation
ALTER TABLE mt5_accounts
ADD COLUMN account_type text DEFAULT 'real' 
  CHECK (account_type IN ('demo', 'real', 'contest'));

COMMENT ON COLUMN mt5_accounts.account_type IS 'Account type from MT5: demo, real, or contest';