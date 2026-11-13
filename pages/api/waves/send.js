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

  const { to_user_id, body } = req.body || {};
  const note = typeof body === 'string' ? body.trim() : '';

  if (!to_user_id) {
    return res.status(400).json({ error: 'Missing to_user_id' });
  }
  if (!note || note.length > 500) {
    return res.status(400).json({ error: 'A note needs between 1 and 500 characters' });
  }

  // 2. Enforce that from_user_id === the authenticated user
  const from_user_id = user.id;

  if (from_user_id === to_user_id) {
    return res.status(400).json({ error: 'Cannot send a note to yourself' });
  }

  // 3. Leave a note. The database holds it for at least four hours
  // before the other person can read it. No notification is created.
  const deliversAt = new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString();
  const { error: noteError } = await supabaseAdmin
    .from('quiet_notes')
    .insert({
      from_user_id,
      to_user_id,
      body: note,
      delivers_at: deliversAt,
    });

  if (noteError) return res.status(400).json({ error: noteError.message });

  res.status(200).json({ success: true, delivers_at: deliversAt });
}
