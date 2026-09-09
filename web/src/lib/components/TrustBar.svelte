<section class="trust-bar">
  <div class="container trust-content">
    <div class="trust-item">
      <h2>5k+</h2>
      <p>Books Listed</p>
    </div>
    <div class="divider"></div>
    <div class="trust-item">
      <h2>15%</h2>
      <p>Cheaper than Retail</p>
    </div>
    <div class="divider"></div>
    <div class="trust-item">
      <h2>4</h2>
      <p>Major Cities</p>
    </div>
    <div class="divider"></div>
    <div class="trust-item">
      <h2>100%</h2>
      <p>Secure</p>
    </div>
  </div>
</section>

<style>
  /* Trust Bar */
  .trust-bar {
    background-color: var(--scholar-blue);
    padding: 3rem 0;
    color: white;
  }

  .trust-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .trust-item {
    text-align: center;
  }

  .trust-item h2 {
    font-size: 2.5rem;
    color: white; /* Override default blue */
    margin-bottom: 0.2rem;
  }

  .trust-item p {
    font-weight: 500;
    opacity: 0.8;
  }

  .divider {
    width: 1px;
    height: 50px;
    background-color: rgba(255, 255, 255, 0.2);
  }

  @media (max-width: 768px) {
    .trust-content {
      flex-wrap: wrap;
      justify-content: center;
      gap: 2rem;
    }
    .divider {
      display: none;
    }
    .trust-item {
      min-width: 150px;
    }
  }
</style>
