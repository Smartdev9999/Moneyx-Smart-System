-- Add new columns for market bias analysis
ALTER TABLE public.ai_analysis_cache
ADD COLUMN IF NOT EXISTS bullish_probability integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS bearish_probability integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS sideways_probability integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS dominant_bias text,
ADD COLUMN IF NOT EXISTS threshold_met boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS market_structure text,
ADD COLUMN IF NOT EXISTS trend_h4 text,
ADD COLUMN IF NOT EXISTS trend_daily text,
ADD COLUMN IF NOT EXISTS key_levels jsonb,
ADD COLUMN IF NOT EXISTS patterns text;

-- Create index for faster bias lookups
CREATE INDEX IF NOT EXISTS idx_ai_cache_dominant_bias ON public.ai_analysis_cache(dominant_bias);
CREATE INDEX IF NOT EXISTS idx_ai_cache_threshold_met ON public.ai_analysis_cache(threshold_met);