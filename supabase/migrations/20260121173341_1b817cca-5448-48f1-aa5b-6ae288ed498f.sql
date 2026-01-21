-- Add currency column to mt5_accounts for auto-detection of USD/USC accounts
ALTER TABLE mt5_accounts 
ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'USD';

COMMENT ON COLUMN mt5_accounts.currency IS 
'Account currency from MT5: USD, USC (US Cent), EUR, etc.';