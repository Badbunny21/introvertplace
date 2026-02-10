-- Subscriptions table for tracking Stripe payments
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  plan TEXT NOT NULL DEFAULT 'free', -- 'free', 'quiet_soul'
  status TEXT NOT NULL DEFAULT 'active', -- 'active', 'canceled', 'past_due', 'trialing'
  current_period_start TIMESTAMPTZ,
  current_period_end TIMESTAMPTZ,
  cancel_at_period_end BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id),
  UNIQUE(stripe_customer_id),
  UNIQUE(stripe_subscription_id)
);

-- Index for faster lookups
CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_stripe_customer_id ON subscriptions(stripe_customer_id);

-- RLS policies
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can read their own subscription
CREATE POLICY "Users can view own subscription"
  ON subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- Only service role can insert/update (via webhooks)
CREATE POLICY "Service role can manage subscriptions"
  ON subscriptions FOR ALL
  USING (auth.role() = 'service_role');

-- Function to check if user has premium access
CREATE OR REPLACE FUNCTION has_premium_access(check_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM subscriptions
    WHERE user_id = check_user_id
    AND plan = 'quiet_soul'
    AND status IN ('active', 'trialing')
    AND (current_period_end IS NULL OR current_period_end > NOW())
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
