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

interface CandleData {
  time: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

interface IndicatorData {
  time: string;
  ema20: number | null;
  ema50: number | null;
  rsi: number | null;
  macd_main: number | null;
  macd_signal: number | null;
  macd_histogram: number | null;
  atr: number | null;
}

// Aggregate H1 → H4 (combine 4 candles)
function aggregateToH4(h1Candles: CandleData[]): CandleData[] {
  const sorted = [...h1Candles].sort((a, b) => 
    new Date(a.time).getTime() - new Date(b.time).getTime()
  );
  
  const h4Groups = new Map<string, CandleData[]>();
  for (const candle of sorted) {
    const date = new Date(candle.time);
    // H4 periods: 0, 4, 8, 12, 16, 20
    const h4Hour = Math.floor(date.getUTCHours() / 4) * 4;
    const dateStr = date.toISOString().split('T')[0];
    const h4Key = `${dateStr}T${h4Hour.toString().padStart(2, '0')}:00:00.000Z`;
    
    if (!h4Groups.has(h4Key)) h4Groups.set(h4Key, []);
    h4Groups.get(h4Key)!.push(candle);
  }
  
  return Array.from(h4Groups.entries())
    .filter(([_, candles]) => candles.length >= 3) // At least 3 of 4 candles
    .map(([time, candles]) => ({
      time,
      open: candles[0].open,
      high: Math.max(...candles.map(c => c.high)),
      low: Math.min(...candles.map(c => c.low)),
      close: candles[candles.length - 1].close,
      volume: candles.reduce((sum, c) => sum + (c.volume || 0), 0)
    }))
    .sort((a, b) => new Date(a.time).getTime() - new Date(b.time).getTime());
}

// Aggregate H1 → D1 (combine 24 candles)
function aggregateToD1(h1Candles: CandleData[]): CandleData[] {
  const sorted = [...h1Candles].sort((a, b) => 
    new Date(a.time).getTime() - new Date(b.time).getTime()
  );
  
  const d1Groups = new Map<string, CandleData[]>();
  for (const candle of sorted) {
    const date = new Date(candle.time);
    const d1Key = `${date.toISOString().split('T')[0]}T00:00:00.000Z`;
    
    if (!d1Groups.has(d1Key)) d1Groups.set(d1Key, []);
    d1Groups.get(d1Key)!.push(candle);
  }
  
  return Array.from(d1Groups.entries())
    .filter(([_, candles]) => candles.length >= 20) // At least 20 of 24 hours
    .map(([time, candles]) => ({
      time,
      open: candles[0].open,
      high: Math.max(...candles.map(c => c.high)),
      low: Math.min(...candles.map(c => c.low)),
      close: candles[candles.length - 1].close,
      volume: candles.reduce((sum, c) => sum + (c.volume || 0), 0)
    }))
    .sort((a, b) => new Date(a.time).getTime() - new Date(b.time).getTime());
}

// Calculate EMA
function calculateEMA(data: number[], period: number): number[] {
  if (data.length === 0) return [];
  const k = 2 / (period + 1);
  const ema: number[] = [data[0]];
  for (let i = 1; i < data.length; i++) {
    ema.push(data[i] * k + ema[i - 1] * (1 - k));
  }
  return ema;
}

// Calculate RSI
function calculateRSI(closes: number[], period = 14): number[] {
  const rsi: number[] = [];
  for (let i = 0; i < Math.min(period, closes.length); i++) rsi.push(50);
  
  for (let i = period; i < closes.length; i++) {
    let gains = 0, losses = 0;
    for (let j = i - period + 1; j <= i; j++) {
      const change = closes[j] - closes[j - 1];
      if (change > 0) gains += change;
      else losses -= change;
    }
    const avgGain = gains / period;
    const avgLoss = losses / period;
    rsi.push(avgLoss === 0 ? 100 : 100 - (100 / (1 + avgGain / avgLoss)));
  }
  return rsi;
}

// Calculate MACD
function calculateMACD(closes: number[], fast = 12, slow = 26, signal = 9): { main: number[], signal: number[], histogram: number[] } {
  if (closes.length < slow) {
    return { main: [], signal: [], histogram: [] };
  }
  
  const emaFast = calculateEMA(closes, fast);
  const emaSlow = calculateEMA(closes, slow);
  const macdLine = emaFast.map((v, i) => v - emaSlow[i]);
  const signalLine = calculateEMA(macdLine.slice(slow - 1), signal);
  
  // Pad signal line to match length
  const paddedSignal = new Array(slow - 1 + signal - 1).fill(null).concat(signalLine);
  const histogram = macdLine.map((v, i) => paddedSignal[i] !== null ? v - paddedSignal[i] : null);
  
  return { 
    main: macdLine, 
    signal: paddedSignal as number[], 
    histogram: histogram as number[] 
  };
}

// Calculate ATR
function calculateATR(candles: CandleData[], period = 14): number[] {
  if (candles.length < 2) return [];
  
  const tr: number[] = [candles[0].high - candles[0].low];
  for (let i = 1; i < candles.length; i++) {
    const high = candles[i].high;
    const low = candles[i].low;
    const prevClose = candles[i - 1].close;
    tr.push(Math.max(high - low, Math.abs(high - prevClose), Math.abs(low - prevClose)));
  }
  
  return calculateEMA(tr, period);
}

// Calculate all indicators for aggregated candles
function calculateIndicators(candles: CandleData[]): IndicatorData[] {
  const closes = candles.map(c => c.close);
  const ema20 = calculateEMA(closes, 20);
  const ema50 = calculateEMA(closes, 50);
  const rsi = calculateRSI(closes, 14);
  const macd = calculateMACD(closes, 12, 26, 9);
  const atr = calculateATR(candles, 14);
  
  return candles.map((c, i) => ({
    time: c.time,
    ema20: ema20[i] || null,
    ema50: ema50[i] || null,
    rsi: rsi[i] || null,
    macd_main: macd.main[i] || null,
    macd_signal: macd.signal[i] || null,
    macd_histogram: macd.histogram[i] || null,
    atr: atr[i] || null
  }));
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

    // Normalize timeframe
    const normalizedTimeframe = rawTimeframe.replace('PERIOD_', '');
    const isHigherTimeframe = normalizedTimeframe === 'H4' || normalizedTimeframe === 'D1';

    console.log('[AI Dashboard] Fetching data for symbols:', symbols.join(', '), 'timeframe:', normalizedTimeframe);

    // For H4/D1, we need to fetch H1 data for aggregation
    const timeframesToQuery = isHigherTimeframe 
      ? ['H1', 'PERIOD_H1']
      : [rawTimeframe, rawTimeframe.startsWith('PERIOD_') ? rawTimeframe.replace('PERIOD_', '') : `PERIOD_${rawTimeframe}`];

    // Fetch latest analysis for all symbols
    const analysisTimeframesToQuery = [
      rawTimeframe,
      rawTimeframe.startsWith('PERIOD_') ? rawTimeframe.replace('PERIOD_', '') : `PERIOD_${rawTimeframe}`,
    ];
    
    const { data: analysisData, error: analysisError } = await supabase
      .from('ai_analysis_cache')
      .select('*')
      .in('symbol', symbols)
      .in('timeframe', analysisTimeframesToQuery)
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

    // Fetch candle history for each symbol
    const candleDataBySymbol: Record<string, CandleData[]> = {};
    const indicatorDataBySymbol: Record<string, IndicatorData[]> = {};
    const isAggregatedBySymbol: Record<string, boolean> = {};
    
    for (const symbol of symbols) {
      // For higher timeframes, fetch more H1 data to aggregate
      const fetchLimit = isHigherTimeframe ? 720 : candleLimit;
      
      const { data: candles, error: candleError } = await supabase
        .from('ai_candle_history')
        .select('*')
        .eq('symbol', symbol)
        .in('timeframe', timeframesToQuery)
        .order('candle_time', { ascending: false })
        .limit(fetchLimit);

      if (candleError) {
        console.error(`[AI Dashboard] Error fetching candles for ${symbol}:`, candleError);
        continue;
      }

      // Convert to CandleData format
      const formattedCandles: CandleData[] = (candles || [])
        .reverse()
        .map(c => ({
          time: c.candle_time,
          open: parseFloat(c.open_price),
          high: parseFloat(c.high_price),
          low: parseFloat(c.low_price),
          close: parseFloat(c.close_price),
          volume: c.volume || 0
        }));

      // Aggregate if higher timeframe
      if (isHigherTimeframe && formattedCandles.length > 0) {
        const aggregated = normalizedTimeframe === 'D1' 
          ? aggregateToD1(formattedCandles)
          : aggregateToH4(formattedCandles);
        
        candleDataBySymbol[symbol] = aggregated.slice(-candleLimit);
        indicatorDataBySymbol[symbol] = calculateIndicators(aggregated).slice(-candleLimit);
        isAggregatedBySymbol[symbol] = true;
        
        console.log(`[AI Dashboard] ${symbol}: Aggregated ${formattedCandles.length} H1 candles to ${aggregated.length} ${normalizedTimeframe} candles`);
      } else {
        candleDataBySymbol[symbol] = formattedCandles;
        isAggregatedBySymbol[symbol] = false;
        
        // Fetch indicators from database for H1
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
          indicatorDataBySymbol[symbol] = (indicators || []).reverse().map(i => ({
            time: i.candle_time,
            rsi: i.rsi ? parseFloat(i.rsi) : null,
            macd_main: i.macd_main ? parseFloat(i.macd_main) : null,
            macd_signal: i.macd_signal ? parseFloat(i.macd_signal) : null,
            macd_histogram: i.macd_histogram ? parseFloat(i.macd_histogram) : null,
            ema20: i.ema20 ? parseFloat(i.ema20) : null,
            ema50: i.ema50 ? parseFloat(i.ema50) : null,
            atr: i.atr ? parseFloat(i.atr) : null,
          }));
        }
      }
    }

    // Build response for each symbol
    const pairData = symbols.map(symbol => {
      const analysis = latestAnalysis[symbol] || null;
      const candles = candleDataBySymbol[symbol] || [];
      const indicators = indicatorDataBySymbol[symbol] || [];
      const isAggregated = isAggregatedBySymbol[symbol] || false;

      return {
        symbol,
        timeframe: normalizedTimeframe,
        is_aggregated: isAggregated,
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
        candles,
        indicators,
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
      timeframe: normalizedTimeframe,
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
