<script>
  import { Github, MessageCircle, Linkedin, Youtube, Instagram, Facebook } from "lucide-svelte";
  import logo from "$lib/assets/logo.png";
  import { 
    GITHUB_REPO_LINK,
    WHATSAPP_COMMUNITY_LINK,
    LINKEDIN_PROFILE_LINK,
    YOUTUBE_CHANNEL_LINK,
    INSTAGRAM_PROFILE_LINK,
    FACEBOOK_PAGE_LINK
  } from "$lib/links";
</script>

<footer>
  <div class="container footer-content">
    <div class="footer-brand">
      <div class="logo">
        <div class="logo-icon">
          <img src={logo} alt="BookBridge Logo" class="bookbridge-logo" />
        </div>
        <span>BookBridge</span>
      </div>
      <p>
        Sustainable reading for every student. Join the circular economy and
        save money on education.
      </p>
      <div class="social-icons">
        <a
          href={WHATSAPP_COMMUNITY_LINK}
          target="_blank"
          rel="noopener noreferrer"
          title="WhatsApp Community"
          class="social-link"
        >
          <MessageCircle size={20} />
          <span>WhatsApp</span>
        </a>
        <a
          href={LINKEDIN_PROFILE_LINK}
          target="_blank"
          rel="noopener noreferrer"
          title="LinkedIn"
          class="social-link"
        >
          <Linkedin size={20} />
          <span>LinkedIn</span>
        </a>
        <a
          href={YOUTUBE_CHANNEL_LINK}
          target="_blank"
          rel="noopener noreferrer"
          title="YouTube"
          class="social-link"
        >
          <Youtube size={20} />
          <span>YouTube</span>
        </a>
        <a
          href={INSTAGRAM_PROFILE_LINK}
          target="_blank"
          rel="noopener noreferrer"
          title="Instagram"
          class="social-link"
        >
          <Instagram size={20} />
          <span>Instagram</span>
        </a>
        <a
          href={FACEBOOK_PAGE_LINK}
          target="_blank"
          rel="noopener noreferrer"
          title="Facebook"
          class="social-link"
        >
          <Facebook size={20} />
          <span>Facebook</span>
        </a>
        <a
          href={GITHUB_REPO_LINK}
          target="_blank"
          rel="noopener noreferrer"
          title="GitHub"
          class="social-link"
        >
          <Github size={20} />
          <span>GitHub</span>
        </a>
      </div>
    </div>

    <div class="footer-links-group">
      <div class="link-column">
        <h3>Platform</h3>
        <a href="#how-it-works">How it Works</a>
        <a href="#features">Features</a>
        <a href="#app">Download</a>
      </div>
      <div class="link-column">
        <h3>Support</h3>
        <a href="#how-it-works">Help Center</a>
        <a href="#founder">About Founder</a>
        <a href={WHATSAPP_COMMUNITY_LINK} target="_blank" rel="noopener noreferrer">Community</a>
      </div>
      <div class="link-column">
        <h3>Legal</h3>
        <a href="/privacy">Privacy Policy</a>
        <a href="/terms">Terms of Service</a>
      </div>
    </div>
  </div>

  <div class="container footer-bottom">
    <p>&copy; {new Date().getFullYear()} BookBridge. Built for Cameroonian Students.</p>
  </div>
</footer>

<style>
  footer {
    background-color: var(--bg-secondary);
    border-top: 1px solid var(--border-color);
    padding: 6rem 0 3rem;
    transition: background-color 0.3s ease, border-color 0.3s ease;
  }

  .footer-content {
    display: grid;
    grid-template-columns: 1.5fr 2fr;
    gap: 4rem;
    margin-bottom: 4rem;
  }

  .logo {
    display: flex;
    align-items: center;
    gap: 0.8rem;
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--scholar-blue);
    font-family: var(--font-header);
    margin-bottom: 1.5rem;
  }

  .bookbridge-logo {
    height: 36px;
    width: auto;
    border-radius: 8px;
  }

  .footer-brand p {
    color: var(--text-secondary);
    font-size: 1rem;
    line-height: 1.6;
    margin-bottom: 2rem;
    max-width: 380px;
  }

  .social-icons {
    display: flex;
    flex-wrap: wrap;
    gap: 0.8rem;
  }

  .social-link {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 1rem;
    border-radius: 10px;
    background: var(--bg-tertiary);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
    font-size: 0.85rem;
    font-weight: 500;
    transition: all 0.3s ease;
  }

  .social-link:hover {
    color: var(--scholar-blue);
    background: var(--scholar-blue-light);
    border-color: var(--scholar-blue);
    transform: translateY(-2px);
  }

  .footer-links-group {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 2rem;
  }

  .link-column h3 {
    font-size: 1.1rem;
    color: var(--text-primary);
    margin-bottom: 1.5rem;
    font-family: var(--font-header);
  }

  .link-column a {
    display: block;
    color: var(--text-secondary);
    margin-bottom: 0.8rem;
    font-size: 0.95rem;
    transition: all 0.2s ease;
  }

  .link-column a:hover {
    color: var(--scholar-blue);
    transform: translateX(3px);
  }

  .footer-bottom {
    border-top: 1px solid var(--border-color);
    padding-top: 2rem;
    text-align: center;
    color: var(--text-secondary);
    font-size: 0.9rem;
  }

  @media (max-width: 900px) {
    .footer-content {
      grid-template-columns: 1fr;
      gap: 3rem;
    }
  }

  @media (max-width: 600px) {
    .footer-links-group {
      grid-template-columns: 1fr 1fr;
    }
  }
</style>
