<script>
  import { Search, MessageCircle, MapPin, Camera, Upload, CreditCard } from "lucide-svelte";
  
  let activeTab = $state("buyer");

  /** @param {string} tab */
  function setTab(tab) {
    activeTab = tab;
  }
</script>

<section id="how-it-works" class="how-it-works">
  <div class="container">
    <div class="section-header">
      <span class="section-tag">Simple Process</span>
      <h2>How BookBridge Works</h2>
      <p>Whether you're buying or selling, we make it simple and secure.</p>
    </div>

    <div class="tabs-container">
      <div class="tabs">
        <button
          class="tab-btn {activeTab === 'buyer' ? 'active' : ''}"
          onclick={() => setTab("buyer")}
        >
          I want to Buy
        </button>
        <button
          class="tab-btn {activeTab === 'seller' ? 'active' : ''}"
          onclick={() => setTab("seller")}
        >
          I want to Sell
        </button>
      </div>
    </div>

    <div class="steps-grid">
      {#if activeTab === "buyer"}
        <!-- Buyer Steps -->
        <div class="step-card">
          <div class="step-number">01</div>
          <div class="step-icon">
            <Search size={32} />
          </div>
          <h3>Discover</h3>
          <p>
            Search for the books you need by title, author, or university
            level.
          </p>
        </div>
        <div class="step-card">
          <div class="step-number">02</div>
          <div class="step-icon">
            <MessageCircle size={32} />
          </div>
          <h3>Connect</h3>
          <p>
            Chat directly with sellers to ask questions and negotiate usage.
          </p>
        </div>
        <div class="step-card">
          <div class="step-number">03</div>
          <div class="step-icon">
            <MapPin size={32} />
          </div>
          <h3>Meet Up</h3>
          <p>
            Arrange a safe meeting spot on campus to inspect and collect your
            book.
          </p>
        </div>
      {:else}
        <!-- Seller Steps -->
        <div class="step-card">
          <div class="step-number">01</div>
          <div class="step-icon">
            <Camera size={32} />
          </div>
          <h3>Snap</h3>
          <p>
            Take a few clear photos of your textbook and scan the ISBN bar
            code.
          </p>
        </div>
        <div class="step-card">
          <div class="step-number">02</div>
          <div class="step-icon">
            <Upload size={32} />
          </div>
          <h3>List</h3>
          <p>
            Set your price and condition. Your listing goes live instantly.
          </p>
        </div>
        <div class="step-card">
          <div class="step-number">03</div>
          <div class="step-icon">
            <CreditCard size={32} />
          </div>
          <h3>Earn</h3>
          <p>
            Meet the buyer, hand over the book, and get paid cash or mobile
            money.
          </p>
        </div>
      {/if}
    </div>
  </div>
</section>

<style>
  /* How it Works */
  .how-it-works {
    padding: 8rem 0;
    background-color: var(--bg-secondary);
    transition: background-color 0.3s ease;
  }

  .section-tag {
    display: inline-block;
    color: var(--scholar-blue);
    font-weight: 600;
    font-size: 0.9rem;
    padding: 0.3rem 1rem;
    background-color: var(--scholar-blue-light);
    border-radius: 20px;
    margin-bottom: 1rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .section-header {
    text-align: center;
    margin-bottom: 4rem;
  }

  .section-header h2 {
    font-size: 2.5rem;
    margin-bottom: 1rem;
    color: var(--text-primary);
  }

  .section-header p {
    color: var(--text-secondary);
    font-size: 1.1rem;
    max-width: 600px;
    margin: 0 auto;
  }

  .tabs-container {
    display: flex;
    justify-content: center;
    margin-bottom: 4rem;
  }

  .tabs {
    background: var(--bg-tertiary);
    padding: 0.5rem;
    border-radius: 100px;
    display: flex;
    gap: 0.5rem;
    border: 1px solid var(--border-subtle);
  }

  .tab-btn {
    padding: 0.8rem 2.5rem;
    border-radius: 100px;
    font-size: 1rem;
    font-weight: 600;
    color: var(--text-secondary);
    background: transparent;
    transition: all 0.3s ease;
    border: none;
    cursor: pointer;
  }

  .tab-btn.active {
    background: var(--bg-card);
    color: var(--scholar-blue);
    box-shadow: var(--shadow-sm);
  }

  .steps-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 3rem;
    max-width: 1100px;
    margin: 0 auto;
  }

  .step-card {
    text-align: center;
    position: relative;
    padding: 2rem;
  }

  .step-number {
    font-size: 5rem;
    font-weight: 800;
    color: var(--bg-tertiary);
    position: absolute;
    top: 0;
    left: 50%;
    transform: translateX(-50%);
    z-index: 0;
    opacity: 0.8;
  }

  .step-icon {
    width: 80px;
    height: 80px;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0 auto 1.5rem;
    box-shadow: var(--shadow-md);
    position: relative;
    z-index: 1;
    color: var(--scholar-blue);
  }

  .step-card h3 {
    font-size: 1.5rem;
    margin-bottom: 1rem;
    position: relative;
    z-index: 1;
    color: var(--text-primary);
  }

  .step-card p {
    color: var(--text-secondary);
    position: relative;
    z-index: 1;
  }

  @media (max-width: 768px) {
    .steps-grid {
      grid-template-columns: 1fr;
      gap: 1rem;
    }
    .how-it-works {
      padding: 4rem 0;
    }
  }
</style>
