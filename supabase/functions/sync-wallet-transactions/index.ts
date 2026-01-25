import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface TronTransaction {
  transaction_id: string;
  from: string;
  to: string;
  value: string;
  block_timestamp: number;
  token_info: {
    symbol: string;
    decimals: number;
  };
}

interface BSCTransaction {
  hash: string;
  from: string;
  to: string;
  value: string;
  timeStamp: string;
  tokenSymbol: string;
  tokenDecimal: string;
}

async function syncSingleWallet(supabase: any, wallet: any): Promise<{ success: boolean; synced: number; wallet_id: string }> {
  let transactions: any[] = [];

  try {
    if (wallet.network === 'tron') {
      // Fetch TRC20 USDT transactions from TronGrid
      const tronUrl = `https://api.trongrid.io/v1/accounts/${wallet.wallet_address}/transactions/trc20?contract_address=TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t&limit=100`;
      
      const tronResponse = await fetch(tronUrl, {
        headers: { 'Accept': 'application/json' },
      });

      if (tronResponse.ok) {
        const tronData = await tronResponse.json();
        if (tronData.data && Array.isArray(tronData.data)) {
          transactions = tronData.data.map((tx: TronTransaction) => ({
            tx_hash: tx.transaction_id,
            tx_type: tx.to.toLowerCase() === wallet.wallet_address.toLowerCase() ? 'in' : 'out',
            amount: parseInt(tx.value) / Math.pow(10, tx.token_info?.decimals || 6),
            token_symbol: tx.token_info?.symbol || 'USDT',
            from_address: tx.from,
            to_address: tx.to,
            block_time: new Date(tx.block_timestamp).toISOString(),
            raw_data: tx,
          }));
        }
      }
    } else if (wallet.network === 'bsc') {
      // Fetch BEP20 USDT transactions from BSCScan
      const bscUrl = `https://api.bscscan.com/api?module=account&action=tokentx&address=${wallet.wallet_address}&contractaddress=0x55d398326f99059fF775485246999027B3197955&sort=desc&page=1&offset=100`;
      
      const bscResponse = await fetch(bscUrl, {
        headers: { 'Accept': 'application/json' },
      });

      if (bscResponse.ok) {
        const bscData = await bscResponse.json();
        if (bscData.status === '1' && Array.isArray(bscData.result)) {
          transactions = bscData.result.map((tx: BSCTransaction) => ({
            tx_hash: tx.hash,
            tx_type: tx.to.toLowerCase() === wallet.wallet_address.toLowerCase() ? 'in' : 'out',
            amount: parseInt(tx.value) / Math.pow(10, parseInt(tx.tokenDecimal) || 18),
            token_symbol: tx.tokenSymbol || 'USDT',
            from_address: tx.from,
            to_address: tx.to,
            block_time: new Date(parseInt(tx.timeStamp) * 1000).toISOString(),
            raw_data: tx,
          }));
        }
      }
    }

    // Upsert transactions
    let insertedCount = 0;
    for (const tx of transactions) {
      const { error: insertError } = await supabase
        .from('wallet_transactions')
        .upsert({
          wallet_id: wallet.id,
          tx_hash: tx.tx_hash,
          tx_type: tx.tx_type,
          amount: tx.amount,
          token_symbol: tx.token_symbol,
          from_address: tx.from_address,
          to_address: tx.to_address,
          block_time: tx.block_time,
          raw_data: tx.raw_data,
        }, {
          onConflict: 'tx_hash,wallet_id',
        });

      if (!insertError) {
        insertedCount++;
      }
    }

    // Update last_sync timestamp
    await supabase
      .from('fund_wallets')
      .update({ last_sync: new Date().toISOString() })
      .eq('id', wallet.id);

    return { success: true, synced: insertedCount, wallet_id: wallet.id };
  } catch (error) {
    console.error(`Error syncing wallet ${wallet.id}:`, error);
    return { success: false, synced: 0, wallet_id: wallet.id };
  }
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const body = await req.json();
    const { wallet_id, sync_all } = body;

    // Sync all active wallets (for cron job)
    if (sync_all === true) {
      console.log('Starting sync for all active wallets...');
      
      const { data: wallets, error: walletsError } = await supabase
        .from('fund_wallets')
        .select('*')
        .eq('is_active', true);

      if (walletsError) {
        console.error('Error fetching wallets:', walletsError);
        return new Response(
          JSON.stringify({ error: 'Failed to fetch wallets' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      console.log(`Found ${wallets?.length || 0} active wallets to sync`);

      const results = [];
      for (const wallet of wallets || []) {
        console.log(`Syncing wallet: ${wallet.wallet_address} (${wallet.network})`);
        const result = await syncSingleWallet(supabase, wallet);
        results.push(result);
        // Add small delay between requests to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 500));
      }

      const totalSynced = results.reduce((sum, r) => sum + r.synced, 0);
      const successCount = results.filter(r => r.success).length;

      console.log(`Sync complete: ${successCount}/${results.length} wallets, ${totalSynced} transactions`);

      return new Response(
        JSON.stringify({ 
          success: true, 
          wallets_synced: successCount,
          total_wallets: results.length,
          total_transactions: totalSynced,
          results
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Sync single wallet
    if (!wallet_id) {
      return new Response(
        JSON.stringify({ error: 'wallet_id is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`Syncing wallet: ${wallet_id}`);

    // Get wallet info
    const { data: wallet, error: walletError } = await supabase
      .from('fund_wallets')
      .select('*')
      .eq('id', wallet_id)
      .single();

    if (walletError || !wallet) {
      console.error('Wallet not found:', walletError);
      return new Response(
        JSON.stringify({ error: 'Wallet not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`Wallet: ${wallet.wallet_address}, Network: ${wallet.network}`);

    const result = await syncSingleWallet(supabase, wallet);

    console.log(`Synced ${result.synced} transactions for wallet ${wallet_id}`);

    return new Response(
      JSON.stringify({ 
        success: result.success, 
        synced: result.synced,
        wallet_address: wallet.wallet_address,
        network: wallet.network,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    console.error('Error syncing wallet:', errorMessage);
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
