<script>
  import { Github, Linkedin, Youtube, Instagram, Facebook } from "lucide-svelte";
  import founderImg from "$lib/assets/Founder.jpg";
  import { 
    GITHUB_REPO_LINK,
    LINKEDIN_PROFILE_LINK,
    YOUTUBE_CHANNEL_LINK,
    INSTAGRAM_PROFILE_LINK,
    FACEBOOK_PAGE_LINK
  } from "$lib/links";
</script>

<section id="founder" class="founder-section">
  <div class="container">
    <div class="section-header">
      <span class="section-tag">The Visionary</span>
      <h2>Behind BookBridge</h2>
      <p>Empowering students in Cameroon through technology and community-driven circular economy.</p>
    </div>

    <div class="founder-grid">
      <div class="founder-image-container">
        <div class="image-wrapper">
          <img src={founderImg} alt="VERLA BERINYUY" class="founder-image" />
          <div class="badge">Mr.DCT</div>
        </div>
        <div class="decorator-blob-1"></div>
        <div class="decorator-blob-2"></div>
      </div>

      <div class="founder-info">
        <div class="founder-header">
          <h3>VERLA BERINYUY NDEY</h3>
          <span class="title">Founder & Lead Developer</span>
        </div>

        <div class="founder-quote">
          <blockquote>
            "Bridging the Textbook Gap. One Student at a Time."
          </blockquote>
        </div>

        <div class="founder-bio">
          <p>
            My name is <strong>Verla Berinyuy Ndey</strong> — I go by <strong>Mr. DCT</strong> (which stands for <em>Deep Code Thinking</em>). I'm a cybersecurity and software engineering student at ICT University, a self-taught full-stack developer, and the founder of BookBridge.
          </p>
          <p>
            This mission is deeply personal. After passing my O-Level and A-Level GCE Exams in high school, I found myself with stacks of unused textbooks and pamphlets, but no way to find the students who needed them. Every year, over 2 million students in Cameroon need textbooks they cannot afford — while other students have those exact books sitting unused on their shelves. The solution exists, but what was missing was <strong>trust</strong>.
          </p>
          <p>
            I built BookBridge specifically for Cameroonian students to solve this. Equipped with secure mobile money escrow payments, verified seller ratings, and real-time social impact tracking, BookBridge is live at version 1.5.0 on GitHub, with over 50+ real students already actively using the platform.
          </p>
        </div>

        <div class="social-links-wrapper">
          <span class="connect-label">Connect with Mr.DCT:</span>
          <div class="social-links">
            <a 
              href={LINKEDIN_PROFILE_LINK} 
              target="_blank" 
              rel="noopener noreferrer" 
              class="social-btn linkedin"
              title="LinkedIn"
            >
              <Linkedin size={20} />
            </a>
            <a 
              href="https://github.com/DCT-Berinyuy" 
              target="_blank" 
              rel="noopener noreferrer" 
              class="social-btn github"
              title="GitHub"
            >
              <Github size={20} />
            </a>
            <a 
              href={YOUTUBE_CHANNEL_LINK} 
              target="_blank" 
              rel="noopener noreferrer" 
              class="social-btn youtube"
              title="YouTube"
            >
              <Youtube size={20} />
            </a>
            <a 
              href={INSTAGRAM_PROFILE_LINK} 
              target="_blank" 
              rel="noopener noreferrer" 
              class="social-btn instagram"
              title="Instagram"
            >
              <Instagram size={20} />
            </a>
            <a 
              href={FACEBOOK_PAGE_LINK} 
              target="_blank" 
              rel="noopener noreferrer" 
              class="social-btn facebook"
              title="Facebook"
            >
              <Facebook size={20} />
            </a>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>

