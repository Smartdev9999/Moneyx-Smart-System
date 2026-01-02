-- Allow users (including developers) to read their own role row
-- This is required so the client can determine where to redirect after login.

DO $$
BEGIN
  -- Ensure RLS is enabled (no-op if already enabled)
  EXECUTE 'ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY';
EXCEPTION WHEN others THEN
  -- ignore
END $$;

DROP POLICY IF EXISTS "Users can view own role" ON public.user_roles;
CREATE POLICY "Users can view own role"
ON public.user_roles
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);
