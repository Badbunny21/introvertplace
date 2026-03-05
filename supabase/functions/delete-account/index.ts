import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get the authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'No authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Create Supabase client with the user's token
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Client with user's auth to get user ID
    const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    });

    // Get the current user
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: 'Not authenticated' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const userId = user.id;

    // Create admin client to delete user data and auth record
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    // Delete all user data — order matters (child records before parent)

    // Tables with user_id column
    const userIdTables = [
      'notifications',
      'beta_feedback',
      'personal_goals',
      'garden_visits',
      'battery_activities',
      'mood_entries',
      'journal_entries',
      'reflections',
      'blog_posts',
      'community_members',
      'creations',
      'garden_rooms',
      'subscriptions',
    ];

    for (const table of userIdTables) {
      const { error } = await supabaseAdmin.from(table).delete().eq('user_id', userId);
      if (error) console.error(`Error deleting from ${table}:`, error);
    }

    // Waves: user can be sender or recipient
    await supabaseAdmin.from('waves').delete().eq('from_user_id', userId);
    await supabaseAdmin.from('waves').delete().eq('to_user_id', userId);

    // Messages: user can be sender or recipient
    await supabaseAdmin.from('messages').delete().eq('sender_id', userId);
    await supabaseAdmin.from('messages').delete().eq('recipient_id', userId);

    // Communities created by user
    await supabaseAdmin.from('communities').delete().eq('creator_id', userId);

    // Profile last (other tables may reference it)
    await supabaseAdmin.from('profiles').delete().eq('id', userId);

    // Delete the user from auth
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId);

    if (deleteError) {
      console.error('Error deleting user:', deleteError);
      return new Response(
        JSON.stringify({ error: 'Failed to delete account' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ success: true, message: 'Account deleted successfully' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
