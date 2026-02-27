-- Fix Bug 1: Other users can't see posts.
-- The previous policies only allowed reading "public" visibility posts for everyone,
-- but did NOT give all authenticated users access to each other's content.
-- Adding a broad policy so any logged-in user can read any non-private creation
-- regardless of the author — this is what makes the feed work for real users.

-- Allow any authenticated user to read all public and community creations
-- (private posts stay private — only the author sees those via the existing policy).
CREATE POLICY "Authenticated users can view all non-private creations"
  ON creations FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND visibility IN ('public', 'community')
  );

-- Note: this policy is additive. Supabase ORs all SELECT policies together, so:
-- - Anonymous users still see: visibility = 'public' (existing policy)
-- - Authenticated users see: visibility IN ('public', 'community') from any author
-- - Authors always see their own creations regardless of visibility (existing policy)
