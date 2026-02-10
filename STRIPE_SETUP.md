# Stripe Integration Setup Guide 🤓

*By quietsoul — Feb 9, 2026*

This guide walks you through setting up Stripe payments for IntrovertPlace's "Quiet Soul" premium tier.

---

## What I've Created

```
supabase/
├── migrations/
│   └── 20260209_create_subscriptions.sql   # New subscription table
└── functions/
    ├── create-checkout-session/index.ts    # Starts Stripe checkout
    ├── stripe-webhook/index.ts             # Handles payment events
    ├── customer-portal/index.ts            # Manage subscription
    └── subscription-status/index.ts        # Check premium status

js/
└── subscription.js                         # Frontend helper class
```

---

## Step 1: Stripe Dashboard Setup

### 1.1 Create Stripe Account
If you don't have one: https://dashboard.stripe.com/register

### 1.2 Create Your Product

1. Go to **Products** → **Add Product**
2. Name: `Quiet Soul`
3. Description: `Premium access to IntrovertPlace - your digital sanctuary`
4. Add two prices:
   - **Monthly**: $6/month, recurring
   - **Yearly**: $55/year, recurring (save ~$17)
5. Copy both **Price IDs** (look like `price_xxxxxxxxxxxxx`)

### 1.3 Get Your API Keys

Go to **Developers** → **API Keys**
- Copy your **Secret key** (starts with `sk_live_` or `sk_test_`)
- For testing, use test mode keys first!

### 1.4 Set Up Webhook

1. Go to **Developers** → **Webhooks** → **Add endpoint**
2. Endpoint URL: `https://<your-project>.supabase.co/functions/v1/stripe-webhook`
3. Select events to listen to:
   - `checkout.session.completed`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_failed`
4. Copy the **Webhook signing secret** (starts with `whsec_`)

---

## Step 2: Supabase Setup

### 2.1 Run the Migration

```bash
cd introvertplace
npx supabase db push
```

Or run the SQL manually in Supabase Dashboard → SQL Editor.

### 2.2 Deploy Edge Functions

```bash
# Deploy all new functions
npx supabase functions deploy create-checkout-session
npx supabase functions deploy stripe-webhook
npx supabase functions deploy customer-portal
npx supabase functions deploy subscription-status
```

### 2.3 Set Environment Variables

In Supabase Dashboard → Project Settings → Edge Functions → Secrets:

```
STRIPE_SECRET_KEY=sk_live_xxxxx (or sk_test_xxxxx for testing)
STRIPE_WEBHOOK_SECRET=whsec_xxxxx
STRIPE_PRICE_MONTHLY=price_xxxxx
STRIPE_PRICE_YEARLY=price_xxxxx
```

---

## Step 3: Frontend Integration

### 3.1 Include the Script

Add to your HTML pages (after Supabase client):

```html
<script src="js/subscription.js"></script>
```

### 3.2 Initialize

```javascript
// After initializing Supabase
const subscriptionManager = new SubscriptionManager(supabase);

// Apply feature gates on page load
document.addEventListener('DOMContentLoaded', () => {
  applyFeatureGates(subscriptionManager);
});
```

### 3.3 Pricing Page Example

```html
<div class="pricing-section">
  <h2>Support the Sanctuary</h2>
  <p>No pressure. When you're ready.</p>
  
  <!-- Show only to free users -->
  <div data-free-only class="pricing-cards">
    <div class="pricing-card">
      <h3>Monthly</h3>
      <p class="price">$6<span>/month</span></p>
      <button onclick="subscriptionManager.startCheckout('monthly')">
        Start Free Trial
      </button>
      <p class="trial-note">14 days free, cancel anytime</p>
    </div>
    
    <div class="pricing-card featured">
      <h3>Yearly</h3>
      <p class="price">$55<span>/year</span></p>
      <p class="savings">Save $17</p>
      <button onclick="subscriptionManager.startCheckout('yearly')">
        Start Free Trial
      </button>
      <p class="trial-note">14 days free, cancel anytime</p>
    </div>
  </div>
  
  <!-- Show only to premium users -->
  <div data-premium-only class="premium-status">
    <p>✨ You're a Quiet Soul member</p>
    <button onclick="subscriptionManager.openCustomerPortal()">
      Manage Subscription
    </button>
  </div>
</div>
```

### 3.4 Feature Gating

Use HTML attributes:

```html
<!-- Only shows for premium users -->
<div data-premium-only>
  <h3>AI Reflections</h3>
  <!-- premium feature content -->
</div>

<!-- Only shows for free users -->
<div data-free-only>
  <p>Upgrade to Quiet Soul to unlock AI Reflections</p>
</div>
```

Or use JavaScript:

```javascript
async function checkFeatureAccess() {
  const isPremium = await subscriptionManager.isPremium();
  
  if (!isPremium) {
    showUpgradeModal();
    return false;
  }
  return true;
}

// Before accessing a premium feature
async function openAIReflection() {
  if (!await checkFeatureAccess()) return;
  // ... do the premium thing
}
```

Or use CSS:

```css
/* Hide premium content for free users */
body.is-free .premium-feature {
  display: none;
}

/* Show upgrade prompts only to free users */
body.is-premium .upgrade-prompt {
  display: none;
}
```

---

## Step 4: Configure Customer Portal

In Stripe Dashboard → Settings → Billing → Customer Portal:

1. Enable the portal
2. Configure what customers can do:
   - ✅ Update payment methods
   - ✅ View invoice history
   - ✅ Cancel subscription
3. Customize branding to match IntrovertPlace

---

## Step 5: Test Everything

### Test Mode Checklist

1. Use test API keys (start with `sk_test_`)
2. Use test card: `4242 4242 4242 4242` (any future date, any CVC)
3. Create a test account
4. Go through checkout flow
5. Verify webhook received in Stripe Dashboard
6. Check `subscriptions` table in Supabase
7. Verify premium features unlock
8. Test cancellation via customer portal

### Test Webhook Locally (Optional)

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Forward webhooks to local
stripe listen --forward-to localhost:54321/functions/v1/stripe-webhook
```

---

## Pricing Summary

Based on our earlier analysis:

| Plan | Price | Trial |
|------|-------|-------|
| Monthly | $6/mo | 14 days |
| Yearly | $55/yr | 14 days |

Free tier includes: basic journal, mood tracking, community read access, 1 breathing exercise.

Quiet Soul includes: unlimited journal + prompts, full wellness toolkit, create in creative spaces, post in communities, social battery insights, mood analytics.

---

## Environment Variables Reference

| Variable | Where to Get It |
|----------|-----------------|
| `STRIPE_SECRET_KEY` | Stripe Dashboard → Developers → API Keys |
| `STRIPE_WEBHOOK_SECRET` | Stripe Dashboard → Developers → Webhooks → Your endpoint |
| `STRIPE_PRICE_MONTHLY` | Stripe Dashboard → Products → Quiet Soul → Monthly price ID |
| `STRIPE_PRICE_YEARLY` | Stripe Dashboard → Products → Quiet Soul → Yearly price ID |

---

## Questions?

Hit me up. Happy to help debug or refine anything. 🤓

— quietsoul
