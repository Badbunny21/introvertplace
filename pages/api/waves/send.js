import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export default async function handler(req, res) {
  const { from_user_id, to_user_id } = req.body;

  // Save the wave (ignore if already waved)
  const { error } = await supabase
    .from('waves')
    .upsert({ from_user_id, to_user_id });

  if (error) return res.status(400).json({ error: error.message });

  // Create in-app notification
  await supabase
    .from('notifications')
    .insert({
      user_id: to_user_id,
      type: 'wave',
      message: 'Someone sent you a quiet wave 🌙',
      seen: false
    });

  res.status(200).json({ success: true });
}
