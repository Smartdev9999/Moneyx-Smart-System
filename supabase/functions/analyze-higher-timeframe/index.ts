import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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
  time: string;
  ema20: number | null;
  ema50: number | null;
  rsi: number | null;
  macd_main: number | null;
  macd_signal: number | null;
  macd_histogram: number | null;
  atr: number | null;
}

interface AnalysisRequest {
  symbol: string;
  timeframe: 'H4' | 'D1';
  force_refresh?: boolean;
}

// ============= CUSTOMIZABLE ANALYSIS PROMPTS =============
// These prompts can be updated later to train AI for specific techniques

const ANALYSIS_TECHNIQUES = {
  // Default technique: Smart Money Concepts + Price Action
  default: {
    name: "SMC + Price Action",
    systemPrompt: `You are an expert market analyst specializing in Smart Money Concepts (SMC) and Price Action trading.

ANALYSIS FRAMEWORK:
1. **Market Structure Analysis**
   - Identify Break of Structure (BOS) and Change of Character (CHoCH)
   - Map out Higher Highs/Higher Lows (bullish) or Lower Highs/Lower Lows (bearish)
   - Determine current swing points and market phase

2. **Liquidity Analysis**
   - Identify liquidity pools (equal highs/lows, stop hunt zones)
   - Previous session highs/lows as liquidity targets
   - Order blocks and fair value gaps

3. **Key Level Identification**
   - Strong support/resistance zones
   - Institutional order blocks
   - Imbalance zones (Fair Value Gaps)

4. **Multi-Timeframe Confluence**
   - Align analysis with higher timeframe bias
   - Look for confluence zones across timeframes

PROBABILITY ASSESSMENT:
- Give probability based on how many confluences align
- >70% requires: Clear structure + liquidity target + key level alignment
- 50-70%: Partial confluence, mixed signals
- <50%: Counter-trend or unclear structure`,

    userPromptTemplate: (symbol: string, timeframe: string, candlesSummary: string, indicatorSummary: string, lastCandle: CandleData) => `
Analyze ${symbol} on ${timeframe} timeframe for MARKET BIAS:

**Current Price:** ${lastCandle.close.toFixed(5)}
**Recent Candles (OHLC):**
${candlesSummary}

**Technical Indicators:**
${indicatorSummary}

Provide analysis in this exact JSON format:
{
  "symbol": "${symbol}",
  "timeframe": "${timeframe}",
  "bullish_probability": <number 0-100>,
  "bearish_probability": <number 0-100>,
  "sideways_probability": <number 0-100>,
  "dominant_bias": "<bullish|bearish|sideways>",
  "market_structure": "<describe current structure: HH/HL or LH/LL patterns>",
  "key_levels": {
    "support": [<price1>, <price2>],
    "resistance": [<price1>, <price2>]
  },
  "liquidity_zones": "<describe key liquidity targets>",
  "order_blocks": "<describe any significant order blocks>",
  "patterns": "<any chart patterns identified>",
  "trade_bias": "<Only LONG | Only SHORT | No Trade>",
  "reasoning": "<2-3 sentences explaining the analysis>"
}

RULES:
- Probabilities MUST sum to 100%
- Be conservative: only give >70% when multiple SMC confluences align
- For ${timeframe}, focus on swing trading perspective`
  },

  // ICT (Inner Circle Trader) Concepts
  ict: {
    name: "ICT Concepts",
    systemPrompt: `You are an expert in ICT (Inner Circle Trader) methodology.

ANALYSIS FRAMEWORK:
1. **Power of Three (Accumulation, Manipulation, Distribution)**
2. **Optimal Trade Entry (OTE)** - Fibonacci retracements
3. **Kill Zones** - London/NY session timing
4. **Fair Value Gaps (FVG)** - Imbalance zones
5. **Breaker Blocks & Mitigation Blocks**
6. **Judas Swing** - False breakout patterns

Focus on institutional order flow and liquidity engineering.`,

    userPromptTemplate: (symbol: string, timeframe: string, candlesSummary: string, indicatorSummary: string, lastCandle: CandleData) => `
ICT Analysis for ${symbol} ${timeframe}:

Current Price: ${lastCandle.close.toFixed(5)}
Recent Candles: ${candlesSummary}
Indicators: ${indicatorSummary}

Provide ICT-based analysis in JSON format with probabilities and key ICT concepts identified.`
  },

  // Supply & Demand Zones
  supplyDemand: {
    name: "Supply & Demand",
    systemPrompt: `You are an expert in Supply and Demand zone trading.

ANALYSIS FRAMEWORK:
1. **Fresh vs Tested Zones** - Untested zones have higher probability
2. **Zone Strength** - Based on departure strength and time spent
3. **Proximal/Distal Lines** - Entry zones
4. **Rally-Base-Drop / Drop-Base-Rally patterns**
5. **Curve Analysis** - Understanding momentum shifts

Focus on institutional footprints and zone quality.`,

    userPromptTemplate: (symbol: string, timeframe: string, candlesSummary: string, indicatorSummary: string, lastCandle: CandleData) => `
Supply & Demand Analysis for ${symbol} ${timeframe}:

Current Price: ${lastCandle.close.toFixed(5)}
Recent Candles: ${candlesSummary}
Indicators: ${indicatorSummary}

Identify active supply/demand zones and probability of price reaction.`
  }
};

