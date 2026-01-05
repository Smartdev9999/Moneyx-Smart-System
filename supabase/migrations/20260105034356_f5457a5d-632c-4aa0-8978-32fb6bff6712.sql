-- Create table to cache economic news from Forex Factory
CREATE TABLE IF NOT EXISTS public.economic_news_cache (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  country TEXT NOT NULL,
  event_date TIMESTAMP WITH TIME ZONE NOT NULL,
  impact TEXT NOT NULL CHECK (impact IN ('Low', 'Medium', 'High', 'Holiday')),
  forecast TEXT,
  previous TEXT,
  actual TEXT,
  source TEXT DEFAULT 'forex_factory',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(title, country, event_date)
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_economic_news_date ON public.economic_news_cache(event_date);
CREATE INDEX IF NOT EXISTS idx_economic_news_country ON public.economic_news_cache(country);
CREATE INDEX IF NOT EXISTS idx_economic_news_impact ON public.economic_news_cache(impact);

-- Enable RLS
ALTER TABLE public.economic_news_cache ENABLE ROW LEVEL SECURITY;

-- Allow public read access for EAs
CREATE POLICY "Anyone can read economic news"
  ON public.economic_news_cache
  FOR SELECT
  USING (true);

-- Only service role can insert/update (from edge function)
CREATE POLICY "Service role can manage economic news"
  ON public.economic_news_cache
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Create table to track last update time
CREATE TABLE IF NOT EXISTS public.economic_news_metadata (
  id TEXT PRIMARY KEY DEFAULT 'main',
  last_updated TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  last_source TEXT,
  event_count INT DEFAULT 0,
  error_message TEXT
);

-- Allow public read
ALTER TABLE public.economic_news_metadata ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read news metadata"
  ON public.economic_news_metadata
  FOR SELECT
  USING (true);

CREATE POLICY "Service role can manage news metadata"
  ON public.economic_news_metadata
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Trigger for updated_at
CREATE TRIGGER update_economic_news_updated_at
  BEFORE UPDATE ON public.economic_news_cache
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();