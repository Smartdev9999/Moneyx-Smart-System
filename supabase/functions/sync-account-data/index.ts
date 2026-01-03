import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key',
};

const EA_API_SECRET = Deno.env.get('EA_API_SECRET');

function validateApiKey(req: Request): boolean {
  const apiKey = req.headers.get('x-api-key');
  return apiKey === EA_API_SECRET;
}

interface TradeHistoryItem {
  deal_ticket: number;
  order_ticket?: number;
  symbol: string;
  deal_type: string; // 'buy', 'sell', 'balance', 'credit'
  entry_type: string; // 'in', 'out', 'inout'
  volume: number;
  open_price: number;
  close_price?: number;
  sl?: number;
  tp?: number;
  profit: number;
  swap: number;
  commission: number;
  comment?: string;
  open_time?: string;
  close_time?: string;
  magic_number?: number;
}

interface SyncRequest {
  account_number: string;
  balance: number;
  equity: number;
  margin_level: number;
  drawdown: number;
  profit_loss: number;
  // Real-time trading data
  open_orders?: number;
  floating_pl?: number;
  total_profit?: number;
  // Portfolio stats
  initial_balance?: number;
  total_deposit?: number;
  total_withdrawal?: number;
  max_drawdown?: number;
  win_trades?: number;
  loss_trades?: number;
  total_trades?: number;
  // Trade history (sent on order close events)
  trade_history?: TradeHistoryItem[];
  // Event type for tracking
  event_type?: 'scheduled' | 'order_open' | 'order_close';
  // EA status for dashboard display
  ea_status?: 'working' | 'paused' | 'suspended' | 'expired' | 'invalid' | 'offline';
}

