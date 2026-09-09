import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';

/** @type {import('@supabase/supabase-js').SupabaseClient | undefined} */
let supabase;

function getSupabase() {
	if (!supabase && env.SUPABASE_URL && env.SUPABASE_SERVICE_ROLE_KEY) {
		supabase = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY);
	}
	return supabase;
}

// Health check endpoint
export async function GET() {
	return json({ 
		status: 'alive', 
		time: new Date().toISOString(),
		config_check: {
			has_url: !!env.SUPABASE_URL,
			has_key: !!env.SUPABASE_SERVICE_ROLE_KEY,
			has_webhook_key: !!env.FAPSHI_WEBHOOK_KEY
		}
	});
}

export async function POST({ request }) {
	const timestamp = new Date().toISOString();
	console.log(`[${timestamp}] Fapshi Webhook received`);

	// 1. Log Headers for debugging
	const headers = Object.fromEntries(request.headers.entries());
	console.log(`[${timestamp}] Headers:`, JSON.stringify(headers));

	// 2. Verify Authentication from Fapshi
	// According to docs, Fapshi sends 'apiuser' and 'apikey' in the headers
	const providedApiUser = request.headers.get('apiuser');
	const providedApiKey = request.headers.get('apikey');
	
	const expectedApiUser = env.FAPSHI_API_USER;
	const expectedApiKey = env.FAPSHI_API_KEY;

	if (expectedApiUser && expectedApiKey) {
		if (providedApiUser !== expectedApiUser || providedApiKey !== expectedApiKey) {
			console.error(`[${timestamp}] Unauthorized: Invalid apiuser or apikey`);
			return json({ error: 'Unauthorized', debug: 'Invalid credentials' }, { status: 401 });
		}
	} else {
		console.warn(`[${timestamp}] WARNING: Fapshi API credentials not configured in environment. Webhook is running insecurely!`);
	}

	try {
		let payload = await request.json();
		console.log(`[${timestamp}] Raw Payload:`, JSON.stringify(payload));
		
		// The Fapshi documentation specifies that the payload is sent as an array of objects
		if (Array.isArray(payload) && payload.length > 0) {
			payload = payload[0];
			console.log(`[${timestamp}] Extracted Payload Object:`, JSON.stringify(payload));
		}
		
		// Fapshi typically sends transId, status, amount, externalId
		const status = payload.status || payload.state;
		const reference = payload.transId || payload.transactionId || payload.id;
		const amount = payload.amount;
		const external_reference = payload.externalId || payload.externalReference || payload.custom;

		if (status === 'SUCCESSFUL' || status === 'SUCCESS') {
			if (external_reference && (external_reference.startsWith('boost:') || external_reference.startsWith('boost_'))) {
				const separator = external_reference.includes(':') ? ':' : '_';
				const parts = external_reference.split(separator);
				const listingId = parts[1];
				const duration = parts[2] || '7';
				
				console.log(`[${timestamp}] Processing boost: Listing=${listingId}, Duration=${duration}`);
				await handleBoostSuccess(listingId, reference, amount, duration);
			} else if (external_reference && (external_reference.startsWith('donation:') || external_reference.startsWith('donation_'))) {
				const separator = external_reference.includes(':') ? ':' : '_';
				const parts = external_reference.split(separator);
				const userId = parts[1];
				await handleDonationSuccess(userId, reference, amount);
			} else if (external_reference && (external_reference.startsWith('purchase:') || external_reference.startsWith('purchase_'))) {
				const separator = external_reference.includes(':') ? ':' : '_';
				const parts = external_reference.split(separator);
				const listingId = parts[1];
				const buyerId = parts[2];
				
				console.log(`[${timestamp}] Processing purchase: Listing=${listingId}, Buyer=${buyerId}`);
				await handlePurchaseSuccess(listingId, buyerId, reference, amount);
			} else {
				console.warn(`[${timestamp}] Unknown externalId format: ${external_reference}`);
			}
		} else if (status === 'CREATED' || status === 'PENDING' || status === 'pending_payment') {
			if (external_reference && (external_reference.startsWith('purchase:') || external_reference.startsWith('purchase_'))) {
				const separator = external_reference.includes(':') ? ':' : '_';
				const parts = external_reference.split(separator);
				const listingId = parts[1];
				const buyerId = parts[2];
				
				console.log(`[${timestamp}] Processing pending purchase: Listing=${listingId}, Buyer=${buyerId}`);
				await handlePurchasePending(listingId, buyerId, reference, amount);
			}
		} else if (status === 'FAILED' || status === 'EXPIRED') {
			if (external_reference && (external_reference.startsWith('purchase:') || external_reference.startsWith('purchase_'))) {
				console.log(`[${timestamp}] Processing failed purchase: Ref=${reference}`);
				const supabase = getSupabase();
				if (supabase) {
					await supabase
						.from('transactions')
						.update({ status: 'failed' })
						.eq('payment_reference', reference);
				}
			}
		} else {
			console.log(`[${timestamp}] Payment ${status} for ref ${reference}`);
		}

		return json({ success: true, processed_at: timestamp });
	} catch (err) {
		console.error(`[${timestamp}] Webhook Error:`, err);
		const error = /** @type {Error} */ (err);
		return json({ error: error.message, stack: error.stack }, { status: 500 });
	}
}

