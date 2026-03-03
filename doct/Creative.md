I have a creative page with 4 modes (Garden, Constellation, Infinite Canvas, Seasonal Flow). I have three related bugs all pointing to a data visibility/persistence problem:
Bug 1 — Other users can't see my posts:
A friend in the same mode (Garden) cannot see my Garden posts. This means either: (a) my posts are being saved without a user_id/author_id so they're orphaned, (b) Supabase Row Level Security is blocking SELECT for other users, or (c) the query loading posts filters by author_id = currentUser.id when it should be loading ALL users in that mode.
Bug 2 — My own posts disappear after sign out / sign in:
This means posts are either being saved to localStorage or in-memory state instead of (or in addition to) Supabase, so they vanish when the session resets. Or posts ARE saved to Supabase but the author_id is null because currentUser wasn't loaded yet when the insert ran.
Bug 3 — Content missing for real users at scale:
Both bugs above will get worse with more users. This needs to be fixed at the database level, not patched in the UI.
Please audit and fix all of the following:

Insert timing — Before any post/creative content insert, check that currentUser is not null. If it is null, wait for db.auth.getSession() to resolve first. Never insert with author_id: null.
RLS policies — Check the Supabase RLS policies on the creative_posts (or equivalent) table. The SELECT policy must allow all authenticated users to read posts, not just the author. It should be: CREATE POLICY "Anyone can view posts" ON creative_posts FOR SELECT USING (true); — not USING (auth.uid() = author_id).
Loading query — The query that loads posts for a mode view must fetch posts from ALL users in that mode, not just the current user. It should be something like: fetch all profiles where display_mode = activeMode, then fetch posts where author_id IN (those profile ids). Remove any .eq('author_id', currentUser.id) filter from the general feed query.
localStorage audit — Search the creative page code for any localStorage.setItem or in-memory arrays being used to store posts. Remove them. All post data must go to and come from Supabase only.
Auth race condition — If the page loads and fires data queries before onAuthStateChange has confirmed the session, posts will load as if the user is logged out. Wrap all initial data loading inside the auth ready callback:

jsdb.auth.onAuthStateChange((event, session) => {
  if (session) {
    currentUser = session.user;
    loadCreativePosts(); // load AFTER auth confirmed
  }
});

Verify inserts are reaching Supabase — Add error logging to every insert: if (error) console.error('Insert failed:', error). Check the Supabase dashboard Table Editor to confirm rows are actually appearing after a post is made.

The root cause is likely a combination of RLS blocking reads + auth not being awaited before inserts. Fix the RLS SELECT policy first — that alone will probably solve Bug 1 and partially solve Bug 3.