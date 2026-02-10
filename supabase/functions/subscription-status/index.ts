import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Returns the user's current subscription status

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Not authenticated' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    });

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Not authenticated' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get subscription status
    const { data: subscription } = await supabase
      .from('subscriptions')
      .select('plan, status, current_period_end, cancel_at_period_end')
      .eq('user_id', user.id)
      .single();

    const now = new Date();
    const periodEnd = subscription?.current_period_end 
      ? new Date(subscription.current_period_end) 
      : null;

    const isPremium = subscription 
      && subscription.plan === 'quiet_soul'
      && ['active', 'trialing'].includes(subscription.status)
      && (!periodEnd || periodEnd > now);

    return new Response(
      JSON.stringify({
        isPremium,
        plan: subscription?.plan || 'free',
        status: subscription?.status || 'none',
        periodEnd: subscription?.current_period_end || null,
        cancelAtPeriodEnd: subscription?.cancel_at_period_end || false,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
