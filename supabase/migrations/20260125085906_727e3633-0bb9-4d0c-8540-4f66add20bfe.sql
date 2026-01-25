-- First: Add 'customer' to app_role enum only
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'customer';