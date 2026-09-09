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
		service: 'fapshi-payouts',
		time: new Date().toISOString()
	});
}

export async function POST({ request }) {
	const timestamp = new Date().toISOString();
	console.log(`[${timestamp}] Fapshi Payouts Webhook received`);

	// 1. Verify Authentication from Fapshi Payouts Dashboard
	// Note: Authentication disabled as requested. The integration is running
	// in "Set URL Only" mode without a webhook secret.

	try {
		let payload = await request.json();
		console.log(`[${timestamp}] Payout Webhook Payload:`, JSON.stringify(payload));
		
		// Unbox array if necessary
		if (Array.isArray(payload) && payload.length > 0) {
			payload = payload[0];
		}
		
		const status = payload.status || payload.state;
		// transId is the Fapshi reference we saved as `payout_reference` in our database
		const reference = payload.transId || payload.transactionId || payload.id;
		const amount = payload.amount;
		const external_reference = payload.externalId || payload.custom;

		if (!reference) {
		    console.error(`[${timestamp}] Missing transaction reference in payload.`);
		    return json({ error: 'Missing transaction reference' }, { status: 400 });
		}

		console.log(`[${timestamp}] Processing payout update: Ref=${reference}, Status=${status}, Amount=${amount}, Ext=${external_reference}`);

		// 2. Update the corresponding transaction in Supabase
		const supabaseClient = getSupabase();
		if (!supabaseClient) {
		    throw new Error('Supabase client not initialized');
		}

		// Convert Fapshi status (e.g. SUCCESSFUL, FAILED) to our local status shape
		let normalizedStatus = 'pending';
		if (status === 'SUCCESSFUL' || status === 'SUCCESS') {
		    normalizedStatus = 'successful';
		} else if (status === 'FAILED' || status === 'FAIL') {
		    normalizedStatus = 'failed';
		}

		const { data, error } = await supabaseClient
			.from('transactions')
			.update({
				payout_status: normalizedStatus
			})
			.eq('payout_reference', reference)
			.select();

		if (error) {
			console.error(`[${timestamp}] Error updating transaction payout status:`, error);
			throw error;
		}

		if (!data || data.length === 0) {
		    // It's possible the webhook arrives before the original payment request finishes inserting the row,
		    // or the reference doesn't match perfectly.
		    console.warn(`[${timestamp}] No transaction found with payout_reference: ${reference}`);
		} else {
		    console.log(`[${timestamp}] Successfully updated payout status to '${normalizedStatus}' for transaction with reference ${reference}`);
		}

		return json({ success: true, processed_at: timestamp });
	} catch (err) {
		console.error(`[${timestamp}] Payouts Webhook Error:`, err);
		const error = /** @type {Error} */ (err);
		return json({ error: error.message }, { status: 500 });
	}
}
