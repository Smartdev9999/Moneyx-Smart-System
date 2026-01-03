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

interface VerifyRequest {
  account_number: string;
}

interface VerifyResponse {
  valid: boolean;
  customer_name?: string;
  expiry_date?: string;
  days_remaining?: number;
  is_lifetime?: boolean;
  trading_system?: string;
  package_type?: string;
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
      console.log('[verify-license] Invalid or missing API key');
      return new Response(
        JSON.stringify({ valid: false, message: 'Unauthorized' } as VerifyResponse),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Handle raw body that might have encoding issues from MQL5
    let account_number: string = '';
    try {
      const rawBody = await req.text();
      console.log('[verify-license] Raw body received:', rawBody);
      
      // Try to parse as JSON first
      try {
        const parsed = JSON.parse(rawBody);
        account_number = parsed.account_number || '';
      } catch {
        // If JSON parse fails, try to extract account_number manually
        const match = rawBody.match(/account_number["\s:]+["']?(\d+)/i);
        if (match) {
          account_number = match[1];
        }
      }
    } catch (e) {
      console.error('[verify-license] Failed to read body:', e);
    }

    console.log(`[verify-license] Checking license for MT5 account: ${account_number}`);

    if (!account_number) {
      console.log('[verify-license] No account number provided');
      return new Response(
        JSON.stringify({ valid: false, message: 'Account number is required' } as VerifyResponse),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Query the MT5 account with customer and trading system info
    const { data: account, error } = await supabase
      .from('mt5_accounts')
      .select(`
        *,
        customer:customers(name, email, status),
        trading_system:trading_systems(name)
      `)
      .eq('account_number', account_number)
      .maybeSingle();

    if (error) {
      console.error('[verify-license] Database error:', error);
      return new Response(
        JSON.stringify({ valid: false, message: 'Database error' } as VerifyResponse),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!account) {
      console.log(`[verify-license] Account ${account_number} not found`);
      return new Response(
        JSON.stringify({ 
          valid: false, 
          message: 'Account not registered. Please contact Moneyx Support.' 
        } as VerifyResponse),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check if customer is active
    if (account.customer?.status !== 'active') {
      console.log(`[verify-license] Customer is inactive for account ${account_number}`);
      return new Response(
        JSON.stringify({ 
          valid: false, 
          message: 'Customer account is inactive. Please contact Moneyx Support.' 
        } as VerifyResponse),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check if MT5 account is suspended
    if (account.status === 'suspended') {
      console.log(`[verify-license] Account ${account_number} is suspended`);
      return new Response(
        JSON.stringify({ 
          valid: false, 
          message: 'This MT5 account has been suspended. Please contact Moneyx Support.' 
        } as VerifyResponse),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check if account is lifetime
    if (account.is_lifetime) {
      console.log(`[verify-license] Account ${account_number} has lifetime license`);
      return new Response(
        JSON.stringify({ 
          valid: true, 
          customer_name: account.customer?.name,
          is_lifetime: true,
          trading_system: account.trading_system?.name,
          package_type: account.package_type,
          message: 'Lifetime license active'
        } as VerifyResponse),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check expiry date
    if (!account.expiry_date) {
      console.log(`[verify-license] No expiry date for account ${account_number}`);
      return new Response(
        JSON.stringify({ 
          valid: false, 
          message: 'License not configured. Please contact Moneyx Support.' 
        } as VerifyResponse),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const now = new Date();
    const expiryDate = new Date(account.expiry_date);
    const daysRemaining = Math.ceil((expiryDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

    // Check if expired
    if (daysRemaining < 0) {
      console.log(`[verify-license] Account ${account_number} has expired`);
      
      // Update status to expired
      await supabase
        .from('mt5_accounts')
        .update({ status: 'expired' })
        .eq('id', account.id);

      return new Response(
        JSON.stringify({ 
          valid: false, 
          customer_name: account.customer?.name,
          expiry_date: account.expiry_date,
          days_remaining: daysRemaining,
          message: 'License has expired. Please contact Moneyx Support to renew.' 
        } as VerifyResponse),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Update status if expiring soon (5 days or less)
    if (daysRemaining <= 5 && account.status !== 'expiring_soon') {
      await supabase
        .from('mt5_accounts')
        .update({ status: 'expiring_soon' })
        .eq('id', account.id);
    }

    console.log(`[verify-license] Account ${account_number} is valid, ${daysRemaining} days remaining`);

    return new Response(
      JSON.stringify({ 
        valid: true, 
        customer_name: account.customer?.name,
        expiry_date: account.expiry_date,
        days_remaining: daysRemaining,
        is_lifetime: false,
        trading_system: account.trading_system?.name,
        package_type: account.package_type,
        message: daysRemaining <= 5 
          ? `License expiring in ${daysRemaining} days. Please renew soon.`
          : 'License active'
      } as VerifyResponse),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('[verify-license] Error:', error);
    return new Response(
      JSON.stringify({ valid: false, message: 'Internal server error' } as VerifyResponse),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
