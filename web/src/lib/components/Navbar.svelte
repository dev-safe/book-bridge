<script>
  import { Menu, X, Github, Download, Sun, Moon } from "lucide-svelte";
  import logo from "$lib/assets/logo.png";
  import { APP_DOWNLOAD_LINK, GITHUB_REPO_LINK } from "$lib/links";
  import { theme } from "$lib/theme.svelte.js";

  let { scrollY = 0 } = $props();
  let isMenuOpen = $state(false);

  function toggleMenu() {
    isMenuOpen = !isMenuOpen;
  }
</script>

<nav class:scrolled={scrollY > 10}>
  <div class="container nav-content">
    <a href="/" class="logo">
      <div class="logo-icon">
        <img src={logo} alt="BookBridge Logo" class="bookbridge-logo" />
      </div>
      <span>BookBridge</span>
    </a>

    <!-- Desktop Nav -->
    <div class="desktop-links">
      <a href="#how-it-works">How it Works</a>
      <a href="#features">Features</a>
      <a href="#app">App</a>

      <!-- Theme Switcher Button -->
      <button 
        class="theme-toggle-btn"
        onclick={() => theme.toggle()}
        aria-label="Toggle theme"
        title={theme.current === 'dark' ? 'Switch to Light Mode' : 'Switch to Dark Mode'}
      >
        {#if theme.current === 'dark'}
          <Sun size={20} class="theme-icon sun" />
        {:else}
          <Moon size={20} class="theme-icon moon" />
        {/if}
      </button>

      <a
        href={GITHUB_REPO_LINK}
        target="_blank"
        rel="noopener noreferrer"
        title="GitHub"
        class="social-link nav-github"
      >
        <Github size={20} />
      </a>
      <a
        href={APP_DOWNLOAD_LINK}
        target="_blank"
        rel="noopener noreferrer"
        class="btn-primary"
        style="text-decoration: none; display: flex; align-items: center; gap: 8px;"
      >
        <Download size={18} /> Download App
      </a>
    </div>

    <!-- Mobile Action Group -->
    <div class="mobile-actions">
      <button 
        class="theme-toggle-btn mobile"
        onclick={() => theme.toggle()}
        aria-label="Toggle theme"
      >
        {#if theme.current === 'dark'}
          <Sun size={20} />
        {:else}
          <Moon size={20} />
        {/if}
      </button>

      <button class="mobile-toggle" onclick={toggleMenu} aria-label="Toggle menu">
        {#if isMenuOpen}
          <X size={24} />
        {:else}
          <Menu size={24} />
        {/if}
      </button>
    </div>
  </div>

  <!-- Mobile Menu -->
  {#if isMenuOpen}
    <div class="mobile-menu">
      <a href="#how-it-works" onclick={toggleMenu}>How it Works</a>
      <a href="#features" onclick={toggleMenu}>Features</a>
      <a href="#app" onclick={toggleMenu}>Mobile App</a>
      <a
        href={GITHUB_REPO_LINK}
        target="_blank"
        rel="noopener noreferrer"
        onclick={toggleMenu}
        style="display: flex; align-items: center; gap: 8px;"
      >
        <Github size={24} /> GitHub
      </a>
      <a
        href={APP_DOWNLOAD_LINK}
        target="_blank"
        rel="noopener noreferrer"
        class="btn-primary"
        style="text-decoration: none; width: 100%; text-align: center;"
        onclick={toggleMenu}
      >
        Download App
      </a>
    </div>
  {/if}
</nav>

<style>
  /* Navbar Styles */
  nav {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    z-index: 1000;
    padding: 1.2rem 0;
    transition: all 0.3s ease;
    background-color: transparent;
  }

  nav.scrolled {
    background-color: var(--nav-bg-scrolled);
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    padding: 0.8rem 0;
    box-shadow: var(--shadow-sm);
    border-bottom: 1px solid var(--border-subtle);
  }

  .nav-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .logo {
    display: flex;
    align-items: center;
    gap: 0.8rem;
    font-size: 1.3rem;
    font-weight: 700;
    color: var(--scholar-blue);
    font-family: var(--font-header);
    letter-spacing: -0.5px;
    text-decoration: none;
  }

  .bookbridge-logo {
    height: 32px;
    width: auto;
    border-radius: 8px;
  }

  .logo-icon {
    background-color: transparent;
    padding: 0;
    border-radius: 0;
  }

  /* Desktop Nav */
  .desktop-links {
    display: flex;
    align-items: center;
    gap: 2rem;
  }

  .desktop-links a:not(.btn-primary) {
    font-weight: 500;
    font-size: 0.95rem;
    color: var(--text-primary);
    position: relative;
    text-decoration: none;
  }

  .desktop-links a:not(.btn-primary):hover {
    color: var(--scholar-blue);
  }

  /* Theme Toggle Button */
  .theme-toggle-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 40px;
    height: 40px;
    border-radius: 12px;
    background: var(--bg-tertiary);
    color: var(--text-primary);
    border: 1px solid var(--border-subtle);
    cursor: pointer;
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .theme-toggle-btn:hover {
    background: var(--scholar-blue-light);
    color: var(--scholar-blue);
    transform: rotate(15deg) scale(1.05);
  }

  .mobile-actions {
    display: none;
    align-items: center;
    gap: 0.8rem;
  }

  /* Mobile Menu Toggle */
  .mobile-toggle {
    background: transparent;
    border: none;
    color: var(--text-primary);
    cursor: pointer;
    z-index: 1001;
  }

  .mobile-menu {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: var(--bg-secondary);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 2rem;
    padding: 2rem;
    z-index: 999;
  }

  .mobile-menu a {
    font-size: 1.25rem;
    color: var(--text-primary);
    font-weight: 600;
    text-decoration: none;
  }

  .social-link {
    display: flex;
    align-items: center;
    color: var(--text-primary);
    transition: all 0.3s ease;
    text-decoration: none;
  }

  .social-link:hover {
    color: var(--scholar-blue);
    transform: translateY(-3px);
  }

  @media (max-width: 768px) {
    .desktop-links {
      display: none;
    }
    .mobile-actions {
      display: flex;
    }
  }

  @media (max-width: 400px) {
    nav {
      padding: 0.8rem 0;
    }

    .logo {
      font-size: 1.1rem;
    }

    .bookbridge-logo {
      height: 28px;
    }
  }
</style>