/**
 * @param {string} listingId
 * @param {string} reference
 * @param {string|number} amount
 * @param {string|number} duration
 */
async function handleBoostSuccess(listingId, reference, amount, duration) {
	const expiresAt = new Date();
	expiresAt.setDate(expiresAt.getDate() + parseInt(String(duration)));

	console.log(`Processing boost for listing ${listingId}`);

	// 1. Get the seller_id from the listing
	const supabase = getSupabase();
	if (!supabase) throw new Error('Supabase client not initialized');

	const { data: listing, error: fetchError } = await supabase
		.from('listings')
		.select('seller_id')
		.eq('id', listingId)
		.single();

	if (fetchError || !listing) {
		console.error('Error fetching listing for boost:', fetchError);
		throw new Error('Listing not found');
	}

	const userId = listing.seller_id;

	// 2. Update listing visibility
	const { error: listingError } = await supabase
		.from('listings')
		.update({
			is_boosted: true,
			boost_expires_at: expiresAt.toISOString()
		})
		.eq('id', listingId);

	if (listingError) {
		console.error('Error updating listing visibility:', listingError);
		throw listingError;
	}

	// 3. Upsert boost payment record
	const { error: paymentError } = await supabase
		.from('boost_payments')
		.upsert({
			payment_reference: reference,
			listing_id: listingId,
			user_id: userId,
			amount: parseInt(String(amount)),
			duration_days: parseInt(String(duration)),
			status: 'successful',
			created_at: new Date().toISOString()
		}, { onConflict: 'payment_reference' });
    
    if (paymentError) {
		console.error('Error recording boost payment:', paymentError);
		throw paymentError;
	}
	
	console.log(`Successfully boosted listing ${listingId} for user ${userId}`);
}

/**
 * @param {string} userId
 * @param {string} reference
 * @param {string|number} amount
 */
async function handleDonationSuccess(userId, reference, amount) {
	console.log(`Processing donation from user ${userId}`);
	
	const supabase = getSupabase();
	if (!supabase) throw new Error('Supabase client not initialized');

	const { error } = await supabase
		.from('donations')
		.upsert({
			payment_reference: reference,
			user_id: userId === 'anonymous' ? null : userId,
			amount: parseInt(String(amount)),
			status: 'successful',
			created_at: new Date().toISOString()
		}, { onConflict: 'payment_reference' });
    
    if (error) {
		console.error('Donation record error:', error);
		throw error;
	}
}

/**
 * @param {string} listingId
 * @param {string} buyerId
 * @param {string} reference
 * @param {string|number} amount
 */
