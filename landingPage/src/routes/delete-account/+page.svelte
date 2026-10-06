<script>
	const LAST_UPDATED = '18 October 2026';
	const CONTACT_EMAIL = 'contact@devsafe.cm';
	const EMAIL_SUBJECT = 'Delete my BookBridge account';
	const mailto = `mailto:${CONTACT_EMAIL}?subject=${encodeURIComponent(EMAIL_SUBJECT)}`;
</script>

<svelte:head>
	<title>Delete your account — BookBridge</title>
	<meta
		name="description"
		content="How to delete your BookBridge account and what data is deleted or kept."
	/>
</svelte:head>

<section class="policy">
	<article class="card">
		<h1>Delete your BookBridge account</h1>
		<p class="meta">BookBridge by DevSafe · Last updated: {LAST_UPDATED}</p>

		<p>
			You can delete your BookBridge account and the personal data linked to it at any time. Deletion
			is permanent and cannot be undone.
		</p>

		<h2>Delete it in the app</h2>
		<ol>
			<li>Open BookBridge and sign in.</li>
			<li>Go to the <strong>Profile</strong> tab.</li>
			<li>Scroll down and tap <strong>Delete account</strong>.</li>
			<li>
				Tick <strong>I understand this cannot be undone</strong>, then tap
				<strong>Delete account</strong>.
			</li>
		</ol>
		<p>
			Your account is deleted straight away and you are signed out on every device. If you have an
			order in progress (a paid order waiting for confirmation, an open dispute or an active
			reservation), finish or cancel it first. The app will tell you if this applies.
		</p>

		<h2>Can't use the app?</h2>
		<p>
			Email <a href={mailto}>{CONTACT_EMAIL}</a> from the email address you use for BookBridge, with
			the subject "{EMAIL_SUBJECT}". We will confirm the request is yours and delete your account
			within 30 days. A parent or guardian can ask on behalf of a child.
		</p>

		<h2>What we delete</h2>
		<ul>
			<li>
				Your profile: name, email, profile photo, WhatsApp number, school, city, date of birth or age
				declaration, and a guardian's phone number.
			</li>
			<li>ID verification photos and details.</li>
			<li>Your sign-in details, sessions on all devices and your push notification token.</li>
			<li>Book photos and descriptions. Listings that were never sold are deleted completely.</li>
			<li>Chat messages you sent or received, favourites, wishlists and notifications.</li>
			<li>The Mobile Money numbers linked to your payments.</li>
			<li>The written comments in reviews you gave.</li>
		</ul>

		<h2>What we keep, without your name</h2>
		<p>
			Some records must be kept for accounting, fraud prevention and dispute handling. They are kept
			only as long as the law requires and are no longer linked to your name, email or phone number:
		</p>
		<ul>
			<li>
				Records of purchases, sales and escrow payments (amounts, dates, payment references and
				dispute reasons).
			</li>
			<li>Records of Power Seller upgrades, listing boosts and donations.</li>
			<li>Star ratings you gave or received, so other sellers' scores stay accurate.</li>
			<li>Feedback you sent us, no longer linked to your account.</li>
			<li>Our moderation and admin logs.</li>
		</ul>
		<p>Our payment partner Fapshi keeps its own payment records under its own legal obligations.</p>

		<p>Read our <a href="/privacy">Privacy Policy</a> for more on how we handle your data.</p>

		<p class="powered">
			Powered by <a href="https://www.devsafe.cm" target="_blank" rel="noopener noreferrer">DevSafe</a>
		</p>
	</article>
</section>

<style>
	.policy {
		max-width: 760px;
		margin: 0 auto;
		padding: 7rem 1.25rem 3rem;
	}

	.card {
		background: var(--bg-card);
		border: 1px solid var(--border-color);
		border-radius: 1rem;
		box-shadow: var(--shadow-md);
		padding: 2rem 1.5rem;
		color: var(--text-secondary);
		line-height: 1.65;
	}

	h1 {
		margin: 0 0 0.25rem;
		font-size: 1.75rem;
		font-family: var(--font-header);
		color: var(--text-primary);
	}

	h2 {
		margin: 2rem 0 0.5rem;
		font-size: 1.15rem;
		font-family: var(--font-header);
		color: var(--text-primary);
	}

	.meta {
		margin: 0 0 1.5rem;
		color: var(--text-muted);
		font-size: 0.9rem;
	}

	ul,
	ol {
		padding-left: 1.25rem;
	}

	li {
		margin-bottom: 0.4rem;
	}

	strong {
		color: var(--text-primary);
	}

	a {
		color: var(--scholar-blue);
	}

	.powered {
		margin-top: 2.5rem;
		text-align: center;
		color: var(--text-muted);
		font-size: 0.9rem;
	}
</style>