interface SyncResponse {
  success: boolean;
  message?: string;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Validate API key
    if (!validateApiKey(req)) {
      console.log('[sync-account-data] Invalid or missing API key');
      return new Response(
        JSON.stringify({ success: false, message: 'Unauthorized' } as SyncResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Handle raw body that might have encoding issues from MQL5
    let syncData: SyncRequest;
    try {
      const rawBody = await req.text();
      console.log('[sync-account-data] Raw body length:', rawBody.length);
      
      // Clean the raw body - remove null bytes and fix encoding issues
      let cleanBody = rawBody
        .replace(/\x00/g, '')  // Remove null bytes
        .replace(/[\x00-\x1F\x7F]/g, (c) => c === '\n' || c === '\r' || c === '\t' ? c : '')  // Remove control chars except newlines/tabs
        .trim();
      
      // Try to parse as JSON
      try {
        syncData = JSON.parse(cleanBody);
      } catch (parseError) {
        console.error('[sync-account-data] JSON parse error, trying to fix:', parseError);
        
        // Try to extract account_number manually for basic sync
        const accountMatch = cleanBody.match(/account_number["\s:]+["']?(\d+)/i);
        const balanceMatch = cleanBody.match(/balance["\s:]+([0-9.]+)/i);
        const equityMatch = cleanBody.match(/equity["\s:]+([0-9.]+)/i);
        
        if (accountMatch) {
          syncData = {
            account_number: accountMatch[1],
            balance: balanceMatch ? parseFloat(balanceMatch[1]) : 0,
            equity: equityMatch ? parseFloat(equityMatch[1]) : 0,
            margin_level: 0,
            drawdown: 0,
            profit_loss: 0,
          };
          console.log('[sync-account-data] Recovered basic data from malformed JSON');
        } else {
          throw new Error('Could not extract account_number from malformed JSON');
        }
      }
    } catch (e) {
      console.error('[sync-account-data] Failed to read/parse body:', e);
      return new Response(
        JSON.stringify({ success: false, message: 'Invalid request body' } as SyncResponse),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const eventType = syncData.event_type || 'scheduled';
    console.log(`[sync-account-data] Syncing data for MT5 account: ${syncData.account_number} (event: ${eventType})`);

    if (!syncData.account_number) {
      console.log('[sync-account-data] No account number provided');
      return new Response(
        JSON.stringify({ success: false, message: 'Account number is required' } as SyncResponse),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Find the MT5 account
    const { data: account, error: findError } = await supabase
      .from('mt5_accounts')
      .select('id')
      .eq('account_number', syncData.account_number)
      .maybeSingle();

    if (findError) {
      console.error('[sync-account-data] Database error:', findError);
      return new Response(
        JSON.stringify({ success: false, message: 'Database error' } as SyncResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!account) {
      console.log(`[sync-account-data] Account ${syncData.account_number} not found`);
      return new Response(
        JSON.stringify({ success: false, message: 'Account not found' } as SyncResponse),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Build update data for MT5 account
    const updateData: Record<string, any> = {
      balance: syncData.balance,
      equity: syncData.equity,
      margin_level: syncData.margin_level,
      drawdown: syncData.drawdown,
      profit_loss: syncData.profit_loss,
      last_sync: new Date().toISOString(),
    };

    // Add optional real-time fields
    if (syncData.open_orders !== undefined) {
      updateData.open_orders = syncData.open_orders;
    }
    if (syncData.floating_pl !== undefined) {
      updateData.floating_pl = syncData.floating_pl;
    }
    if (syncData.total_profit !== undefined) {
      updateData.total_profit = syncData.total_profit;
    }

    // Add portfolio stats
    if (syncData.initial_balance !== undefined) {
      updateData.initial_balance = syncData.initial_balance;
    }
    if (syncData.total_deposit !== undefined) {
      updateData.total_deposit = syncData.total_deposit;
    }
    if (syncData.total_withdrawal !== undefined) {
      updateData.total_withdrawal = syncData.total_withdrawal;
    }
    if (syncData.max_drawdown !== undefined) {
      updateData.max_drawdown = syncData.max_drawdown;
    }
    if (syncData.win_trades !== undefined) {
      updateData.win_trades = syncData.win_trades;
    }
    if (syncData.loss_trades !== undefined) {
      updateData.loss_trades = syncData.loss_trades;
    }
    if (syncData.total_trades !== undefined) {
      updateData.total_trades = syncData.total_trades;
    }

    // EA status for dashboard display
    if (syncData.ea_status !== undefined) {
      updateData.ea_status = syncData.ea_status;
    }

    const { error: updateError } = await supabase
      .from('mt5_accounts')
      .update(updateData)
      .eq('id', account.id);

    if (updateError) {
      console.error('[sync-account-data] Update error:', updateError);
      return new Response(
        JSON.stringify({ success: false, message: 'Failed to update account' } as SyncResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Insert into account history for tracking
    const { error: historyError } = await supabase
      .from('account_history')
      .insert({
        mt5_account_id: account.id,
        balance: syncData.balance,
        equity: syncData.equity,
        margin_level: syncData.margin_level,
        drawdown: syncData.drawdown,
        profit_loss: syncData.profit_loss,
      });

    if (historyError) {
      console.error('[sync-account-data] History insert error:', historyError);
    }

    // Insert trade history if provided (typically on order_close events)
    if (syncData.trade_history && syncData.trade_history.length > 0) {
      console.log(`[sync-account-data] Processing ${syncData.trade_history.length} trade history records`);
      
      const tradeRecords = syncData.trade_history.map((trade) => ({
        mt5_account_id: account.id,
        deal_ticket: trade.deal_ticket,
        order_ticket: trade.order_ticket,
        symbol: trade.symbol,
        deal_type: trade.deal_type,
        entry_type: trade.entry_type,
        volume: trade.volume,
        open_price: trade.open_price,
        close_price: trade.close_price,
        sl: trade.sl,
        tp: trade.tp,
        profit: trade.profit,
        swap: trade.swap,
        commission: trade.commission,
        comment: trade.comment,
        open_time: trade.open_time,
        close_time: trade.close_time,
        magic_number: trade.magic_number,
      }));

      const { error: tradeHistoryError } = await supabase
        .from('trade_history')
        .upsert(tradeRecords, { 
          onConflict: 'mt5_account_id,deal_ticket',
          ignoreDuplicates: true 
        });

      if (tradeHistoryError) {
        console.error('[sync-account-data] Trade history insert error:', tradeHistoryError);
      } else {
        console.log(`[sync-account-data] Successfully inserted/updated ${tradeRecords.length} trade history records`);
      }
    }

    console.log(`[sync-account-data] Successfully synced data for account ${syncData.account_number}`);
    console.log(`[sync-account-data] Balance: ${syncData.balance}, Equity: ${syncData.equity}, P/L: ${syncData.profit_loss}`);
    if (syncData.open_orders !== undefined) {
      console.log(`[sync-account-data] Open Orders: ${syncData.open_orders}, Floating P/L: ${syncData.floating_pl}, Total Profit: ${syncData.total_profit}`);
    }
    if (syncData.total_trades !== undefined) {
      console.log(`[sync-account-data] Portfolio Stats - Total Trades: ${syncData.total_trades}, Win: ${syncData.win_trades}, Loss: ${syncData.loss_trades}`);
    }

    return new Response(
      JSON.stringify({ success: true, message: 'Data synced successfully' } as SyncResponse),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('[sync-account-data] Error:', error);
    return new Response(
      JSON.stringify({ success: false, message: 'Internal server error' } as SyncResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});