<style>
  .founder-section {
    padding: 8rem 0;
    background-color: var(--bg-primary);
    position: relative;
    overflow: hidden;
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
    margin-bottom: 5rem;
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

  .founder-grid {
    display: grid;
    grid-template-columns: 1.1fr 1.9fr;
    gap: 5rem;
    align-items: center;
    max-width: 1100px;
    margin: 0 auto;
    background: var(--bg-card);
    border-radius: 28px;
    padding: 4rem;
    box-shadow: var(--shadow-lg);
    border: 1px solid var(--border-color);
    position: relative;
    z-index: 2;
    transition: background-color 0.3s ease, border-color 0.3s ease;
  }

  .founder-image-container {
    position: relative;
    width: 100%;
    display: flex;
    justify-content: center;
  }

  .image-wrapper {
    position: relative;
    border-radius: 24px;
    overflow: hidden;
    box-shadow: var(--shadow-md);
    z-index: 2;
    aspect-ratio: 4 / 5;
    width: 100%;
    max-width: 320px;
    border: 6px solid var(--bg-card);
  }

  .founder-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
    transition: transform 0.5s ease;
  }

  .image-wrapper:hover .founder-image {
    transform: scale(1.05);
  }

  .badge {
    position: absolute;
    bottom: 20px;
    right: 20px;
    background: var(--scholar-blue);
    color: #ffffff;
    padding: 0.5rem 1.2rem;
    border-radius: 100px;
    font-weight: 700;
    font-size: 0.85rem;
    letter-spacing: 0.5px;
    box-shadow: 0 10px 25px rgba(59, 130, 246, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.2);
  }

  .decorator-blob-1 {
    position: absolute;
    width: 140px;
    height: 140px;
    background: linear-gradient(135deg, var(--emerald-green), #5cdb95);
    border-radius: 30% 70% 70% 30% / 30% 30% 70% 70%;
    top: -20px;
    left: -20px;
    z-index: 1;
    opacity: 0.2;
    filter: blur(10px);
    animation: blob-bounce 8s infinite alternate;
  }

  .decorator-blob-2 {
    position: absolute;
    width: 160px;
    height: 160px;
    background: linear-gradient(135deg, var(--scholar-blue), #3b82f6);
    border-radius: 50% 50% 30% 70% / 50% 60% 40% 50%;
    bottom: -30px;
    right: -10px;
    z-index: 1;
    opacity: 0.15;
    filter: blur(12px);
    animation: blob-bounce 10s infinite alternate-reverse;
  }

  .founder-info {
    display: flex;
    flex-direction: column;
    justify-content: center;
  }

  .founder-header h3 {
    font-size: 2rem;
    margin-bottom: 0.3rem;
    color: var(--text-primary);
    letter-spacing: -0.5px;
  }

  .founder-header .title {
    font-size: 1.05rem;
    color: var(--scholar-blue);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 1px;
  }

  .founder-quote {
    position: relative;
    margin: 2rem 0;
    padding: 1rem 0 1rem 1.8rem;
    border-left: 4px solid var(--emerald-green);
  }

  .founder-quote blockquote {
    font-size: 1.15rem;
    line-height: 1.6;
    font-style: italic;
    color: var(--text-primary);
    font-weight: 500;
  }

  .founder-bio p {
    font-size: 1.05rem;
    color: var(--text-secondary);
    line-height: 1.7;
    margin-bottom: 1.2rem;
  }

  .founder-bio p:last-child {
    margin-bottom: 0;
  }

  .social-links-wrapper {
    margin-top: 2.5rem;
    border-top: 1px solid var(--border-color);
    padding-top: 1.5rem;
  }

  .connect-label {
    display: block;
    font-size: 0.9rem;
    font-weight: 600;
    color: var(--text-primary);
    margin-bottom: 1rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .social-links {
    display: flex;
    gap: 1rem;
  }

  .social-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 44px;
    height: 44px;
    border-radius: 12px;
    color: var(--text-primary);
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .social-btn:hover {
    transform: translateY(-3px);
    color: #ffffff;
    box-shadow: 0 10px 20px rgba(0, 0, 0, 0.15);
  }

  .social-btn.linkedin:hover {
    background-color: #0077b5;
    border-color: #0077b5;
  }

  .social-btn.github:hover {
    background-color: #24292e;
    border-color: #24292e;
  }

  .social-btn.youtube:hover {
    background-color: #ff0000;
    border-color: #ff0000;
  }

  .social-btn.instagram:hover {
    background: radial-gradient(circle at 30% 107%, #fdf497 0%, #fdf497 5%, #fd5949 45%, #d6249f 60%, #285aeb 90%);
    border-color: transparent;
  }

  .social-btn.facebook:hover {
    background-color: #1877f2;
    border-color: #1877f2;
  }

  @keyframes blob-bounce {
    0% {
      transform: translate(0, 0) scale(1);
    }
    100% {
      transform: translate(15px, -15px) scale(1.08);
    }
  }

  @media (max-width: 992px) {
    .founder-grid {
      grid-template-columns: 1fr;
      gap: 3.5rem;
      padding: 3rem;
    }

    .founder-image-container {
      max-width: 280px;
      margin: 0 auto;
    }

    .founder-header {
      text-align: center;
    }

    .founder-quote {
      margin: 1.5rem 0;
    }

    .social-links-wrapper {
      text-align: center;
    }

    .social-links {
      justify-content: center;
    }
  }

  @media (max-width: 768px) {
    .founder-section {
      padding: 5rem 0;
    }

    .section-header h2 {
      font-size: 2rem;
    }

    .founder-header h3 {
      font-size: 1.75rem;
    }
  }

  @media (max-width: 480px) {
    .founder-grid {
      padding: 2rem 1.5rem;
      border-radius: 20px;
    }

    .founder-bio p {
      font-size: 0.95rem;
    }

    .founder-quote blockquote {
      font-size: 1.05rem;
    }
  }
</style>
