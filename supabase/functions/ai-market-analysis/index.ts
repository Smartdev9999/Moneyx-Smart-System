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
}

interface AIAnalysisResult {
  symbol: string;
  trend: string;
  signal: string;
  confidence: number;
  entry_price: number;
  stop_loss: number;
  take_profit: number;
  reasoning: string;
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Verify API key
    const apiKey = req.headers.get('x-api-key');
    const expectedKey = Deno.env.get('EA_API_SECRET');
    
    if (apiKey !== expectedKey) {
      console.log('[AI Analysis] Unauthorized request');
      return new Response(
        JSON.stringify({ success: false, error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const requestData: AnalysisRequest = await req.json();
    console.log('[AI Analysis] Received request for', requestData.pairs?.length || 0, 'pairs');

    if (!requestData.pairs || requestData.pairs.length === 0) {
      return new Response(
        JSON.stringify({ success: false, error: 'No pairs data provided' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Create Supabase client for caching
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Check cache for each pair
    const cachedResults: AIAnalysisResult[] = [];
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

      if (cached) {
        console.log(`[AI Analysis] Cache hit for ${pair.symbol} ${pair.timeframe}`);
        cachedResults.push({
          symbol: cached.symbol,
          trend: cached.trend || 'neutral',
          signal: cached.signal || 'hold',
          confidence: cached.confidence || 0,
          entry_price: cached.entry_price || 0,
          stop_loss: cached.stop_loss || 0,
          take_profit: cached.take_profit || 0,
          reasoning: cached.reasoning || '',
        });
      } else {
        pairsToAnalyze.push(pair);
      }
    }

    let newResults: AIAnalysisResult[] = [];

    // Only call AI if we have pairs to analyze
    if (pairsToAnalyze.length > 0) {
      console.log(`[AI Analysis] Analyzing ${pairsToAnalyze.length} pairs with AI`);
      
      const LOVABLE_API_KEY = Deno.env.get('LOVABLE_API_KEY');
      if (!LOVABLE_API_KEY) {
        throw new Error('LOVABLE_API_KEY is not configured');
      }

      // Build concise prompt for all pairs
      const pairsPrompt = pairsToAnalyze.map(pair => {
        const lastCandles = pair.candles.slice(-10); // Last 10 candles only
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

      const systemPrompt = `You are an expert forex/gold trading analyst. Analyze the provided market data and give trading signals. Response MUST be valid JSON array only, no markdown, no explanation text outside JSON. Each object: {"symbol":"EURUSD","trend":"bullish|bearish|neutral","signal":"buy|sell|hold","confidence":0-100,"entry_price":1.0855,"stop_loss":1.0820,"take_profit":1.0920,"reasoning":"short reason max 50 words"}`;

      const userPrompt = `Analyze these pairs and provide trading signals:\n\n${pairsPrompt}\n\nRespond with JSON array only.`;

      console.log('[AI Analysis] Calling Lovable AI...');
      
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
          temperature: 0.3,
          max_tokens: 2000,
        }),
      });

      if (!aiResponse.ok) {
        const errorText = await aiResponse.text();
        console.error('[AI Analysis] AI API error:', aiResponse.status, errorText);
        
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
      
      console.log('[AI Analysis] Raw AI response:', content.substring(0, 500));

      // Parse AI response - handle markdown code blocks
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
        newResults = JSON.parse(cleanContent);
        console.log('[AI Analysis] Parsed', newResults.length, 'results');
      } catch (parseError) {
        console.error('[AI Analysis] Failed to parse AI response:', parseError);
        // Return empty results for failed parse
        newResults = pairsToAnalyze.map(pair => ({
          symbol: pair.symbol,
          trend: 'neutral',
          signal: 'hold',
          confidence: 0,
          entry_price: 0,
          stop_loss: 0,
          take_profit: 0,
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
              signal: result.signal,
              confidence: result.confidence,
              trend: result.trend,
              entry_price: result.entry_price,
              stop_loss: result.stop_loss,
              take_profit: result.take_profit,
              reasoning: result.reasoning,
              expires_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(), // 1 hour
            }, {
              onConflict: 'symbol,timeframe,candle_time',
            });

          if (cacheError) {
            console.error('[AI Analysis] Cache error:', cacheError);
          }
        }
      }
    }

    // Combine cached and new results
    const allResults = [...cachedResults, ...newResults];
    
    // Calculate overall market sentiment
    const bullishCount = allResults.filter(r => r.trend === 'bullish').length;
    const bearishCount = allResults.filter(r => r.trend === 'bearish').length;
    let marketSentiment = 'neutral';
    if (bullishCount > bearishCount) marketSentiment = 'bullish';
    else if (bearishCount > bullishCount) marketSentiment = 'bearish';

    const response = {
      success: true,
      timestamp: new Date().toISOString(),
      analysis: allResults,
      market_sentiment: marketSentiment,
      cached_count: cachedResults.length,
      analyzed_count: newResults.length,
    };

    console.log('[AI Analysis] Returning', allResults.length, 'results');

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('[AI Analysis] Error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
