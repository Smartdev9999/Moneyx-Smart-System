
-- Drop old status check constraint and add new one with 'suspended'
ALTER TABLE mt5_accounts DROP CONSTRAINT IF EXISTS mt5_accounts_status_check;

ALTER TABLE mt5_accounts ADD CONSTRAINT mt5_accounts_status_check 
  CHECK (status = ANY (ARRAY['active'::text, 'expired'::text, 'expiring_soon'::text, 'suspended'::text]));
