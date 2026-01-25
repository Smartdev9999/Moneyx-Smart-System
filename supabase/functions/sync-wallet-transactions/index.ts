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

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { wallet_id } = await req.json();

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

    let transactions: any[] = [];

    if (wallet.network === 'tron') {
      // Fetch TRC20 USDT transactions from TronGrid
      const tronUrl = `https://api.trongrid.io/v1/accounts/${wallet.wallet_address}/transactions/trc20?contract_address=TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t&limit=100`;
      
      console.log(`Fetching from TronGrid: ${tronUrl}`);
      
      const tronResponse = await fetch(tronUrl, {
        headers: {
          'Accept': 'application/json',
        },
      });

      if (!tronResponse.ok) {
        const errorText = await tronResponse.text();
        console.error('TronGrid error:', errorText);
        throw new Error(`TronGrid API error: ${tronResponse.status}`);
      }

      const tronData = await tronResponse.json();
      console.log(`TronGrid returned ${tronData.data?.length || 0} transactions`);

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
    } else if (wallet.network === 'bsc') {
      // Fetch BEP20 USDT transactions from BSCScan
      // USDT contract on BSC: 0x55d398326f99059fF775485246999027B3197955
      const bscUrl = `https://api.bscscan.com/api?module=account&action=tokentx&address=${wallet.wallet_address}&contractaddress=0x55d398326f99059fF775485246999027B3197955&sort=desc&page=1&offset=100`;
      
      console.log(`Fetching from BSCScan`);
      
      const bscResponse = await fetch(bscUrl, {
        headers: {
          'Accept': 'application/json',
        },
      });

      if (!bscResponse.ok) {
        const errorText = await bscResponse.text();
        console.error('BSCScan error:', errorText);
        throw new Error(`BSCScan API error: ${bscResponse.status}`);
      }

      const bscData = await bscResponse.json();
      console.log(`BSCScan returned ${bscData.result?.length || 0} transactions, status: ${bscData.status}`);

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

    console.log(`Processing ${transactions.length} transactions`);

    // Upsert transactions
    let insertedCount = 0;
    for (const tx of transactions) {
      const { error: insertError } = await supabase
        .from('wallet_transactions')
        .upsert({
          wallet_id: wallet_id,
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

      if (insertError) {
        console.error('Error inserting transaction:', insertError);
      } else {
        insertedCount++;
      }
    }

    // Update last_sync timestamp
    await supabase
      .from('fund_wallets')
      .update({ last_sync: new Date().toISOString() })
      .eq('id', wallet_id);

    console.log(`Synced ${insertedCount} transactions for wallet ${wallet_id}`);

    return new Response(
      JSON.stringify({ 
        success: true, 
        synced: insertedCount,
        total_fetched: transactions.length,
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