async function handlePurchaseSuccess(listingId, buyerId, reference, amount) {
	console.log(`Processing purchase for listing ${listingId} by buyer ${buyerId}`);
	
	// 1. Get the seller_id from the listing
	const supabase = getSupabase();
	if (!supabase) throw new Error('Supabase client not initialized');

	const { data: listing, error: fetchError } = await supabase
		.from('listings')
		.select('seller_id')
		.eq('id', listingId)
		.single();

	if (fetchError || !listing) {
		console.error('Error fetching listing for purchase:', fetchError);
		throw new Error('Listing not found');
	}

	const sellerId = listing.seller_id;

	// 2. Fetch the seller's mobile money (whatsapp) number
	const { data: profile } = await supabase
		.from('profiles')
		.select('whatsapp_number, full_name')
		.eq('id', sellerId)
		.single();

	// 3. Update listing status to 'sold'
	const { error: listingError } = await supabase
		.from('listings')
		.update({
			status: 'sold'
		})
		.eq('id', listingId);

	if (listingError) {
		console.error('Error marking listing as sold:', listingError);
		throw listingError;
	}

	// 4. Calculate Payout (95% to seller, 5% commission)
	// We parse amount to integer, and calculate 95%. Round down to be safe.
	const totalAmount = parseInt(String(amount));
	const payoutAmount = Math.floor(totalAmount * 0.95);
	const commissionAmount = totalAmount - payoutAmount;

	const ESCROW_ENABLED = true;

	if (ESCROW_ENABLED) {
		console.log(`Escrow is enabled. Recording transaction with status 'held' and holding payout.`);
		
		// Upsert transaction with status = 'held' and get its ID
		const { data: tx, error: paymentError } = await supabase
			.from('transactions')
			.upsert({
				payment_reference: reference,
				listing_id: listingId,
				buyer_id: buyerId,
				seller_id: sellerId,
				amount: totalAmount,
				status: 'held',
				payout_status: 'pending',
				payout_reference: null,
				commission_amount: commissionAmount,
				created_at: new Date().toISOString()
			}, { onConflict: 'payment_reference' })
			.select('id')
			.single();

		if (paymentError || !tx) {
			console.error('Error recording purchase transaction for escrow:', paymentError);
			throw paymentError || new Error('Failed to create transaction');
		}

		// Insert escrow transaction record
		const { error: escrowError } = await supabase
			.from('escrow_transactions')
			.upsert({
				transaction_id: tx.id,
				status: 'held',
				created_at: new Date().toISOString(),
				updated_at: new Date().toISOString()
			}, { onConflict: 'transaction_id' });

		if (escrowError) {
			console.error('Error recording escrow transaction:', escrowError);
			throw escrowError;
		}
	} else {
		// 5. Initiate Payout via Fapshi if seller has a number configured
		let payoutStatus = 'pending';
		let payoutReference = null;
		
		if (profile && profile.whatsapp_number) {
			const fapshiPayoutUser = env.FAPSHI_PAYOUT_API_USER;
			const fapshiPayoutKey = env.FAPSHI_PAYOUT_API_KEY;
			const payoutExternalId = `payout_${reference}`;

			if (fapshiPayoutUser && fapshiPayoutKey) {
				try {
					// Fapshi REQUIRES the phone number to be ONLY local 9-digits (e.g., 6XXXXXXXX) without +237 or spaces.
					let cleanedPhone = profile.whatsapp_number.replace(/\D/g, '');
					if (cleanedPhone.startsWith('237')) {
						cleanedPhone = cleanedPhone.substring(3);
					}
					
					console.log(`Initiating payout of ${payoutAmount} XAF to ${cleanedPhone} for seller ${sellerId}`);
					
					const response = await fetch('https://live.fapshi.com/payout', {
						method: 'POST',
						headers: {
							'Content-Type': 'application/json',
							'apiuser': fapshiPayoutUser,
							'apikey': fapshiPayoutKey
						},
						body: JSON.stringify({
							amount: payoutAmount,
							phone: cleanedPhone,
							name: profile.full_name || 'BookBridge Seller',
							externalId: payoutExternalId,
							message: `BookBridge Book Sale Payout for listing ${listingId}`
						})
					});

					const payoutData = await response.json();
					console.log(`[${new Date().toISOString()}] Payout Response:`, JSON.stringify(payoutData));

					if (response.ok && payoutData.statusCode === 200) {
						payoutStatus = 'successful';
						payoutReference = payoutData.transId;
					} else {
						console.error('Payout failed with response:', payoutData);
						payoutStatus = 'failed';
					}
				} catch (e) {
					console.error('Fapshi Payout Request Exception:', e);
					payoutStatus = 'failed';
				}
			} else {
				console.warn('FAPSHI_PAYOUT_API_USER or FAPSHI_PAYOUT_API_KEY missing from environment. Payout skipped.');
			}
		} else {
			console.warn(`Seller ${sellerId} has no mobile money (whatsapp) number configured. Payout skipped.`);
			payoutStatus = 'failed';
		}

		// 6. Upsert transaction record, including payout data
		const { error: paymentError } = await supabase
			.from('transactions')
			.upsert({
				payment_reference: reference,
				listing_id: listingId,
				buyer_id: buyerId,
				seller_id: sellerId,
				amount: totalAmount,
				status: 'successful',
				payout_status: payoutStatus,
				payout_reference: payoutReference,
				commission_amount: commissionAmount,
				created_at: new Date().toISOString()
			}, { onConflict: 'payment_reference' });
		
		if (paymentError) {
			console.error('Error recording purchase transaction:', paymentError);
			throw paymentError;
		}
	}

	// 7. Send an automated message to start the conversation
	const { error: messageError } = await supabase
		.from('messages')
		.insert({
			listing_id: listingId,
			sender_id: buyerId,
			receiver_id: sellerId,
			content: `Hello! I just purchased this book via BookBridge. When can we meet to complete the exchange?`,
			is_read: false,
			created_at: new Date().toISOString()
		});

	if (messageError) {
		console.error('Error creating automated purchase message:', messageError);
		// Not throwing here so the purchase still succeeds even if the message fails
	}
	
	console.log(`Successfully processed purchase of listing ${listingId} by user ${buyerId}`);
}

