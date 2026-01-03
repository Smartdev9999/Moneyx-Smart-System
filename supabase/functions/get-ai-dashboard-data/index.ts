import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface DashboardRequest {
  symbols?: string[];
  timeframe?: string;
  candle_limit?: number;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    const requestData: DashboardRequest = req.method === 'POST' 
      ? await req.json() 
      : {};
    
    const symbols = requestData.symbols || ['XAUUSD', 'EURUSD', 'GBPUSD', 'USDJPY', 'AUDUSD'];
    const rawTimeframe = requestData.timeframe || 'H1';
    const candleLimit = requestData.candle_limit || 100;

    // Normalize timeframe: EA sends PERIOD_H1, dashboard expects H1
    // Support both formats when querying
    const timeframesToQuery = [
      rawTimeframe,
      rawTimeframe.startsWith('PERIOD_') ? rawTimeframe.replace('PERIOD_', '') : `PERIOD_${rawTimeframe}`,
    ];
    const timeframe = rawTimeframe; // For response

    console.log('[AI Dashboard] Fetching data for symbols:', symbols.join(', '));

    // Fetch latest analysis for all symbols (try both timeframe formats)
    console.log('[AI Dashboard] Querying with timeframes:', timeframesToQuery.join(', '));
    
    const { data: analysisData, error: analysisError } = await supabase
      .from('ai_analysis_cache')
      .select('*')
      .in('symbol', symbols)
      .in('timeframe', timeframesToQuery)
      .order('created_at', { ascending: false });

    if (analysisError) {
      console.error('[AI Dashboard] Error fetching analysis:', analysisError);
      throw analysisError;
    }
    
    console.log('[AI Dashboard] Found', (analysisData || []).length, 'analysis records');

    // Get unique latest analysis per symbol
    const latestAnalysis: Record<string, any> = {};
    for (const analysis of analysisData || []) {
      if (!latestAnalysis[analysis.symbol]) {
        latestAnalysis[analysis.symbol] = analysis;
      }
    }

    // Fetch candle history for each symbol (try both timeframe formats)
    const candleDataBySymbol: Record<string, any[]> = {};
    
    for (const symbol of symbols) {
      const { data: candles, error: candleError } = await supabase
        .from('ai_candle_history')
        .select('*')
        .eq('symbol', symbol)
        .in('timeframe', timeframesToQuery)
        .order('candle_time', { ascending: false })
        .limit(candleLimit);

      if (candleError) {
        console.error(`[AI Dashboard] Error fetching candles for ${symbol}:`, candleError);
      } else {
        // Reverse to chronological order
        candleDataBySymbol[symbol] = (candles || []).reverse();
      }
    }

    // Fetch indicator history for each symbol (try both timeframe formats)
    const indicatorDataBySymbol: Record<string, any[]> = {};
    
    for (const symbol of symbols) {
      const { data: indicators, error: indicatorError } = await supabase
        .from('ai_indicator_history')
        .select('*')
        .eq('symbol', symbol)
        .in('timeframe', timeframesToQuery)
        .order('candle_time', { ascending: false })
        .limit(candleLimit);

      if (indicatorError) {
        console.error(`[AI Dashboard] Error fetching indicators for ${symbol}:`, indicatorError);
      } else {
        indicatorDataBySymbol[symbol] = (indicators || []).reverse();
      }
    }

    // Build response for each symbol
    const pairData = symbols.map(symbol => {
      const analysis = latestAnalysis[symbol] || null;
      const candles = candleDataBySymbol[symbol] || [];
      const indicators = indicatorDataBySymbol[symbol] || [];

      return {
        symbol,
        timeframe,
        analysis: analysis ? {
          bullish_probability: analysis.bullish_probability,
          bearish_probability: analysis.bearish_probability,
          sideways_probability: analysis.sideways_probability,
          dominant_bias: analysis.dominant_bias,
          threshold_met: analysis.threshold_met,
          market_structure: analysis.market_structure,
          trend_h4: analysis.trend_h4,
          trend_daily: analysis.trend_daily,
          key_levels: analysis.key_levels,
          patterns: analysis.patterns,
          reasoning: analysis.reasoning,
          recommendation: getRecommendation(analysis.dominant_bias, analysis.threshold_met),
          created_at: analysis.created_at,
          expires_at: analysis.expires_at,
          candle_time: analysis.candle_time,
        } : null,
        candles: candles.map(c => ({
          time: c.candle_time,
          open: parseFloat(c.open_price),
          high: parseFloat(c.high_price),
          low: parseFloat(c.low_price),
          close: parseFloat(c.close_price),
          volume: c.volume || 0,
        })),
        indicators: indicators.map(i => ({
          time: i.candle_time,
          rsi: i.rsi ? parseFloat(i.rsi) : null,
          macd_main: i.macd_main ? parseFloat(i.macd_main) : null,
          macd_signal: i.macd_signal ? parseFloat(i.macd_signal) : null,
          macd_histogram: i.macd_histogram ? parseFloat(i.macd_histogram) : null,
          ema20: i.ema20 ? parseFloat(i.ema20) : null,
          ema50: i.ema50 ? parseFloat(i.ema50) : null,
          atr: i.atr ? parseFloat(i.atr) : null,
        })),
        candle_count: candles.length,
        has_data: candles.length > 0,
      };
    });

    // Calculate overall statistics
    const pairsWithAnalysis = pairData.filter(p => p.analysis);
    const avgBullish = pairsWithAnalysis.length > 0
      ? pairsWithAnalysis.reduce((sum, p) => sum + (p.analysis?.bullish_probability || 0), 0) / pairsWithAnalysis.length
      : 0;
    const avgBearish = pairsWithAnalysis.length > 0
      ? pairsWithAnalysis.reduce((sum, p) => sum + (p.analysis?.bearish_probability || 0), 0) / pairsWithAnalysis.length
      : 0;
    
    let overallBias = 'sideways';
    if (avgBullish > avgBearish + 10) overallBias = 'bullish';
    else if (avgBearish > avgBullish + 10) overallBias = 'bearish';

    const tradablePairs = pairsWithAnalysis.filter(p => p.analysis?.threshold_met).length;

    const response = {
      success: true,
      timestamp: new Date().toISOString(),
      timeframe,
      pairs: pairData,
      summary: {
        total_pairs: symbols.length,
        pairs_with_analysis: pairsWithAnalysis.length,
        pairs_with_data: pairData.filter(p => p.has_data).length,
        tradable_pairs: tradablePairs,
        overall_bias: overallBias,
        avg_bullish: Math.round(avgBullish),
        avg_bearish: Math.round(avgBearish),
        avg_sideways: Math.round(100 - avgBullish - avgBearish),
      },
    };

    console.log('[AI Dashboard] Returning data for', pairData.length, 'pairs');

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('[AI Dashboard] Error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

function getRecommendation(dominantBias: string, thresholdMet: boolean): string {
  if (!thresholdMet) return 'No Trade';
  if (dominantBias === 'bullish') return 'Only LONG';
  if (dominantBias === 'bearish') return 'Only SHORT';
  return 'No Trade';
}
