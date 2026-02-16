import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-api-key, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Validate API key
    const apiKey = req.headers.get("x-api-key");
    const expectedKey = Deno.env.get("EA_API_SECRET");
    
    if (!expectedKey || expectedKey.length < 16) {
      console.error("EA_API_SECRET not configured or too short");
      return new Response(JSON.stringify({ error: "Server not configured" }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    
    if (!apiKey || apiKey !== expectedKey) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Parse body - handle MQL5 quirks
    let rawBody = await req.text();
    rawBody = rawBody.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, "");
    
    let body: any;
    try {
      body = JSON.parse(rawBody);
    } catch {
      console.error("Failed to parse JSON:", rawBody.substring(0, 500));
      return new Response(JSON.stringify({ error: "Invalid JSON" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { session_name, account_number, broker, magic_number, orders, event } = body;

    if (!session_name) {
      return new Response(JSON.stringify({ error: "session_name required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Auto-create or find session
    let sessionId: string;
    
    const { data: existingSession } = await supabase
      .from("tracked_ea_sessions")
      .select("id, account_number, broker")
      .eq("session_name", session_name)
      .eq("account_number", account_number || "")
      .maybeSingle();

    if (existingSession) {
      sessionId = existingSession.id;
      
      // Update session with heartbeat + broker/account info if missing
      const updateData: any = { last_heartbeat: new Date().toISOString() };
      if (account_number && !existingSession.account_number) {
        updateData.account_number = account_number;
      }
      if (broker && !existingSession.broker) {
        updateData.broker = broker;
      }
      
      await supabase
        .from("tracked_ea_sessions")
        .update(updateData)
        .eq("id", sessionId);
    } else {
      const { data: newSession, error: createErr } = await supabase
        .from("tracked_ea_sessions")
        .insert({
          session_name,
          ea_magic_number: magic_number || 0,
          broker: broker || null,
          account_number: account_number || null,
          status: "tracking",
          last_heartbeat: new Date().toISOString(),
        })
        .select("id")
        .single();

      if (createErr) throw createErr;
      sessionId = newSession.id;
    }

    console.log(`[sync-tracked-orders] Session: ${session_name}, Event: ${event || 'data'}, Account: ${account_number || 'N/A'}, Orders: ${orders?.length || 0}`);

    // Process orders
    if (orders && Array.isArray(orders) && orders.length > 0) {
      const orderRows = orders.map((o: any) => ({
        session_id: sessionId,
        ticket: o.ticket,
        magic_number: o.magic_number || magic_number || 0,
        symbol: o.symbol || "UNKNOWN",
        order_type: o.order_type || "unknown",
        volume: o.volume || 0,
        open_price: o.open_price || 0,
        close_price: o.close_price || null,
        sl: o.sl || null,
        tp: o.tp || null,
        profit: o.profit || 0,
        swap: o.swap || 0,
        commission: o.commission || 0,
        open_time: o.open_time || null,
        close_time: o.close_time || null,
        comment: o.comment || null,
        holding_time_seconds: o.holding_time_seconds || 0,
        market_data: o.market_data || {},
        event_type: o.event_type || "open",
      }));

      const { error: upsertErr } = await supabase
        .from("tracked_orders")
        .upsert(orderRows, { onConflict: "session_id,ticket,event_type" });

      if (upsertErr) {
        console.error("Upsert error:", upsertErr);
        throw upsertErr;
      }

      // Update session stats
      const { data: orderStats } = await supabase
        .from("tracked_orders")
        .select("symbol")
        .eq("session_id", sessionId);

      const uniqueSymbols = [...new Set((orderStats || []).map((o: any) => o.symbol))];
      
      await supabase
        .from("tracked_ea_sessions")
        .update({
          total_orders: orderStats?.length || 0,
          symbols: uniqueSymbols,
          last_heartbeat: new Date().toISOString(),
        })
        .eq("id", sessionId);
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        session_id: sessionId,
        orders_processed: orders?.length || 0
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    console.error("sync-tracked-orders error:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