// Current active technique (can be changed later)
const ACTIVE_TECHNIQUE = 'default';

// ============= AGGREGATION FUNCTIONS =============

function aggregateToH4(h1Candles: CandleData[]): CandleData[] {
  const sorted = [...h1Candles].sort((a, b) => 
    new Date(a.time).getTime() - new Date(b.time).getTime()
  );
  
  const h4Groups = new Map<string, CandleData[]>();
  for (const candle of sorted) {
    const date = new Date(candle.time);
    const h4Hour = Math.floor(date.getUTCHours() / 4) * 4;
    const dateStr = date.toISOString().split('T')[0];
    const h4Key = `${dateStr}T${h4Hour.toString().padStart(2, '0')}:00:00.000Z`;
    
    if (!h4Groups.has(h4Key)) h4Groups.set(h4Key, []);
    h4Groups.get(h4Key)!.push(candle);
  }
  
  return Array.from(h4Groups.entries())
    .filter(([_, candles]) => candles.length >= 3)
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
    .filter(([_, candles]) => candles.length >= 20)
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

// ============= INDICATOR CALCULATIONS =============

function calculateEMA(data: number[], period: number): number[] {
  if (data.length === 0) return [];
  const k = 2 / (period + 1);
  const ema: number[] = [data[0]];
  for (let i = 1; i < data.length; i++) {
    ema.push(data[i] * k + ema[i - 1] * (1 - k));
  }
  return ema;
}

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

function calculateMACD(closes: number[]): { main: number[], signal: number[], histogram: number[] } {
  if (closes.length < 26) return { main: [], signal: [], histogram: [] };
  
  const emaFast = calculateEMA(closes, 12);
  const emaSlow = calculateEMA(closes, 26);
  const macdLine = emaFast.map((v, i) => v - emaSlow[i]);
  const signalLine = calculateEMA(macdLine.slice(25), 9);
  
  const paddedSignal = new Array(25 + 8).fill(null).concat(signalLine);
  const histogram = macdLine.map((v, i) => paddedSignal[i] !== null ? v - paddedSignal[i] : null);
  
  return { main: macdLine, signal: paddedSignal as number[], histogram: histogram as number[] };
}

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

function calculateIndicators(candles: CandleData[]): IndicatorData[] {
  const closes = candles.map(c => c.close);
  const ema20 = calculateEMA(closes, 20);
  const ema50 = calculateEMA(closes, 50);
  const rsi = calculateRSI(closes, 14);
  const macd = calculateMACD(closes);
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

    const { symbol, timeframe, force_refresh = false }: AnalysisRequest = await req.json();

    if (!symbol || !timeframe) {
      return new Response(
        JSON.stringify({ success: false, error: 'symbol and timeframe are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (timeframe !== 'H4' && timeframe !== 'D1') {
      return new Response(
        JSON.stringify({ success: false, error: 'timeframe must be H4 or D1' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`[HTF Analysis] Starting ${timeframe} analysis for ${symbol}`);

    // Fetch H1 candles from database
    const { data: h1Candles, error: candleError } = await supabase
      .from('ai_candle_history')
      .select('*')
      .eq('symbol', symbol)
      .in('timeframe', ['H1', 'PERIOD_H1'])
      .order('candle_time', { ascending: true })
      .limit(720);

    if (candleError || !h1Candles || h1Candles.length === 0) {
      console.error('[HTF Analysis] Error fetching H1 candles:', candleError);
      return new Response(
        JSON.stringify({ success: false, error: 'No H1 data available for aggregation' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`[HTF Analysis] Found ${h1Candles.length} H1 candles`);

    // Convert to CandleData format
    const formattedH1: CandleData[] = h1Candles.map(c => ({
      time: c.candle_time,
      open: parseFloat(c.open_price),
      high: parseFloat(c.high_price),
      low: parseFloat(c.low_price),
      close: parseFloat(c.close_price),
      volume: c.volume || 0
    }));

    // Aggregate to requested timeframe
    const aggregatedCandles = timeframe === 'D1' 
      ? aggregateToD1(formattedH1) 
      : aggregateToH4(formattedH1);

    if (aggregatedCandles.length < 10) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: `Not enough data for ${timeframe} analysis. Need at least 10 candles, got ${aggregatedCandles.length}` 
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`[HTF Analysis] Aggregated to ${aggregatedCandles.length} ${timeframe} candles`);

    // Get last candle time for cache key
    const lastCandle = aggregatedCandles[aggregatedCandles.length - 1];
    const cacheKey = `${symbol}_${timeframe}_${lastCandle.time}`;

    // Check cache (unless force refresh)
    if (!force_refresh) {
      const { data: cached } = await supabase
        .from('ai_analysis_cache')
        .select('*')
        .eq('symbol', symbol)
        .eq('timeframe', timeframe)
        .gt('expires_at', new Date().toISOString())
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (cached && cached.bullish_probability !== null) {
        console.log(`[HTF Analysis] Cache hit for ${symbol} ${timeframe}`);
        return new Response(
          JSON.stringify({
            success: true,
            from_cache: true,
            analysis: {
              symbol: cached.symbol,
              timeframe: cached.timeframe,
              bullish_probability: cached.bullish_probability,
              bearish_probability: cached.bearish_probability,
              sideways_probability: cached.sideways_probability,
              dominant_bias: cached.dominant_bias,
              threshold_met: cached.threshold_met,
              market_structure: cached.market_structure,
              key_levels: cached.key_levels,
              patterns: cached.patterns,
              reasoning: cached.reasoning,
              created_at: cached.created_at,
              expires_at: cached.expires_at,
              technique: ACTIVE_TECHNIQUE
            }
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // Calculate indicators for aggregated candles
    const indicators = calculateIndicators(aggregatedCandles);
    const lastIndicator = indicators[indicators.length - 1];

    // Prepare data for AI
    const recentCandles = aggregatedCandles.slice(-30);
    const candlesSummary = recentCandles.map(c => 
      `${c.time.substring(0, 16)}: O=${c.open.toFixed(5)} H=${c.high.toFixed(5)} L=${c.low.toFixed(5)} C=${c.close.toFixed(5)}`
    ).join('\n');

    const indicatorSummary = `
- RSI(14): ${lastIndicator.rsi?.toFixed(2) || 'N/A'}
- EMA20: ${lastIndicator.ema20?.toFixed(5) || 'N/A'}
- EMA50: ${lastIndicator.ema50?.toFixed(5) || 'N/A'}
- MACD: ${lastIndicator.macd_main?.toFixed(5) || 'N/A'} / Signal: ${lastIndicator.macd_signal?.toFixed(5) || 'N/A'}
- ATR(14): ${lastIndicator.atr?.toFixed(5) || 'N/A'}`;

    // Get active technique
    const technique = ANALYSIS_TECHNIQUES[ACTIVE_TECHNIQUE as keyof typeof ANALYSIS_TECHNIQUES] 
      || ANALYSIS_TECHNIQUES.default;

    console.log(`[HTF Analysis] Using technique: ${technique.name}`);

    // Call Lovable AI
    const LOVABLE_API_KEY = Deno.env.get('LOVABLE_API_KEY');
    if (!LOVABLE_API_KEY) {
      throw new Error('LOVABLE_API_KEY is not configured');
    }

    const userPrompt = technique.userPromptTemplate(symbol, timeframe, candlesSummary, indicatorSummary, lastCandle);

    console.log('[HTF Analysis] Calling Lovable AI...');

    const aiResponse = await fetch('https://ai.gateway.lovable.dev/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${LOVABLE_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'google/gemini-2.5-flash',
        messages: [
          { role: 'system', content: technique.systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.2,
        max_tokens: 2000,
      }),
    });

    if (!aiResponse.ok) {
      const errorText = await aiResponse.text();
      console.error('[HTF Analysis] AI API error:', aiResponse.status, errorText);
      
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
    const content = aiData.choices?.[0]?.message?.content || '{}';

    console.log('[HTF Analysis] Raw AI response:', content.substring(0, 500));

    // Clean and parse response
    let cleanContent = content.trim();
    if (cleanContent.startsWith('```json')) cleanContent = cleanContent.slice(7);
    else if (cleanContent.startsWith('```')) cleanContent = cleanContent.slice(3);
    if (cleanContent.endsWith('```')) cleanContent = cleanContent.slice(0, -3);
    cleanContent = cleanContent.trim();

    let analysisResult;
    try {
      analysisResult = JSON.parse(cleanContent);
    } catch (parseError) {
      console.error('[HTF Analysis] Failed to parse AI response:', parseError);
      return new Response(
        JSON.stringify({ success: false, error: 'Failed to parse AI analysis' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Calculate threshold
    const threshold = 70;
    const thresholdMet = Math.max(
      analysisResult.bullish_probability || 0, 
      analysisResult.bearish_probability || 0
    ) >= threshold;

    // Cache expiry: H4 = 4 hours, D1 = 24 hours
    const expiryHours = timeframe === 'D1' ? 24 : 4;
    const expiresAt = new Date(Date.now() + expiryHours * 60 * 60 * 1000).toISOString();

    // Store in cache
    const { error: cacheError } = await supabase
      .from('ai_analysis_cache')
      .upsert({
        symbol,
        timeframe,
        candle_time: lastCandle.time,
        analysis_data: { ...analysisResult, technique: ACTIVE_TECHNIQUE },
        bullish_probability: analysisResult.bullish_probability || 0,
        bearish_probability: analysisResult.bearish_probability || 0,
        sideways_probability: analysisResult.sideways_probability || 0,
        dominant_bias: analysisResult.dominant_bias || 'sideways',
        threshold_met: thresholdMet,
        market_structure: analysisResult.market_structure || '',
        trend_h4: timeframe === 'H4' ? analysisResult.dominant_bias : null,
        trend_daily: timeframe === 'D1' ? analysisResult.dominant_bias : null,
        key_levels: analysisResult.key_levels || { support: [], resistance: [] },
        patterns: analysisResult.patterns || '',
        reasoning: analysisResult.reasoning || '',
        signal: analysisResult.dominant_bias === 'bullish' ? 'buy' : analysisResult.dominant_bias === 'bearish' ? 'sell' : 'hold',
        confidence: Math.max(analysisResult.bullish_probability || 0, analysisResult.bearish_probability || 0),
        trend: analysisResult.dominant_bias,
        expires_at: expiresAt,
      }, {
        onConflict: 'symbol,timeframe,candle_time',
      });

    if (cacheError) {
      console.error('[HTF Analysis] Cache error:', cacheError);
    }

    console.log(`[HTF Analysis] Completed ${timeframe} analysis for ${symbol}`);

    return new Response(
      JSON.stringify({
        success: true,
        from_cache: false,
        analysis: {
          symbol,
          timeframe,
          bullish_probability: analysisResult.bullish_probability || 0,
          bearish_probability: analysisResult.bearish_probability || 0,
          sideways_probability: analysisResult.sideways_probability || 0,
          dominant_bias: analysisResult.dominant_bias || 'sideways',
          threshold_met: thresholdMet,
          market_structure: analysisResult.market_structure || '',
          key_levels: analysisResult.key_levels || { support: [], resistance: [] },
          patterns: analysisResult.patterns || '',
          reasoning: analysisResult.reasoning || '',
          created_at: new Date().toISOString(),
          expires_at: expiresAt,
          technique: ACTIVE_TECHNIQUE,
          technique_name: technique.name
        }
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('[HTF Analysis] Error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
