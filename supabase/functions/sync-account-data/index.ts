import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface SyncRequest {
  account_number: string;
  balance: number;
  equity: number;
  margin_level: number;
  drawdown: number;
  profit_loss: number;
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
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const syncData: SyncRequest = await req.json();

    console.log(`[sync-account-data] Syncing data for MT5 account: ${syncData.account_number}`);

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

    // Update the MT5 account with latest data
    const { error: updateError } = await supabase
      .from('mt5_accounts')
      .update({
        balance: syncData.balance,
        equity: syncData.equity,
        margin_level: syncData.margin_level,
        drawdown: syncData.drawdown,
        profit_loss: syncData.profit_loss,
        last_sync: new Date().toISOString(),
      })
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
      // Don't fail the request if history insert fails
    }

    console.log(`[sync-account-data] Successfully synced data for account ${syncData.account_number}`);
    console.log(`[sync-account-data] Balance: ${syncData.balance}, Equity: ${syncData.equity}, P/L: ${syncData.profit_loss}`);

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
