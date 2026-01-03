-- Create table for storing candle history from EA
CREATE TABLE public.ai_candle_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  symbol TEXT NOT NULL,
  timeframe TEXT NOT NULL,
  candle_time TIMESTAMPTZ NOT NULL,
  open_price NUMERIC NOT NULL,
  high_price NUMERIC NOT NULL,
  low_price NUMERIC NOT NULL,
  close_price NUMERIC NOT NULL,
  volume BIGINT DEFAULT 0,
  recorded_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(symbol, timeframe, candle_time)
);

-- Create index for fast queries
CREATE INDEX idx_candle_symbol_timeframe_time ON public.ai_candle_history(symbol, timeframe, candle_time DESC);

-- Create table for storing indicator history
CREATE TABLE public.ai_indicator_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  symbol TEXT NOT NULL,
  timeframe TEXT NOT NULL,
  candle_time TIMESTAMPTZ NOT NULL,
  rsi NUMERIC,
  macd_main NUMERIC,
  macd_signal NUMERIC,
  macd_histogram NUMERIC,
  ema20 NUMERIC,
  ema50 NUMERIC,
  atr NUMERIC,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(symbol, timeframe, candle_time)
);

-- Create index for indicator queries
CREATE INDEX idx_indicator_symbol_timeframe_time ON public.ai_indicator_history(symbol, timeframe, candle_time DESC);

-- Enable RLS on both tables
ALTER TABLE public.ai_candle_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_indicator_history ENABLE ROW LEVEL SECURITY;

-- Allow public read access for dashboard
CREATE POLICY "Public can read candle history" ON public.ai_candle_history
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage candle history" ON public.ai_candle_history
  FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Public can read indicator history" ON public.ai_indicator_history
  FOR SELECT USING (true);

CREATE POLICY "Service role can manage indicator history" ON public.ai_indicator_history
  FOR ALL USING (true) WITH CHECK (true);

-- Enable realtime for live updates
ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_analysis_cache;

-- Create cleanup function for old candle data (keep 500 candles per symbol/timeframe)
CREATE OR REPLACE FUNCTION public.cleanup_old_candle_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM ai_candle_history
  WHERE id IN (
    SELECT id FROM (
      SELECT id, ROW_NUMBER() OVER (
        PARTITION BY symbol, timeframe 
        ORDER BY candle_time DESC
      ) as rn
      FROM ai_candle_history
    ) ranked
    WHERE rn > 500
  );
  
  DELETE FROM ai_indicator_history
  WHERE id IN (
    SELECT id FROM (
      SELECT id, ROW_NUMBER() OVER (
        PARTITION BY symbol, timeframe 
        ORDER BY candle_time DESC
      ) as rn
      FROM ai_indicator_history
    ) ranked
    WHERE rn > 500
  );
END;
$$;