import { createClient } from '@supabase/supabase-js';

// Admin client for writes (service role) — never exposed client-side
const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Anon client for verifying the caller's JWT
const supabaseAnon = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
);

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // 1. Verify the caller is authenticated
  const authHeader = req.headers.authorization || '';
  const token = authHeader.replace('Bearer ', '');

  if (!token) {
    return res.status(401).json({ error: 'Unauthorized: missing token' });
  }

  const { data: { user }, error: authError } = await supabaseAnon.auth.getUser(token);

  if (authError || !user) {
    return res.status(401).json({ error: 'Unauthorized: invalid token' });
  }

  const { to_user_id } = req.body;

  if (!to_user_id) {
    return res.status(400).json({ error: 'Missing to_user_id' });
  }

  // 2. Enforce that from_user_id === the authenticated user
  const from_user_id = user.id;

  if (from_user_id === to_user_id) {
    return res.status(400).json({ error: 'Cannot send a wave to yourself' });
  }

  // 3. Save the wave (upsert to avoid duplicates)
  const { error: waveError } = await supabaseAdmin
    .from('waves')
    .upsert({ from_user_id, to_user_id });

  if (waveError) return res.status(400).json({ error: waveError.message });

  // 4. Create in-app notification
  await supabaseAdmin
    .from('notifications')
    .insert({
      user_id: to_user_id,
      type: 'wave',
      message: 'Someone sent you a quiet wave 🌙',
      seen: false,
    });

  res.status(200).json({ success: true });
}
