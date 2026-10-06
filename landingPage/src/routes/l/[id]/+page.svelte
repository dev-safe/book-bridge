<script>
	import { APP_DOWNLOAD_LINK } from '$lib/links.js';

	let { data } = $props();

	const SITE_URL = 'https://bookbridge.devsafe.cm';
	const CONDITION_LABELS = {
		new: 'New',
		like_new: 'Like new',
		good: 'Good',
		excellent: 'Good',
		fair: 'Fair',
		poor: 'Poor'
	};

	const listing = $derived(data.listing);
	const shareUrl = $derived(`${SITE_URL}/l/${data.id}`);
	const intentUrl = $derived(
		`intent://bookbridge.devsafe.cm/l/${data.id}#Intent;scheme=https;package=cm.devsafe.bookbridge;S.browser_fallback_url=${encodeURIComponent(APP_DOWNLOAD_LINK)};end`
	);
	const priceLabel = $derived(
		listing ? `${new Intl.NumberFormat('fr-FR').format(listing.priceFcfa)} FCFA` : ''
	);
	const conditionLabel = $derived(
		listing ? (CONDITION_LABELS[listing.condition] ?? listing.condition) : ''
	);
	const pageTitle = $derived(listing ? `${listing.title} — ${priceLabel} | BookBridge` : 'BookBridge');
	const description = $derived(
		listing
			? [listing.author && `by ${listing.author}`, conditionLabel, listing.schoolName]
					.filter(Boolean)
					.join(' · ') + ' — buy safely on BookBridge.'
			: 'Buy and sell used textbooks safely with students across Cameroon.'
	);
	const isAvailable = $derived(listing?.status === 'available');
</script>

<svelte:head>
	<title>{pageTitle}</title>
	<meta name="description" content={description} />
	<meta property="og:type" content="product" />
	<meta property="og:site_name" content="BookBridge" />
	<meta property="og:title" content={pageTitle} />
	<meta property="og:description" content={description} />
	<meta property="og:url" content={shareUrl} />
	{#if listing?.imageUrl}
		<meta property="og:image" content={listing.imageUrl} />
	{/if}
	<meta name="twitter:card" content={listing?.imageUrl ? 'summary_large_image' : 'summary'} />
	<meta name="twitter:title" content={pageTitle} />
	<meta name="twitter:description" content={description} />
	{#if listing?.imageUrl}
		<meta name="twitter:image" content={listing.imageUrl} />
	{/if}
</svelte:head>

<section class="listing-preview">
	{#if listing}
		<article class="card">
			{#if listing.imageUrl}
				<img class="cover" src={listing.imageUrl} alt={`Cover of ${listing.title}`} />
			{/if}
			<div class="details">
				<h1>{listing.title}</h1>
				{#if listing.author}
					<p class="author">by {listing.author}</p>
				{/if}
				<p class="price">{priceLabel}</p>
				<ul class="meta">
					<li>Condition: {conditionLabel}</li>
					{#if listing.schoolName}
						<li>School: {listing.schoolName}</li>
					{/if}
				</ul>
				{#if !isAvailable}
					<p class="status">This book is no longer available.</p>
				{/if}
			</div>
		</article>
	{:else}
		<div class="card empty">
			<h1>Listing not found</h1>
			<p>This book may have been sold or removed. Browse more books in the BookBridge app.</p>
		</div>
	{/if}

	<div class="actions">
		<a class="btn primary" href={intentUrl}>Open in BookBridge</a>
		<a class="btn secondary" href={APP_DOWNLOAD_LINK}>Download the app</a>
	</div>
	<p class="hint">Contact the seller and pay securely inside the app.</p>
</section>

<style>
	.listing-preview {
		max-width: 640px;
		margin: 0 auto;
		padding: 7rem 1.25rem 3rem;
	}

	.card {
		background: var(--bg-card);
		border: 1px solid var(--border-color);
		border-radius: 1rem;
		box-shadow: var(--shadow-md);
		overflow: hidden;
	}

	.cover {
		display: block;
		width: 100%;
		max-height: 420px;
		object-fit: contain;
		background: var(--bg-tertiary);
	}

	.details,
	.empty {
		padding: 1.5rem;
	}

	h1 {
		margin: 0 0 0.5rem;
		font-size: 1.5rem;
		color: var(--text-primary);
	}

	.author,
	.meta,
	.empty p {
		color: var(--text-secondary);
	}

	.price {
		font-size: 1.25rem;
		font-weight: 700;
		color: var(--scholar-blue);
		margin: 0.75rem 0;
	}

	.meta {
		list-style: none;
		padding: 0;
		margin: 0;
		display: grid;
		gap: 0.25rem;
	}

	.status {
		margin-top: 1rem;
		color: #b45309;
		font-weight: 600;
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		gap: 0.75rem;
		margin-top: 1.5rem;
	}

	.btn {
		flex: 1 1 200px;
		text-align: center;
		padding: 0.85rem 1.25rem;
		border-radius: 0.75rem;
		font-weight: 600;
		text-decoration: none;
	}

	.btn.primary {
		background: var(--scholar-blue);
		color: #fff;
	}

	.btn.primary:hover {
		background: var(--scholar-blue-hover);
	}

	.btn.secondary {
		border: 1px solid var(--scholar-blue);
		color: var(--scholar-blue);
	}

	.hint {
		margin-top: 1rem;
		text-align: center;
		color: var(--text-muted);
		font-size: 0.9rem;
	}
</style>
