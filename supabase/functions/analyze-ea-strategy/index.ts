import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { session_id, action } = await req.json();
    
    if (!session_id || !action) {
      return new Response(JSON.stringify({ error: "session_id and action required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const LOVABLE_API_KEY = Deno.env.get("LOVABLE_API_KEY");
    if (!LOVABLE_API_KEY) {
      return new Response(JSON.stringify({ error: "AI not configured" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Get session
    const { data: session, error: sessErr } = await supabase
      .from("tracked_ea_sessions")
      .select("*")
      .eq("id", session_id)
      .single();

    if (sessErr || !session) {
      return new Response(JSON.stringify({ error: "Session not found" }), {
        status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Update status
    await supabase.from("tracked_ea_sessions").update({ status: "analyzing" }).eq("id", session_id);

    if (action === "summarize") {
      // Get all orders
      const { data: orders } = await supabase
        .from("tracked_orders")
        .select("*")
        .eq("session_id", session_id)
        .order("open_time", { ascending: true });

      if (!orders || orders.length === 0) {
        await supabase.from("tracked_ea_sessions").update({ status: "tracking" }).eq("id", session_id);
        return new Response(JSON.stringify({ error: "No orders to analyze" }), {
          status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Build analysis data
      const orderSummary = orders.map((o: any) => ({
        ticket: o.ticket,
        symbol: o.symbol,
        type: o.order_type,
        volume: o.volume,
        open_price: o.open_price,
        close_price: o.close_price,
        sl: o.sl,
        tp: o.tp,
        profit: o.profit,
        open_time: o.open_time,
        close_time: o.close_time,
        holding_seconds: o.holding_time_seconds,
        event: o.event_type,
        market: o.market_data,
      }));

      const prompt = `You are an expert EA (Expert Advisor) strategy analyst for MetaTrader 5. Analyze the following trading orders and reverse-engineer the strategy.

Session: "${session.session_name}"
Magic Number: ${session.ea_magic_number}
Symbols: ${(session.symbols || []).join(", ")}
Total Orders: ${orders.length}

Orders Data (JSON):
${JSON.stringify(orderSummary, null, 2)}

Analyze and provide a DETAILED strategy summary covering:

1. **Entry Logic** - When does the EA open positions? What conditions trigger entries? 
   - Time patterns (what hours/days)
   - Price patterns (breakouts, reversals, ranges)
   - Indicator patterns (from market_data: RSI, EMA, ATR, MACD, Bollinger values at entry)
   - Direction bias (trend following vs counter-trend)

2. **Exit Logic** - When does the EA close positions?
   - Take Profit patterns (fixed pips, dynamic, trailing)
   - Stop Loss patterns (fixed, ATR-based, breakeven)
   - Time-based exits
   - Indicator-based exits

3. **Position Sizing** - How does the EA determine lot sizes?
   - Fixed vs dynamic lots
   - Martingale/grid patterns
   - Scaling in/out

4. **Risk Management**
   - Max positions at same time
   - Drawdown limits
   - Correlation between trades

5. **Market Conditions**
   - What market conditions does it prefer (trending, ranging, volatile)?
   - How does it handle news events?

6. **Key Statistics**
   - Win rate, average profit, average loss
   - Average holding time
   - Most active trading hours

Provide the summary in both Thai (ภาษาไทย) and English.
Be very specific with numbers and patterns you observe.`;

      const aiResponse = await fetch("https://ai.gateway.lovable.dev/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${LOVABLE_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "google/gemini-2.5-flash",
          messages: [
            { role: "system", content: "You are an expert MQL5 EA strategy analyst. Provide detailed, actionable analysis." },
            { role: "user", content: prompt },
          ],
        }),
      });

      if (!aiResponse.ok) {
        const status = aiResponse.status;
        if (status === 429) {
          await supabase.from("tracked_ea_sessions").update({ status: "tracking" }).eq("id", session_id);
          return new Response(JSON.stringify({ error: "Rate limited. Please try again later." }), {
            status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
        if (status === 402) {
          await supabase.from("tracked_ea_sessions").update({ status: "tracking" }).eq("id", session_id);
          return new Response(JSON.stringify({ error: "Payment required. Please add credits." }), {
            status: 402, headers: { ...corsHeaders, "Content-Type": "application/json" },
          });
        }
        throw new Error(`AI gateway error: ${status}`);
      }

      const aiData = await aiResponse.json();
      const summary = aiData.choices?.[0]?.message?.content || "Analysis failed";

      await supabase.from("tracked_ea_sessions").update({
        strategy_summary: summary,
        status: "summarized",
      }).eq("id", session_id);

      return new Response(JSON.stringify({ success: true, summary }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });

    } else if (action === "generate_prompt") {
      if (!session.strategy_summary) {
        await supabase.from("tracked_ea_sessions").update({ status: "summarized" }).eq("id", session_id);
        return new Response(JSON.stringify({ error: "Please summarize first" }), {
          status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const prompt = `Based on the following EA strategy analysis, create a DETAILED and COMPLETE prompt that can be used to write a full MQL5 Expert Advisor that replicates this strategy.

Strategy Summary:
${session.strategy_summary}

The prompt should include:
1. Complete entry conditions with specific indicator values and thresholds
2. Complete exit conditions (TP, SL, trailing stop, time-based)
3. Position sizing rules
4. Risk management rules
5. Order management (pending orders, modifications)
6. Specific input parameters with recommended default values
7. Any special logic (grid, martingale, hedging, etc.)

Format the prompt as a clear, structured specification that an MQL5 developer can follow exactly.
Include specific numeric values wherever possible.
Write in English for technical accuracy.`;

      const aiResponse = await fetch("https://ai.gateway.lovable.dev/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${LOVABLE_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "google/gemini-2.5-flash",
          messages: [
            { role: "system", content: "You are an expert MQL5 EA specification writer. Create precise, implementable specifications." },
            { role: "user", content: prompt },
          ],
        }),
      });

      if (!aiResponse.ok) {
        const status = aiResponse.status;
        await supabase.from("tracked_ea_sessions").update({ status: "summarized" }).eq("id", session_id);
        if (status === 429) return new Response(JSON.stringify({ error: "Rate limited" }), { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        if (status === 402) return new Response(JSON.stringify({ error: "Payment required" }), { status: 402, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        throw new Error(`AI error: ${status}`);
      }

      const aiData = await aiResponse.json();
      const generatedPrompt = aiData.choices?.[0]?.message?.content || "Prompt generation failed";

      await supabase.from("tracked_ea_sessions").update({
        strategy_prompt: generatedPrompt,
        status: "prompted",
      }).eq("id", session_id);

      return new Response(JSON.stringify({ success: true, prompt: generatedPrompt }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });

    } else if (action === "generate_ea") {
      if (!session.strategy_prompt) {
        await supabase.from("tracked_ea_sessions").update({ status: "prompted" }).eq("id", session_id);
        return new Response(JSON.stringify({ error: "Please generate prompt first" }), {
          status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const prompt = `Write a COMPLETE, COMPILE-READY MQL5 Expert Advisor based on the following specification.

EA Specification:
${session.strategy_prompt}

Requirements:
1. The code must compile without errors in MetaEditor
2. Include proper #property headers
3. Include all input parameters with sensible defaults
4. Implement OnInit(), OnDeinit(), OnTick() properly
5. Include proper error handling and logging
6. Use proper MQL5 trade functions (CTrade class)
7. Include dashboard/comment display
8. Follow MQL5 best practices

Output ONLY the MQL5 code, no explanations. Start with //+------------------------------------------------------------------+ header.`;

      const aiResponse = await fetch("https://ai.gateway.lovable.dev/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${LOVABLE_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "google/gemini-2.5-pro",
          messages: [
            { role: "system", content: "You are an expert MQL5 developer. Write complete, production-ready EA code. Output ONLY valid MQL5 code." },
            { role: "user", content: prompt },
          ],
        }),
      });

      if (!aiResponse.ok) {
        const status = aiResponse.status;
        await supabase.from("tracked_ea_sessions").update({ status: "prompted" }).eq("id", session_id);
        if (status === 429) return new Response(JSON.stringify({ error: "Rate limited" }), { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        if (status === 402) return new Response(JSON.stringify({ error: "Payment required" }), { status: 402, headers: { ...corsHeaders, "Content-Type": "application/json" } });
        throw new Error(`AI error: ${status}`);
      }

      const aiData = await aiResponse.json();
      let eaCode = aiData.choices?.[0]?.message?.content || "Code generation failed";
      
      // Clean up code blocks if present
      eaCode = eaCode.replace(/^```(mql5|cpp|c\+\+)?\n?/gm, "").replace(/```$/gm, "").trim();

      await supabase.from("tracked_ea_sessions").update({
        generated_ea_code: eaCode,
        status: "generated",
      }).eq("id", session_id);

      return new Response(JSON.stringify({ success: true, code: eaCode }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });

    } else {
      return new Response(JSON.stringify({ error: "Invalid action. Use: summarize, generate_prompt, generate_ea" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  } catch (error: any) {
    console.error("analyze-ea-strategy error:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
