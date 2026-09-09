<script>
  import { Star, Download, CheckCircle, MessageCircle } from "lucide-svelte";
  import screenshot from "$lib/assets/screenshot.png";
  import { APP_DOWNLOAD_LINK } from "$lib/links";
</script>

<section id="hero" class="hero">
  <div class="container hero-container">
    <div class="hero-content">
      <div class="badge-container">
        <span class="badge">
          <Star size={14} fill="var(--scholar-blue)" strokeWidth={0} />
          #1 Student Marketplace in Cameroon
        </span>
      </div>
      <h1>
        Buy. Sell. <br />
        <span class="highlight">Connect.</span>
      </h1>
      <p class="hero-sub">
        The easiest way for students in Yaoundé, Buea, Douala, and Bamenda to
        trade textbooks. Save money, reduce waste, and build your library.
      </p>

      <div class="hero-actions">
        <a
          href={APP_DOWNLOAD_LINK}
          target="_blank"
          rel="noopener noreferrer"
          class="btn-primary-lg"
        >
          <Download size={20} /> Download App
        </a>
        <a href="#how-it-works" class="btn-secondary-lg"> How it Works </a>
      </div>

      <div class="trust-avatars">
        <div class="avatar-group">
          <!-- Placeholders for avatars -->
          <div class="avatar" style="background-color: #3b82f6;"></div>
          <div class="avatar" style="background-color: #10b981;"></div>
          <div class="avatar" style="background-color: #8b5cf6;"></div>
          <div class="avatar" style="background-color: #f59e0b;"></div>
        </div>
        <p>Joined by <strong>2,000+</strong> students</p>
      </div>
    </div>

    <div class="hero-image">
      <div class="phone-mockup">
        <div class="phone-screen">
          <img src={screenshot} alt="BookBridge App" class="app-screen" />
        </div>
        <div class="mockup-reflection"></div>
      </div>

      <!-- Floating Elements -->
      <div class="float-card card-1">
        <div class="icon-circle green"><CheckCircle size={16} /></div>
        <span>Book Sold!</span>
        <span class="price">+ 5,000 XAF</span>
      </div>

      <div class="float-card card-2">
        <div class="icon-circle blue"><MessageCircle size={16} /></div>
        <span>New Message</span>
        <span class="sub">Is this available?</span>
      </div>
    </div>
  </div>
</section>

