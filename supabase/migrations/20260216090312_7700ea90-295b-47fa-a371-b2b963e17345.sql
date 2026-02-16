
-- Create tracked_ea_sessions table
CREATE TABLE public.tracked_ea_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  session_name text NOT NULL,
  ea_magic_number integer NOT NULL DEFAULT 0,
  broker text,
  account_number text,
  symbols text[] DEFAULT '{}',
  timeframe text,
  start_time timestamptz DEFAULT now(),
  end_time timestamptz,
  total_orders integer DEFAULT 0,
  strategy_summary text,
  strategy_prompt text,
  generated_ea_code text,
  status text NOT NULL DEFAULT 'tracking',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Create tracked_orders table
CREATE TABLE public.tracked_orders (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id uuid NOT NULL REFERENCES public.tracked_ea_sessions(id) ON DELETE CASCADE,
  ticket bigint NOT NULL,
  magic_number integer,
  symbol text NOT NULL,
  order_type text NOT NULL,
  volume numeric DEFAULT 0,
  open_price numeric DEFAULT 0,
  close_price numeric,
  sl numeric,
  tp numeric,
  profit numeric DEFAULT 0,
  swap numeric DEFAULT 0,
  commission numeric DEFAULT 0,
  open_time timestamptz,
  close_time timestamptz,
  comment text,
  holding_time_seconds integer DEFAULT 0,
  market_data jsonb DEFAULT '{}',
  event_type text NOT NULL DEFAULT 'open',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Create unique constraint for upsert (session_id + ticket + event_type)
CREATE UNIQUE INDEX idx_tracked_orders_upsert ON public.tracked_orders (session_id, ticket, event_type);

-- Enable RLS
ALTER TABLE public.tracked_ea_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracked_orders ENABLE ROW LEVEL SECURITY;

-- RLS: Developers and Admins can do everything on tracked_ea_sessions
CREATE POLICY "Developers can manage tracked_ea_sessions"
ON public.tracked_ea_sessions FOR ALL
TO authenticated
USING (
  has_role(auth.uid(), 'developer') OR is_admin(auth.uid())
)
WITH CHECK (
  has_role(auth.uid(), 'developer') OR is_admin(auth.uid())
);

-- RLS: Developers and Admins can do everything on tracked_orders
CREATE POLICY "Developers can manage tracked_orders"
ON public.tracked_orders FOR ALL
TO authenticated
USING (
  has_role(auth.uid(), 'developer') OR is_admin(auth.uid())
)
WITH CHECK (
  has_role(auth.uid(), 'developer') OR is_admin(auth.uid())
);

-- RLS: Service role (edge functions) can manage both tables
CREATE POLICY "Service role can manage tracked_ea_sessions"
ON public.tracked_ea_sessions FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Service role can manage tracked_orders"
ON public.tracked_orders FOR ALL
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');
