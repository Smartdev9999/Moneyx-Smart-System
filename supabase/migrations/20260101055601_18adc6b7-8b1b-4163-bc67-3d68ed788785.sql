-- Fix function search path warnings
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_customer_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  next_id INT;
BEGIN
  SELECT COALESCE(MAX(CAST(SUBSTRING(customer_id FROM 4) AS INTEGER)), 0) + 1
  INTO next_id
  FROM public.customers;
  
  NEW.customer_id := 'MX-' || LPAD(next_id::TEXT, 5, '0');
  RETURN NEW;
END;
$$;