<style>
  /* Hero Section */
  .hero {
    position: relative;
    padding-top: 8rem; /* Nav height + spacing */
    padding-bottom: 6rem;
    overflow: hidden;
    background: radial-gradient(
        circle at top right,
        rgba(46, 204, 113, 0.06),
        transparent 40%
      ),
      radial-gradient(
        circle at bottom left,
        rgba(26, 77, 140, 0.08),
        transparent 40%
      );
  }

  .hero-container {
    display: grid;
    grid-template-columns: 1.1fr 0.9fr;
    align-items: center;
    gap: 4rem;
  }

  .badge-container {
    margin-bottom: 1.5rem;
  }

  .badge {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 1rem;
    background-color: var(--bg-card);
    border: 1px solid var(--border-color);
    border-radius: 30px;
    font-size: 0.9rem;
    font-weight: 500;
    color: var(--text-primary);
    box-shadow: var(--shadow-sm);
  }

  .hero h1 {
    font-size: 4.5rem;
    line-height: 1.1;
    margin-bottom: 1.5rem;
    color: var(--text-primary);
  }

  .highlight {
    color: var(--scholar-blue);
    position: relative;
    z-index: 1;
  }

  .highlight::after {
    content: "";
    position: absolute;
    bottom: 5px;
    left: 0;
    width: 100%;
    height: 15px;
    background-color: rgba(46, 204, 113, 0.25);
    z-index: -1;
    transform: skewX(-10deg);
  }

  .hero-sub {
    font-size: 1.25rem;
    color: var(--text-secondary);
    margin-bottom: 2.5rem;
    max-width: 500px;
    line-height: 1.6;
  }

  .hero-actions {
    display: flex;
    gap: 1rem;
    margin-bottom: 3rem;
  }

  .btn-primary-lg {
    background-color: var(--scholar-blue);
    color: white;
    padding: 1rem 2rem;
    border-radius: 12px;
    font-weight: 600;
    text-decoration: none;
    display: flex;
    align-items: center;
    gap: 0.8rem;
    font-size: 1.1rem;
    transition: all 0.3s ease;
    box-shadow: 0 10px 20px rgba(59, 130, 246, 0.2);
  }

  .btn-primary-lg:hover {
    transform: translateY(-3px);
    box-shadow: 0 15px 30px rgba(59, 130, 246, 0.3);
    background-color: var(--scholar-blue-hover);
  }

  .btn-secondary-lg {
    background-color: var(--bg-card);
    color: var(--text-primary);
    padding: 1rem 2rem;
    border-radius: 12px;
    font-weight: 600;
    text-decoration: none;
    font-size: 1.1rem;
    transition: all 0.3s ease;
    border: 1px solid var(--border-color);
  }

  .btn-secondary-lg:hover {
    background-color: var(--bg-tertiary);
    border-color: var(--scholar-blue);
    color: var(--scholar-blue);
  }

  .trust-avatars {
    display: flex;
    align-items: center;
    gap: 1rem;
    color: var(--text-secondary);
  }

  .avatar-group {
    display: flex;
  }

  .avatar {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    border: 3px solid var(--bg-primary);
    margin-left: -15px;
  }

  .avatar:first-child {
    margin-left: 0;
  }

  /* Right Side Hero Visuals */
  .hero-image {
    position: relative;
    display: flex;
    justify-content: center;
    perspective: 1000px;
  }

  .phone-mockup {
    width: 300px;
    height: 600px;
    background: #111;
    border-radius: 25px;
    padding: 12px;
    box-shadow: 0 30px 60px rgba(0, 0, 0, 0.3);
    position: relative;
    z-index: 10;
    border: 4px solid #222;
    transform: rotateY(-10deg) rotateX(5deg);
    transition: transform 0.5s ease;
  }

  .phone-mockup:hover {
    transform: rotateY(0) rotateX(0);
  }

  .phone-screen {
    width: 100%;
    height: 100%;
    background: white;
    border-radius: 15px;
    overflow: hidden;
  }

  .app-screen {
    background-color: var(--scholar-blue);
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }

  .float-card {
    position: absolute;
    background: var(--bg-card);
    border: 1px solid var(--border-color);
    padding: 1rem 1.5rem;
    border-radius: 16px;
    box-shadow: var(--shadow-md);
    display: flex;
    align-items: center;
    gap: 1rem;
    z-index: 12;
    animation: float 6s infinite ease-in-out;
    min-width: 200px;
  }

  .card-1 {
    top: 20%;
    right: -20px;
    animation-delay: 0s;
  }

  .card-2 {
    bottom: 25%;
    left: -40px;
    animation-delay: 3s;
  }

  .icon-circle {
    width: 40px;
    height: 40px;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: white;
  }

  .icon-circle.green {
    background: var(--emerald-green);
  }
  .icon-circle.blue {
    background: var(--scholar-blue);
  }

  .float-card span {
    font-weight: 600;
    color: var(--text-primary);
  }

  .float-card .price {
    color: var(--emerald-green);
    margin-left: auto;
  }

  .float-card .sub {
    font-weight: 400;
    font-size: 0.85rem;
    color: var(--text-secondary);
    display: block;
  }

  @keyframes float {
    0%,
    100% {
      transform: translateY(0);
    }
    50% {
      transform: translateY(-15px);
    }
  }

  @media (max-width: 1024px) {
    .hero-container {
      grid-template-columns: 1fr;
      text-align: center;
      gap: 2rem;
    }
    .hero h1 {
      font-size: 3.5rem;
    }
    .hero-sub {
      margin: 0 auto 2.5rem;
    }
    .hero-actions {
      justify-content: center;
    }
    .avatar-group {
      justify-content: center;
    }
    .phone-mockup {
      transform: none;
    }
    .card-1, .card-2 {
      display: none;
    }
  }

  @media (max-width: 480px) {
    .hero h1 {
      font-size: 2.8rem;
    }
    .hero-actions {
      flex-direction: column;
    }
    .btn-primary-lg, .btn-secondary-lg {
      width: 100%;
      justify-content: center;
    }
  }
</style>
