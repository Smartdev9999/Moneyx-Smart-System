
-- Add last_heartbeat column to tracked_ea_sessions
ALTER TABLE public.tracked_ea_sessions
ADD COLUMN last_heartbeat timestamp with time zone;

-- Enable realtime for tracked_orders table
ALTER PUBLICATION supabase_realtime ADD TABLE public.tracked_orders;
