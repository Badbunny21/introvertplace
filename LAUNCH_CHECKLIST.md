# IntrovertPlace Launch Checklist 🚀

## Phase 1: Payment Ready ✨

### Stripe Setup
- [ ] Create Stripe account (stripe.com)
- [ ] Create product "Quiet Soul" with two prices:
  - Monthly: $6/month
  - Yearly: $55/year
- [ ] Copy Price IDs (look like `price_xxxxx`)
- [ ] Get API keys (Developers → API Keys)
- [ ] Set up webhook endpoint pointing to your Supabase function

### Supabase Setup
- [ ] Run database migrations:
  ```bash
  npx supabase db push
  ```
- [ ] Add secrets (Project Settings → Edge Functions → Secrets):
  - `STRIPE_SECRET_KEY`
  - `STRIPE_WEBHOOK_SECRET`
  - `STRIPE_PRICE_MONTHLY`
  - `STRIPE_PRICE_YEARLY`
- [ ] Deploy edge functions:
  ```bash
  npx supabase functions deploy create-checkout-session
  npx supabase functions deploy stripe-webhook
  npx supabase functions deploy customer-portal
  npx supabase functions deploy subscription-status
  ```

### Test Payment Flow
- [ ] Create test account on your site
- [ ] Try subscribing (use Stripe test card: 4242 4242 4242 4242)
- [ ] Verify subscription shows in Supabase `subscriptions` table
- [ ] Test customer portal (manage/cancel subscription)
- [ ] Test with real card (small amount, then refund)

---

## Phase 2: Bug Hunt 🐛

### Test Every Page
- [ ] Landing page (index.html) — all links work?
- [ ] Sign up / Sign in flow
- [ ] Profile page — can edit, save?
- [ ] Wellness page — all features work?
- [ ] Creative page — can create/view?
- [ ] Connect page — communities work? Posts work?
- [ ] Blog page — loads correctly?

### Test on Different Devices
- [ ] Desktop (Chrome, Firefox, Safari)
- [ ] Mobile phone
- [ ] Tablet

### Common Issues to Check
- [ ] Forms submit correctly
- [ ] Error messages show when needed
- [ ] Loading states appear
- [ ] No console errors (F12 → Console)
- [ ] Images load properly
- [ ] Links don't 404

---

## Phase 3: Pre-Launch Polish 💅

- [ ] Pricing page with clear tiers
- [ ] Terms of Service page
- [ ] Privacy Policy page
- [ ] Contact/Support info
- [ ] Social media links
- [ ] Favicon and meta tags for sharing

---

## Phase 4: Get Users 📣

### Free Promotion (Start Here)

**Reddit (best for introverts!)**
- [ ] r/introvert (780k members)
- [ ] r/infp, r/infj, r/intj, r/intp (personality types)
- [ ] r/socialanxiety
- [ ] r/selfimprovement
- [ ] Don't spam — share genuinely, ask for feedback

**Twitter/X**
- [ ] Create account @introvertplace
- [ ] Post about introvert life, mental health, quiet moments
- [ ] Use hashtags: #introvert #mentalhealth #selfcare #quietlife
- [ ] Engage with introvert community

**TikTok**
- [ ] Short videos about introvert struggles/wins
- [ ] "POV: You finally found your people" vibes
- [ ] Show the app in action

**Product Hunt**
- [ ] Prepare launch (good screenshots, description)
- [ ] Launch on a Tuesday/Wednesday
- [ ] Ask friends to upvote

**Communities**
- [ ] Discord servers for introverts
- [ ] Facebook groups
- [ ] Online forums

### Content Marketing (Ongoing)
- [ ] Blog posts about introvert topics
- [ ] "Social battery" content
- [ ] "How to say no gracefully"
- [ ] Guest posts on mental health blogs

### Paid (Later, Once Validated)
- [ ] Instagram/TikTok ads targeting introverts
- [ ] Google ads for "introvert community"
- [ ] Influencer partnerships (small mental health creators)

---

## Launch Day Checklist

- [ ] Everything tested and working
- [ ] Payment flow verified
- [ ] Post on Reddit (genuine, ask for feedback)
- [ ] Post on Twitter
- [ ] Tell friends and family
- [ ] Monitor for issues
- [ ] Respond to feedback quickly

---

## Success Metrics (First Month)

- [ ] 100 sign-ups
- [ ] 10 paid subscribers
- [ ] No critical bugs
- [ ] At least 5 community posts
- [ ] Some positive feedback

---

*You've built something real. Now let's get it into people's hands.* 🌙
