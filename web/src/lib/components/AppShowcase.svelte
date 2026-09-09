<script>
  import { Download, Smartphone, Apple } from "lucide-svelte";
  import { APP_DOWNLOAD_LINK } from "$lib/links";
</script>

<section id="app" class="app-showcase">
  <div class="container showcase-box">
    <div class="showcase-content">
      <h2>Your Library in Your Pocket</h2>
      <p>
        Download BookBridge today and join the fastest growing student
        community in Cameroon.
      </p>
      <div class="store-buttons">
        <a
          href={APP_DOWNLOAD_LINK}
          target="_blank"
          rel="noopener noreferrer"
          class="store-btn android"
        >
          <Download size={24} />
          <div class="btn-text">
            <span>Download APK</span>
            <strong>Direct Download</strong>
          </div>
        </a>
        <!-- Placeholder for Play Store -->
        <button class="store-btn other" disabled>
          <Smartphone size={24} />
          <div class="btn-text">
            <span>Coming soon to</span>
            <strong>Play Store</strong>
          </div>
        </button>
        <!-- Placeholder for App Store -->
        <button class="store-btn other" disabled>
          <Apple size={24} />
          <div class="btn-text">
            <span>Coming soon to</span>
            <strong>App Store</strong>
          </div>
        </button>
      </div>
    </div>
  </div>
</section>

<style>
  /* App Showcase */
  .app-showcase {
    padding: 2rem 0 6rem;
    background-color: var(--bg-primary);
    transition: background-color 0.3s ease;
  }

  .showcase-box {
    background-color: var(--scholar-blue);
    border-radius: 40px;
    padding: 6rem;
    text-align: center;
    color: white;
    background-image: linear-gradient(
      135deg,
      rgba(255, 255, 255, 0.15) 0%,
      rgba(0, 0, 0, 0.2) 100%
    );
    box-shadow: var(--shadow-lg);
    border: 1px solid var(--border-subtle);
  }

  .showcase-content h2 {
    font-size: 3rem;
    margin-bottom: 1.5rem;
    color: white;
  }

  .showcase-content p {
    font-size: 1.25rem;
    margin-bottom: 3rem;
    opacity: 0.9;
    max-width: 600px;
    margin-left: auto;
    margin-right: auto;
    color: rgba(255, 255, 255, 0.9);
  }

  .store-buttons {
    display: flex;
    justify-content: center;
    gap: 1.5rem;
    flex-wrap: wrap;
  }

  .store-btn {
    display: flex;
    align-items: center;
    gap: 1rem;
    background: var(--bg-card);
    color: var(--text-primary);
    padding: 0.8rem 1.8rem;
    border-radius: 12px;
    text-decoration: none;
    transition: all 0.3s ease;
    border: 1px solid var(--border-color);
    box-shadow: var(--shadow-md);
  }

  .store-btn.android:hover {
    transform: translateY(-3px);
    box-shadow: 0 15px 30px rgba(0, 0, 0, 0.25);
  }

  .store-btn.other {
    opacity: 0.7;
    cursor: not-allowed;
    background: var(--bg-tertiary);
    color: var(--text-muted);
  }

  .btn-text {
    display: flex;
    flex-direction: column;
    text-align: left;
  }

  .btn-text span {
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .btn-text strong {
    font-size: 1rem;
    font-weight: 700;
  }

  @media (max-width: 768px) {
    .showcase-box {
      padding: 3rem 1.5rem;
      border-radius: 24px;
    }

    .showcase-content h2 {
      font-size: 2.2rem;
    }

    .showcase-content p {
      font-size: 1rem;
    }

    .store-buttons {
      flex-direction: column;
      align-items: stretch;
    }

    .store-btn {
      justify-content: center;
    }
  }
</style>
