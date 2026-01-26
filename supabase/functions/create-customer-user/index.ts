import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    // Get auth header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader?.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client with user's token
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    })

    // Verify user is admin
    const token = authHeader.replace('Bearer ', '')
    const { data: claims, error: claimsError } = await supabaseUser.auth.getClaims(token)
    
    if (claimsError || !claims?.claims?.sub) {
      console.error('Claims error:', claimsError)
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const userId = claims.claims.sub as string

    // Check if user is admin using service role
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)
    
    const { data: roleData, error: roleError } = await supabaseAdmin
      .from('user_roles')
      .select('role')
      .eq('user_id', userId)
      .in('role', ['admin', 'super_admin'])
      .single()

    if (roleError || !roleData) {
      console.error('Role check failed:', roleError)
      return new Response(
        JSON.stringify({ error: 'ไม่มีสิทธิ์ใช้งาน (Admin Only)' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request body
    const { email, password, customerId, fullName } = await req.json()

    if (!email || !password || !customerId) {
      return new Response(
        JSON.stringify({ error: 'กรุณากรอกข้อมูลให้ครบถ้วน' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (password.length < 6) {
      return new Response(
        JSON.stringify({ error: 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if customer exists
    const { data: customerData, error: customerError } = await supabaseAdmin
      .from('customers')
      .select('id, name')
      .eq('id', customerId)
      .single()

    if (customerError || !customerData) {
      console.error('Customer not found:', customerError)
      return new Response(
        JSON.stringify({ error: 'ไม่พบข้อมูลลูกค้า' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if customer already has a linked user
    const { data: existingLink } = await supabaseAdmin
      .from('customer_users')
      .select('id, status')
      .eq('customer_id', customerId)
      .maybeSingle()

    if (existingLink) {
      return new Response(
        JSON.stringify({ error: 'ลูกค้านี้มีบัญชี Login อยู่แล้ว' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`Creating user for customer: ${customerId}, email: ${email}`)

    // Create user using admin API
    const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true, // Auto-confirm email
      user_metadata: {
        full_name: fullName || customerData.name,
      },
    })

    if (createError) {
      console.error('Create user error:', createError)
      
      // Handle specific errors
      if (createError.message?.includes('already been registered')) {
        return new Response(
          JSON.stringify({ error: 'อีเมลนี้ถูกใช้งานแล้ว' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      
      return new Response(
        JSON.stringify({ error: createError.message || 'ไม่สามารถสร้างบัญชีได้' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!newUser?.user) {
      return new Response(
        JSON.stringify({ error: 'ไม่สามารถสร้างบัญชีได้' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`User created: ${newUser.user.id}`)

    // Add customer role
    const { error: roleInsertError } = await supabaseAdmin
      .from('user_roles')
      .insert({
        user_id: newUser.user.id,
        role: 'customer',
      })

    if (roleInsertError) {
      console.error('Role insert error:', roleInsertError)
      // Don't fail completely, just log
    }

    // Link user to customer with approved status
    const { error: linkError } = await supabaseAdmin
      .from('customer_users')
      .insert({
        user_id: newUser.user.id,
        customer_id: customerId,
        status: 'approved',
        approved_by: userId,
        approved_at: new Date().toISOString(),
      })

    if (linkError) {
      console.error('Link error:', linkError)
      return new Response(
        JSON.stringify({ error: 'สร้างบัญชีสำเร็จ แต่ไม่สามารถเชื่อมกับลูกค้าได้' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`User ${newUser.user.id} linked to customer ${customerId}`)

    return new Response(
      JSON.stringify({
        success: true,
        message: 'สร้างบัญชี Login สำเร็จ',
        user: {
          id: newUser.user.id,
          email: newUser.user.email,
        },
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: 'เกิดข้อผิดพลาดที่ไม่คาดคิด' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
