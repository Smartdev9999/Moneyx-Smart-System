-- Add UPDATE policy for user_roles (Super Admin only)
CREATE POLICY "Super admin can update roles"
ON public.user_roles
FOR UPDATE
USING (has_role(auth.uid(), 'super_admin'::app_role))
WITH CHECK (has_role(auth.uid(), 'super_admin'::app_role));