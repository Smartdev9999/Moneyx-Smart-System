import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key',
};

interface CandleData {
  time: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

interface IndicatorData {
  rsi?: number;
  macd?: { main: number; signal: number; histogram: number };
  ema?: { ema20: number; ema50: number; ema200?: number };
  atr?: number;
  bb?: { upper: number; middle: number; lower: number };
}

interface PairData {
  symbol: string;
  timeframe: string;
  candles: CandleData[];
  indicators: IndicatorData;
  candle_time: string;
}

interface AnalysisRequest {
  pairs: PairData[];
  threshold?: number;
}

interface MarketBiasResult {
  symbol: string;
  bullish_probability: number;
  bearish_probability: number;
  sideways_probability: number;
  dominant_bias: string;
  threshold_met: boolean;
  market_structure: string;
  trend_h4: string;
  trend_daily: string;
  key_levels: { support: number[]; resistance: number[] };
  patterns: string;
  recommendation: string;
  reasoning: string;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const apiKey = req.headers.get('x-api-key');
    const expectedKey = Deno.env.get('EA_API_SECRET');
    
    if (apiKey !== expectedKey) {
      console.log('[AI Bias] Unauthorized request');
      return new Response(
        JSON.stringify({ success: false, error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Read raw body and clean MQL5 malformed data
    let rawBody = await req.text();
    console.log('[AI Bias] Received raw body length:', rawBody.length);
    
    // AGGRESSIVE CLEANING for MQL5 WebRequest data
    // 1. Remove ALL control characters including nulls
    rawBody = rawBody.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');
    
    // 2. Trim whitespace from start and end
    rawBody = rawBody.trim();
    
    // 3. Remove trailing commas before ] or }
    rawBody = rawBody.replace(/,\s*([\]}])/g, '$1');
    
    // 4. Fix number formatting issues
    rawBody = rawBody.replace(/:\s*NaN/g, ':0');
    rawBody = rawBody.replace(/:\s*Infinity/g, ':999999');
    rawBody = rawBody.replace(/:\s*-Infinity/g, ':-999999');
    
    // 5. Ensure JSON ends properly - find the last valid JSON end character
    const lastBrace = rawBody.lastIndexOf('}');
    const lastBracket = rawBody.lastIndexOf(']');
    const lastValidEnd = Math.max(lastBrace, lastBracket);
    if (lastValidEnd > 0 && lastValidEnd < rawBody.length - 1) {
      console.log('[AI Bias] Trimming invalid trailing chars from position', lastValidEnd + 1);
      rawBody = rawBody.substring(0, lastValidEnd + 1);
    }
    
    console.log('[AI Bias] Cleaned body length:', rawBody.length);
    console.log('[AI Bias] Body ends with:', JSON.stringify(rawBody.substring(rawBody.length - 50)));
    
    let requestData: AnalysisRequest;
    try {
      requestData = JSON.parse(rawBody);
    } catch (parseErr) {
      console.error('[AI Bias] Initial JSON parse failed:', parseErr);
      console.log('[AI Bias] Raw body sample (first 500 chars):', rawBody.substring(0, 500));
      console.log('[AI Bias] Raw body sample (last 500 chars):', rawBody.substring(rawBody.length - 500));
      
      // Try to find and fix the problematic area
      const errorMatch = String(parseErr).match(/position (\d+)/);
      if (errorMatch) {
        const pos = parseInt(errorMatch[1]);
        console.log('[AI Bias] Error context around position', pos, ':', 
          JSON.stringify(rawBody.substring(Math.max(0, pos - 30), Math.min(rawBody.length, pos + 30))));
        
        // Try to analyze what's at that position
        if (pos < rawBody.length) {
          const charCode = rawBody.charCodeAt(pos);
          console.log('[AI Bias] Char at position', pos, ':', charCode, '=', JSON.stringify(rawBody.charAt(pos)));
        }
      }
      
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid JSON from EA: ' + String(parseErr) }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    
    const threshold = requestData.threshold || 70;
    console.log('[AI Bias] Received request for', requestData.pairs?.length || 0, 'pairs, threshold:', threshold);

    if (!requestData.pairs || requestData.pairs.length === 0) {
      return new Response(
        JSON.stringify({ success: false, error: 'No pairs data provided' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // ============= PHASE 2: Store Candle & Indicator Data =============
    console.log('[AI Bias] Storing candle and indicator data...');
    
    for (const pair of requestData.pairs) {
      // Store candles to ai_candle_history
      if (pair.candles && pair.candles.length > 0) {
        const candleRows = pair.candles.map(c => ({
          symbol: pair.symbol,
          timeframe: pair.timeframe,
          candle_time: c.time,
          open_price: c.open,
          high_price: c.high,
          low_price: c.low,
          close_price: c.close,
          volume: c.volume || 0,
        }));

        const { error: candleError } = await supabase
          .from('ai_candle_history')
          .upsert(candleRows, { onConflict: 'symbol,timeframe,candle_time' });

        if (candleError) {
          console.error('[AI Bias] Error storing candles:', candleError);
        } else {
          console.log(`[AI Bias] Stored ${candleRows.length} candles for ${pair.symbol}`);
        }
      }

      // Store indicators to ai_indicator_history (latest candle only)
      if (pair.indicators && pair.candle_time) {
        const indicatorRow = {
          symbol: pair.symbol,
          timeframe: pair.timeframe,
          candle_time: pair.candle_time,
          rsi: pair.indicators.rsi || null,
          macd_main: pair.indicators.macd?.main || null,
          macd_signal: pair.indicators.macd?.signal || null,
          macd_histogram: pair.indicators.macd?.histogram || null,
          ema20: pair.indicators.ema?.ema20 || null,
          ema50: pair.indicators.ema?.ema50 || null,
          atr: pair.indicators.atr || null,
        };

        const { error: indicatorError } = await supabase
          .from('ai_indicator_history')
          .upsert(indicatorRow, { onConflict: 'symbol,timeframe,candle_time' });

        if (indicatorError) {
          console.error('[AI Bias] Error storing indicators:', indicatorError);
        }
      }
    }

    // ============= Check cache for each pair =============
    const cachedResults: MarketBiasResult[] = [];
    const pairsToAnalyze: PairData[] = [];

    for (const pair of requestData.pairs) {
      const { data: cached } = await supabase
        .from('ai_analysis_cache')
        .select('*')
        .eq('symbol', pair.symbol)
        .eq('timeframe', pair.timeframe)
        .eq('candle_time', pair.candle_time)
        .gt('expires_at', new Date().toISOString())
        .maybeSingle();

      if (cached && cached.bullish_probability !== null) {
        console.log(`[AI Bias] Cache hit for ${pair.symbol} ${pair.timeframe}`);
        cachedResults.push({
          symbol: cached.symbol,
          bullish_probability: cached.bullish_probability || 0,
          bearish_probability: cached.bearish_probability || 0,
          sideways_probability: cached.sideways_probability || 0,
          dominant_bias: cached.dominant_bias || 'sideways',
          threshold_met: cached.threshold_met || false,
          market_structure: cached.market_structure || '',
          trend_h4: cached.trend_h4 || '',
          trend_daily: cached.trend_daily || '',
          key_levels: cached.key_levels || { support: [], resistance: [] },
          patterns: cached.patterns || '',
          recommendation: getRecommendation(cached.dominant_bias, cached.threshold_met),
          reasoning: cached.reasoning || '',
        });
      } else {
        pairsToAnalyze.push(pair);
      }
    }

    let newResults: MarketBiasResult[] = [];

    if (pairsToAnalyze.length > 0) {
      console.log(`[AI Bias] Analyzing ${pairsToAnalyze.length} pairs with AI`);
      
      const LOVABLE_API_KEY = Deno.env.get('LOVABLE_API_KEY');
      if (!LOVABLE_API_KEY) {
        throw new Error('LOVABLE_API_KEY is not configured');
      }

      const pairsPrompt = pairsToAnalyze.map(pair => {
        const lastCandles = pair.candles.slice(-20);
        const candlesSummary = lastCandles.map(c => 
          `${c.time.substring(11, 16)}:O${c.open.toFixed(5)}H${c.high.toFixed(5)}L${c.low.toFixed(5)}C${c.close.toFixed(5)}`
        ).join('|');
        
        const indicators = pair.indicators;
        const indicatorStr = [
          indicators.rsi !== undefined ? `RSI:${indicators.rsi.toFixed(1)}` : '',
          indicators.ema ? `EMA20:${indicators.ema.ema20.toFixed(5)},EMA50:${indicators.ema.ema50.toFixed(5)}` : '',
          indicators.macd ? `MACD:${indicators.macd.main.toFixed(5)},Sig:${indicators.macd.signal.toFixed(5)}` : '',
          indicators.atr !== undefined ? `ATR:${indicators.atr.toFixed(5)}` : '',
        ].filter(s => s).join(';');
        
        return `[${pair.symbol}|${pair.timeframe}]\nCandles:${candlesSummary}\nIndicators:${indicatorStr}`;
      }).join('\n\n');

      const systemPrompt = `You are an expert market analyst specializing in forex and gold trading. Your job is to analyze market BIAS (not entry signals) to help traders choose the most advantageous direction.

ANALYSIS FRAMEWORK:
1. Market Structure: Identify HH/HL (bullish) or LH/LL (bearish) patterns
2. Multi-Timeframe Trend: Consider H4 and Daily trend alignment
3. Key Levels: Identify important support/resistance zones
4. Chart Patterns: Recognize continuation or reversal patterns
5. Overall Probability: Calculate probability for each direction

RESPONSE FORMAT (JSON array only, no markdown):
[{
  "symbol": "XAUUSD",
  "bullish_probability": 72,
  "bearish_probability": 18,
  "sideways_probability": 10,
  "dominant_bias": "bullish",
  "market_structure": "HH-HL forming, bullish structure intact",
  "trend_h4": "bullish",
  "trend_daily": "bullish",
  "key_levels": {"support": [2640.00, 2620.00], "resistance": [2680.00, 2700.00]},
  "patterns": "Bull flag breakout pending",
  "reasoning": "Strong bullish structure with price above EMAs, RSI healthy at 58, MACD positive momentum"
}]

RULES:
- Probabilities MUST sum to 100%
- dominant_bias = direction with highest probability
- Be conservative: only give >70% when multiple confirmations align
- Sideways when no clear direction or conflicting signals`;

      const userPrompt = `Analyze these pairs for MARKET BIAS (probability of each direction). Focus on which side has the advantage for today's trading:\n\n${pairsPrompt}\n\nRespond with JSON array only.`;

      console.log('[AI Bias] Calling Lovable AI...');
      
      const aiResponse = await fetch('https://ai.gateway.lovable.dev/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${LOVABLE_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: 'google/gemini-2.5-flash-lite',
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userPrompt }
          ],
          temperature: 0.2,
          max_tokens: 3000,
        }),
      });

      if (!aiResponse.ok) {
        const errorText = await aiResponse.text();
        console.error('[AI Bias] AI API error:', aiResponse.status, errorText);
        
        if (aiResponse.status === 429) {
          return new Response(
            JSON.stringify({ success: false, error: 'Rate limit exceeded. Please try again later.' }),
            { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
        if (aiResponse.status === 402) {
          return new Response(
            JSON.stringify({ success: false, error: 'AI credits exhausted. Please add credits.' }),
            { status: 402, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
        throw new Error(`AI API error: ${aiResponse.status}`);
      }

      const aiData = await aiResponse.json();
      const content = aiData.choices?.[0]?.message?.content || '[]';
      
      console.log('[AI Bias] Raw AI response:', content.substring(0, 500));

      let cleanContent = content.trim();
      if (cleanContent.startsWith('```json')) {
        cleanContent = cleanContent.slice(7);
      } else if (cleanContent.startsWith('```')) {
        cleanContent = cleanContent.slice(3);
      }
      if (cleanContent.endsWith('```')) {
        cleanContent = cleanContent.slice(0, -3);
      }
      cleanContent = cleanContent.trim();

      try {
        const parsedResults = JSON.parse(cleanContent);
        newResults = parsedResults.map((r: any) => {
          const thresholdMet = Math.max(r.bullish_probability || 0, r.bearish_probability || 0) >= threshold;
          return {
            symbol: r.symbol,
            bullish_probability: r.bullish_probability || 0,
            bearish_probability: r.bearish_probability || 0,
            sideways_probability: r.sideways_probability || 0,
            dominant_bias: r.dominant_bias || 'sideways',
            threshold_met: thresholdMet,
            market_structure: r.market_structure || '',
            trend_h4: r.trend_h4 || '',
            trend_daily: r.trend_daily || '',
            key_levels: r.key_levels || { support: [], resistance: [] },
            patterns: r.patterns || '',
            recommendation: getRecommendation(r.dominant_bias, thresholdMet),
            reasoning: r.reasoning || '',
          };
        });
        console.log('[AI Bias] Parsed', newResults.length, 'results');
      } catch (parseError) {
        console.error('[AI Bias] Failed to parse AI response:', parseError);
        newResults = pairsToAnalyze.map(pair => ({
          symbol: pair.symbol,
          bullish_probability: 33,
          bearish_probability: 33,
          sideways_probability: 34,
          dominant_bias: 'sideways',
          threshold_met: false,
          market_structure: 'Unable to analyze',
          trend_h4: 'unknown',
          trend_daily: 'unknown',
          key_levels: { support: [], resistance: [] },
          patterns: '',
          recommendation: 'No Trade',
          reasoning: 'Analysis failed - unable to parse AI response',
        }));
      }

      // Cache new results
      for (const result of newResults) {
        const pair = pairsToAnalyze.find(p => p.symbol === result.symbol);
        if (pair) {
          const { error: cacheError } = await supabase
            .from('ai_analysis_cache')
            .upsert({
              symbol: result.symbol,
              timeframe: pair.timeframe,
              candle_time: pair.candle_time,
              analysis_data: result,
              bullish_probability: result.bullish_probability,
              bearish_probability: result.bearish_probability,
              sideways_probability: result.sideways_probability,
              dominant_bias: result.dominant_bias,
              threshold_met: result.threshold_met,
              market_structure: result.market_structure,
              trend_h4: result.trend_h4,
              trend_daily: result.trend_daily,
              key_levels: result.key_levels,
              patterns: result.patterns,
              reasoning: result.reasoning,
              signal: result.dominant_bias === 'bullish' ? 'buy' : result.dominant_bias === 'bearish' ? 'sell' : 'hold',
              confidence: Math.max(result.bullish_probability, result.bearish_probability),
              trend: result.dominant_bias,
              expires_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
            }, {
              onConflict: 'symbol,timeframe,candle_time',
            });

          if (cacheError) {
            console.error('[AI Bias] Cache error:', cacheError);
          }
        }
      }
    }

    const allResults = [...cachedResults, ...newResults];
    
    const avgBullish = allResults.reduce((sum, r) => sum + r.bullish_probability, 0) / allResults.length;
    const avgBearish = allResults.reduce((sum, r) => sum + r.bearish_probability, 0) / allResults.length;
    let overallBias = 'sideways';
    if (avgBullish > avgBearish + 10) overallBias = 'bullish';
    else if (avgBearish > avgBullish + 10) overallBias = 'bearish';

    const tradablePairs = allResults.filter(r => r.threshold_met).length;

    const response = {
      success: true,
      timestamp: new Date().toISOString(),
      analysis: allResults,
      overall_bias: overallBias,
      avg_bullish: Math.round(avgBullish),
      avg_bearish: Math.round(avgBearish),
      tradable_pairs: tradablePairs,
      total_pairs: allResults.length,
      threshold: threshold,
      cached_count: cachedResults.length,
      analyzed_count: newResults.length,
    };

    console.log('[AI Bias] Returning', allResults.length, 'results, tradable:', tradablePairs);

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('[AI Bias] Error:', error);
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
