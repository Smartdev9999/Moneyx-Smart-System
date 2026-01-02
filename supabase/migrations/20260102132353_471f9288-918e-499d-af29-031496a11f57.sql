-- Add RLS policy for developers to view and manage trading systems
CREATE POLICY "Developers can view trading systems"
ON public.trading_systems
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles 
    WHERE user_id = auth.uid() 
    AND role = 'developer'
  ) OR is_admin(auth.uid())
);

CREATE POLICY "Developers can manage trading systems"
ON public.trading_systems
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.user_roles 
    WHERE user_id = auth.uid() 
    AND role = 'developer'
  ) OR is_admin(auth.uid())
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.user_roles 
    WHERE user_id = auth.uid() 
    AND role = 'developer'
  ) OR is_admin(auth.uid())
);