/**
 * @param {string} listingId
 * @param {string} buyerId
 * @param {string} reference
 * @param {string|number} amount
 */
async function handlePurchasePending(listingId, buyerId, reference, amount) {
	console.log(`Processing pending purchase for listing ${listingId} by buyer ${buyerId}`);
	
	const supabase = getSupabase();
	if (!supabase) throw new Error('Supabase client not initialized');

	// 1. Get the seller_id from the listing
	const { data: listing, error: fetchError } = await supabase
		.from('listings')
		.select('seller_id')
		.eq('id', listingId)
		.single();

	if (fetchError || !listing) {
		console.error('Error fetching listing for pending purchase:', fetchError);
		throw new Error('Listing not found');
	}

	const sellerId = listing.seller_id;

	// 2. Calculate Payout / Commission (95% to seller, 5% commission)
	const totalAmount = parseInt(String(amount));
	const payoutAmount = Math.floor(totalAmount * 0.95);
	const commissionAmount = totalAmount - payoutAmount;

	// 3. Upsert transaction with status = 'pending_payment'
	const { error: paymentError } = await supabase
		.from('transactions')
		.upsert({
			payment_reference: reference,
			listing_id: listingId,
			buyer_id: buyerId,
			seller_id: sellerId,
			amount: totalAmount,
			status: 'pending_payment',
			payout_status: 'pending',
			payout_reference: null,
			commission_amount: commissionAmount,
			created_at: new Date().toISOString()
		}, { onConflict: 'payment_reference' });

	if (paymentError) {
		console.error('Error recording pending purchase transaction:', paymentError);
		throw paymentError;
	}
	
	console.log(`Successfully recorded pending purchase of listing ${listingId} by user ${buyerId}`);
}
