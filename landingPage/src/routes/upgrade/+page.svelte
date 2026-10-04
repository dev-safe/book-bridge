<script>
	import { enhance } from '$app/forms';
	import { onDestroy, onMount } from 'svelte';

	let { data, form } = $props();

	const POLL_MS = 4000;
	const MAX_POLLS = 60;
	const WAITING = new Set(['PENDING', 'CREATED']);
	const DONE = new Set(['FAILED', 'EXPIRED']);

	let polledStatus = $state('');
	let submitting = $state(false);
	let pollError = $state('');
	/** @type {ReturnType<typeof setTimeout> | undefined} */
	let timer;

	const status = $derived(polledStatus || (form?.started ? 'PENDING' : data.status));
	const priceLabel = $derived(`${new Intl.NumberFormat('fr-FR').format(data.priceXaf)} FCFA`);

	async function poll(attempt = 0) {
		if (attempt >= MAX_POLLS) {
			pollError = 'Still waiting for confirmation. You can close this page — your tier updates automatically once payment completes.';
			return;
		}
		try {
			const res = await fetch(`/upgrade/status?code=${encodeURIComponent(data.code)}`);
			const body = await res.json();
			if (res.ok && body.status) polledStatus = body.status;
		} catch {
			// Transient network error: keep polling.
		}
		if (WAITING.has(status)) {
			timer = setTimeout(() => poll(attempt + 1), POLL_MS);
		}
	}

	function startPolling() {
		if (WAITING.has(status) && data.code && timer === undefined) {
			timer = setTimeout(() => poll(), POLL_MS);
		}
	}

	onMount(startPolling);
	onDestroy(() => clearTimeout(timer));
</script>

<svelte:head>
	<title>Become a Power Seller | BookBridge</title>
	<meta name="robots" content="noindex" />
</svelte:head>

<section class="upgrade">
	<div class="card">
		<h1>Become a Power Seller</h1>
		<p class="price">{priceLabel} <span>/ {data.days} days</span></p>
		<ul class="perks">
			<li>Unlimited active listings (free accounts are limited to 3)</li>
			<li>Power Seller badge on your profile</li>
			<li>No auto-renewal — pay again only if you want to</li>
		</ul>

		{#if status === 'INVALID'}
			<p class="notice error">
				This upgrade link is invalid. Open BookBridge and tap “Become a Power Seller” to get a new one.
			</p>
		{:else if status === 'ERROR'}
			<p class="notice error">{data.error}</p>
		{:else if status === 'UNUSED'}
			<form
				method="POST"
				use:enhance={() => {
					submitting = true;
					return async ({ update }) => {
						await update({ reset: false });
						submitting = false;
						startPolling();
					};
				}}
			>
				<input type="hidden" name="code" value={data.code} />

				<label for="phone">Mobile money number</label>
				<input
					id="phone"
					name="phone"
					type="tel"
					inputmode="numeric"
					autocomplete="tel"
					placeholder="6XXXXXXXX"
					required
					value={form?.phone ?? ''}
				/>

				<fieldset>
					<legend>Pay with</legend>
					<label class="radio">
						<input
							type="radio"
							name="medium"
							value="mobile money"
							checked={(form?.medium ?? 'mobile money') === 'mobile money'}
						/>
						MTN Mobile Money
					</label>
					<label class="radio">
						<input
							type="radio"
							name="medium"
							value="orange money"
							checked={form?.medium === 'orange money'}
						/>
						Orange Money
					</label>
				</fieldset>

				{#if form?.error}
					<p class="notice error" role="alert">{form.error}</p>
				{/if}

				<button class="btn primary" type="submit" disabled={submitting}>
					{submitting ? 'Sending prompt…' : `Pay ${priceLabel}`}
				</button>
			</form>
		{:else if WAITING.has(status)}
			<p class="notice" role="status" aria-live="polite">
				Check your phone and confirm the {priceLabel} payment prompt. This page updates automatically.
			</p>
			{#if pollError}
				<p class="notice">{pollError}</p>
			{/if}
		{:else if status === 'SUCCESSFUL'}
			<p class="notice success" role="status">
				Payment received — you're now a Power Seller! Return to the BookBridge app to keep listing.
			</p>
		{:else if DONE.has(status)}
			<p class="notice error" role="alert">
				The payment didn't go through. Open BookBridge and tap “Become a Power Seller” to try again.
			</p>
		{:else}
			<p class="notice error">
				This upgrade link has expired. Open BookBridge and tap “Become a Power Seller” to get a new one.
			</p>
		{/if}
	</div>
</section>

<style>
	.upgrade {
		max-width: 520px;
		margin: 0 auto;
		padding: 7rem 1.25rem 3rem;
	}

	.card {
		background: var(--bg-card);
		border: 1px solid var(--border-color);
		border-radius: 1rem;
		box-shadow: var(--shadow-md);
		padding: 1.5rem;
	}

	h1 {
		margin: 0 0 0.5rem;
		font-size: 1.5rem;
		color: var(--text-primary);
	}

	.price {
		font-size: 1.5rem;
		font-weight: 700;
		color: var(--scholar-blue);
		margin: 0.5rem 0 1rem;
	}

	.price span {
		font-size: 1rem;
		font-weight: 500;
		color: var(--text-secondary);
	}

	.perks {
		color: var(--text-secondary);
		padding-left: 1.25rem;
		margin: 0 0 1.5rem;
		display: grid;
		gap: 0.35rem;
	}

	form {
		display: grid;
		gap: 0.75rem;
	}

	label,
	legend {
		color: var(--text-primary);
		font-weight: 600;
	}

	input[type='tel'] {
		padding: 0.75rem 1rem;
		border: 1px solid var(--border-color);
		border-radius: 0.75rem;
		background: var(--bg-tertiary);
		color: var(--text-primary);
		font-size: 1rem;
	}

	fieldset {
		border: none;
		padding: 0;
		margin: 0;
		display: grid;
		gap: 0.5rem;
	}

	.radio {
		font-weight: 500;
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}

	.btn {
		padding: 0.85rem 1.25rem;
		border: none;
		border-radius: 0.75rem;
		font-weight: 600;
		font-size: 1rem;
		cursor: pointer;
	}

	.btn.primary {
		background: var(--scholar-blue);
		color: #fff;
	}

	.btn.primary:hover:not(:disabled) {
		background: var(--scholar-blue-hover);
	}

	.btn:disabled {
		opacity: 0.6;
		cursor: wait;
	}

	.notice {
		margin: 0;
		padding: 0.85rem 1rem;
		border-radius: 0.75rem;
		background: var(--bg-tertiary);
		color: var(--text-primary);
	}

	.notice.error {
		color: #b91c1c;
	}

	.notice.success {
		color: #15803d;
		font-weight: 600;
	}
</style>
