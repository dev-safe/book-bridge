<script>
	const LAST_UPDATED = '18 October 2026';
	const CONTACT_EMAIL = 'contact@devsafe.cm';
</script>

<svelte:head>
	<title>Privacy Policy — BookBridge</title>
	<meta
		name="description"
		content="How BookBridge collects, uses and protects personal data, including children's data, under Cameroon Law 2024/017 and the Google Play Families Policy."
	/>
</svelte:head>

<section class="policy">
	<article class="card">
		<h1>Privacy Policy</h1>
		<p class="meta">Last updated: {LAST_UPDATED}</p>

		<p>
			BookBridge is a marketplace that helps students in Cameroon buy and sell used textbooks. It is
			operated by DevSafe. This policy explains what personal data we collect, why we collect it, who
			we share it with, and the rights you have under Cameroon Law No. 2024/017 on the protection of
			personal data. It also explains how we handle children's data in line with the Google Play
			Families Policy.
		</p>

		<h2>1. Who can use BookBridge</h2>
		<p>
			New accounts can be created by students aged 10 to 22. Users under 18 are minors. Users aged
			10 to 14 need a parent or guardian to take part in ID verification and payments, as described
			below.
		</p>

		<h2>2. Data we collect</h2>
		<ul>
			<li><strong>Account data:</strong> full name, email address, profile photo and sign-in data from Google Sign-In.</li>
			<li><strong>Profile data:</strong> city or locality, school, WhatsApp number and account tier.</li>
			<li><strong>Age data:</strong> date of birth or age declaration and, for users aged 10 to 14, a parent or guardian's phone number.</li>
			<li><strong>ID verification data:</strong> photos of the ID document you submit, including a guardian's national ID card where required.</li>
			<li><strong>Listings:</strong> book details, prices, meetup spots and photos you upload, plus an approximate location (rounded to about 1 km) taken from your device when you post a listing. Other users see this approximate location on the map, never your exact position.</li>
			<li><strong>Messages:</strong> chat messages you exchange with other users about a listing.</li>
			<li><strong>Transactions:</strong> purchase records, escrow status and the Mobile Money phone numbers used for payment.</li>
			<li><strong>Reputation:</strong> ratings, reviews and a trust score based on completed transactions.</li>
			<li><strong>Device data:</strong> a push notification token (Firebase Cloud Messaging) so we can notify you about messages and orders.</li>
		</ul>

		<h2>3. How we use your data</h2>
		<ul>
			<li>To create and secure your account.</li>
			<li>To show your listings and public profile to other students.</li>
			<li>To process payments and hold funds in escrow until the buyer confirms receipt.</li>
			<li>To verify identities and keep the marketplace safe.</li>
			<li>To send notifications about messages, orders and account activity.</li>
			<li>To investigate disputes, fraud and abuse.</li>
		</ul>

		<h2>4. Children and guardians</h2>
		<p>We take extra care with users under 18:</p>
		<ul>
			<li>We collect only the data needed to run the marketplace safely.</li>
			<li>
				For users aged 10 to 14, ID verification requires the child's school ID and the parent or
				guardian's national ID card. Payments are made from the guardian's Mobile Money number.
			</li>
			<li>Users aged 15 to 17 verify with a school ID. Users aged 18 and over verify with a national ID card.</li>
			<li>Before sending chat messages, younger users see an online-safety reminder: never share personal details and meet only in safe public places.</li>
			<li>We do not show advertising and we do not use advertising identifiers.</li>
		</ul>
		<p>
			A parent or guardian can ask to see, correct or delete a child's data at any time by contacting
			us (see section 10). We will verify the request before acting on it.
		</p>

		<h2>5. ID verification</h2>
		<p>
			ID photos are stored in a private storage area that only you and our administrators can access.
			An administrator reviews them manually. After the review is approved or rejected, the photos are
			deleted. We keep only the verification status, the type of ID, the reviewer and, if rejected,
			the reason.
		</p>

		<h2>6. Payments</h2>
		<p>
			Payments use Mobile Money through our payment partner Fapshi. We never see or store your Mobile
			Money PIN. Funds are held in escrow and released to the seller when the buyer confirms receipt,
			or automatically after the confirmation period ends. Power Seller upgrades are paid the same
			way.
		</p>

		<h2>7. Sharing your data</h2>
		<p>We do not sell personal data and we do not share it for advertising. We share data only:</p>
		<ul>
			<li>With other users, as needed for a sale (for example, your public profile and listing details).</li>
			<li>With service providers that host and run BookBridge: Supabase (database, storage and authentication), Google (sign-in and push notifications) and Fapshi (payments).</li>
			<li>When required by law, or to protect users from fraud or harm.</li>
		</ul>

		<h2>8. How long we keep data</h2>
		<ul>
			<li>Chat messages are deleted automatically after 7 days.</li>
			<li>ID photos are deleted as soon as the review is complete.</li>
			<li>Transaction records are kept as long as needed for disputes, accounting and legal obligations.</li>
			<li>Other account data is kept while your account is active and deleted when you delete your account.</li>
		</ul>
		<p>
			When you delete your account, your profile, ID data, photos, messages and sign-in details are
			deleted. Records of purchases, payments, ratings and feedback are kept without your name for
			accounting and dispute purposes. See <a href="/delete-account">Delete your account</a> for the
			full list.
		</p>

		<h2>9. Security</h2>
		<p>
			Data is encrypted in transit. Access is restricted with row-level security, so users can read and
			change only the data they are allowed to.
		</p>

		<h2>10. Your rights</h2>
		<p>
			Under Cameroon Law No. 2024/017 you have the right to access, correct and delete your personal
			data, and to object to or restrict its processing. You can delete your account at any time from
			the Profile tab in the app (see <a href="/delete-account">Delete your account</a>). To use
			your other rights, or to ask a question
			about this policy, email
			<a href="mailto:{CONTACT_EMAIL}">{CONTACT_EMAIL}</a>. Parents and guardians can make requests on
			behalf of a child.
		</p>

		<h2>11. Changes to this policy</h2>
		<p>If we change this policy, we will update the date at the top of this page.</p>

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

	ul {
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
