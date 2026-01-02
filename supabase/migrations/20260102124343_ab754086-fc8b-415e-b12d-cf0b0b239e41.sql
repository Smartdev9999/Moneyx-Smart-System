-- Allow admins/super_admins to view all user profiles for User Management
-- Note: is_admin() already returns true for both 'admin' and 'super_admin'

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
      AND policyname = 'Admins can view all profiles'
  ) THEN
    CREATE POLICY "Admins can view all profiles"
    ON public.profiles
    FOR SELECT
    USING (public.is_admin(auth.uid()));
  END IF;
END $$;