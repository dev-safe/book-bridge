<script>
  import { Search, Smartphone, ShieldCheck, Heart } from "lucide-svelte";
</script>

<section id="features" class="features">
  <div class="container">
    <div class="section-header">
      <span class="section-tag">Why Us</span>
      <h2>Designed for Students</h2>
    </div>

    <div class="features-grid">
      <div class="feature-card">
        <div class="icon-box green">
          <Search size={24} color="var(--emerald-green)" />
        </div>
        <h3>Smart Search</h3>
        <p>Filter by university, level (Level 1, Level 2...), and major.</p>
      </div>

      <div class="feature-card">
        <div class="icon-box blue">
          <Smartphone size={24} color="var(--scholar-blue)" />
        </div>
        <h3>Lightweight App</h3>
        <p>Optimized for low data usage and works on all Android devices.</p>
      </div>

      <div class="feature-card">
        <div class="icon-box gold">
          <ShieldCheck size={24} color="#f59e0b" />
        </div>
        <h3>Verified Users</h3>
        <p>Sign up with your student email or phone number for safety.</p>
      </div>

      <div class="feature-card">
        <div class="icon-box red">
          <Heart size={24} color="#ef4444" />
        </div>
        <h3>Community First</h3>
        <p>Rate sellers and help build a trusted network of scholars.</p>
      </div>
    </div>
  </div>
</section>

<style>
  /* Features */
  .features {
    padding: 6rem 0 8rem;
    background-color: var(--bg-primary);
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

  .features-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 2rem;
  }

  .feature-card {
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    padding: 2rem;
    border-radius: 20px;
    transition: all 0.3s ease;
    border-bottom: 4px solid transparent;
  }

  .feature-card h3 {
    color: var(--text-primary);
    margin-bottom: 0.8rem;
    font-size: 1.25rem;
  }

  .feature-card p {
    color: var(--text-secondary);
    font-size: 0.95rem;
    line-height: 1.5;
  }

  .feature-card:hover {
    transform: translateY(-10px);
    box-shadow: var(--shadow-md);
    border-bottom-color: var(--scholar-blue);
  }

  .icon-box {
    width: 50px;
    height: 50px;
    border-radius: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 1.5rem;
    background: var(--bg-tertiary);
  }

  @media (max-width: 1024px) {
    .features-grid {
      grid-template-columns: repeat(2, 1fr);
    }
  }

  @media (max-width: 600px) {
    .features-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
