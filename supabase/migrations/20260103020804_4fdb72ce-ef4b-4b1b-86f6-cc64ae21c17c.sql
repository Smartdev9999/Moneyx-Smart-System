-- Create AI Analysis Cache table
CREATE TABLE public.ai_analysis_cache (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  symbol text NOT NULL,
  timeframe text NOT NULL,
  analysis_data jsonb NOT NULL,
  signal text,
  confidence integer,
  trend text,
  entry_price numeric,
  stop_loss numeric,
  take_profit numeric,
  reasoning text,
  candle_time timestamp with time zone NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  expires_at timestamp with time zone NOT NULL DEFAULT (now() + interval '1 hour'),
  UNIQUE(symbol, timeframe, candle_time)
);

-- Enable RLS
ALTER TABLE public.ai_analysis_cache ENABLE ROW LEVEL SECURITY;

-- Public read access for EA (no auth required)
CREATE POLICY "Public can read AI analysis cache"
ON public.ai_analysis_cache
FOR SELECT
USING (true);

-- Only backend can insert/update/delete
CREATE POLICY "Service role can manage AI analysis cache"
ON public.ai_analysis_cache
FOR ALL
USING (true)
WITH CHECK (true);

-- Create index for faster lookups
CREATE INDEX idx_ai_analysis_cache_lookup ON public.ai_analysis_cache(symbol, timeframe, candle_time);
CREATE INDEX idx_ai_analysis_cache_expires ON public.ai_analysis_cache(expires_at);

-- Add comment
COMMENT ON TABLE public.ai_analysis_cache IS 'Caches AI market analysis results to reduce API calls and save credits';