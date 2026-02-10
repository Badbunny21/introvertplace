/**
 * IntrovertPlace Subscription Manager
 * Handles Stripe integration for Quiet Soul premium tier
 */

class SubscriptionManager {
  constructor(supabaseClient) {
    this.supabase = supabaseClient;
    this.cache = null;
    this.cacheTime = null;
    this.CACHE_DURATION = 60000; // 1 minute
  }

  /**
   * Get current subscription status
   * @returns {Promise<{isPremium: boolean, plan: string, status: string, periodEnd: string|null, cancelAtPeriodEnd: boolean}>}
   */
  async getStatus(forceRefresh = false) {
    // Return cached result if fresh
    if (!forceRefresh && this.cache && this.cacheTime && (Date.now() - this.cacheTime < this.CACHE_DURATION)) {
      return this.cache;
    }

    try {
      const { data: { session } } = await this.supabase.auth.getSession();
      if (!session) {
        return { isPremium: false, plan: 'free', status: 'none', periodEnd: null, cancelAtPeriodEnd: false };
      }

      const response = await this.supabase.functions.invoke('subscription-status');
      
      if (response.error) {
        console.error('Error fetching subscription status:', response.error);
        return { isPremium: false, plan: 'free', status: 'error', periodEnd: null, cancelAtPeriodEnd: false };
      }

      this.cache = response.data;
      this.cacheTime = Date.now();
      return response.data;
    } catch (error) {
      console.error('Subscription status error:', error);
      return { isPremium: false, plan: 'free', status: 'error', periodEnd: null, cancelAtPeriodEnd: false };
    }
  }

  /**
   * Check if user has premium access
   * @returns {Promise<boolean>}
   */
  async isPremium() {
    const status = await this.getStatus();
    return status.isPremium;
  }

  /**
   * Start checkout for premium subscription
   * @param {'monthly' | 'yearly'} priceType
   */
  async startCheckout(priceType = 'monthly') {
    try {
      const { data: { session } } = await this.supabase.auth.getSession();
      if (!session) {
        throw new Error('Please sign in to subscribe');
      }

      const response = await this.supabase.functions.invoke('create-checkout-session', {
        body: { priceType }
      });

      if (response.error) {
        throw new Error(response.error.message || 'Failed to create checkout session');
      }

      // Redirect to Stripe Checkout
      window.location.href = response.data.url;
    } catch (error) {
      console.error('Checkout error:', error);
      throw error;
    }
  }

  /**
   * Open customer portal to manage subscription
   */
  async openCustomerPortal() {
    try {
      const { data: { session } } = await this.supabase.auth.getSession();
      if (!session) {
        throw new Error('Please sign in');
      }

      const response = await this.supabase.functions.invoke('customer-portal');

      if (response.error) {
        throw new Error(response.error.message || 'Failed to open customer portal');
      }

      window.location.href = response.data.url;
    } catch (error) {
      console.error('Customer portal error:', error);
      throw error;
    }
  }

  /**
   * Clear the status cache (call after subscription changes)
   */
  clearCache() {
    this.cache = null;
    this.cacheTime = null;
  }
}

/**
 * Feature gate helper - shows/hides elements based on subscription
 * 
 * Usage in HTML:
 *   <div data-premium-only>This is premium content</div>
 *   <div data-free-only>Upgrade to unlock more features</div>
 */
async function applyFeatureGates(subscriptionManager) {
  const isPremium = await subscriptionManager.isPremium();
  
  // Show/hide premium-only elements
  document.querySelectorAll('[data-premium-only]').forEach(el => {
    el.style.display = isPremium ? '' : 'none';
  });
  
  // Show/hide free-only elements (like upgrade prompts)
  document.querySelectorAll('[data-free-only]').forEach(el => {
    el.style.display = isPremium ? 'none' : '';
  });

  // Add class to body for CSS-based gating
  document.body.classList.toggle('is-premium', isPremium);
  document.body.classList.toggle('is-free', !isPremium);
}

// Export for use
window.SubscriptionManager = SubscriptionManager;
window.applyFeatureGates = applyFeatureGates;
