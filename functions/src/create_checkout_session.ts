import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import Stripe from "stripe";
import * as admin from "firebase-admin";

// Initialize Admin SDK once
try { admin.app(); } catch { admin.initializeApp(); }

// Prices in AED (in fils = minor units)
const AED_PRICES: Record<string, number> = {
  vip: 10000, // AED 100.00
  featured: 5000, // AED 50.00
  urgent: 3000, // AED 30.00
  topBoost: 7500, // AED 75.00
};

export const create_checkout_session = onRequest({ cors: true, region: "us-central1" }, async (req, res) => {
  if (req.method === "OPTIONS") {
    res.set({
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization, x-client-info, apikey",
    }).status(204).send("");
    return;
  }
  res.set({
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization, x-client-info, apikey",
  });
  try {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    const stripeSecret = process.env.STRIPE_SECRET_KEY || process.env.STRIPE_API_KEY;
    if (!stripeSecret) {
      res.status(500).json({ error: "Stripe not configured" });
      return;
    }
    const stripe = new Stripe(stripeSecret, { apiVersion: "2024-06-20" });

    const body = typeof req.body === "string" ? JSON.parse(req.body) : req.body || {};
    const { listingId, selectedPlan, userId } = body as { listingId?: string; selectedPlan?: string; userId?: string };

    if (!listingId || !selectedPlan) {
      res.status(400).json({ error: "Missing listingId or selectedPlan" });
      return;
    }

    const plan = String(selectedPlan);
    if (!AED_PRICES[plan]) {
      res.status(400).json({ error: "Invalid selectedPlan" });
      return;
    }

    const amount = AED_PRICES[plan];
    const currency = "aed";

    // Sanity: ensure listing exists and in pending state if it's a new listing flow
    try {
      const ref = admin.firestore().collection("listings").doc(listingId);
      const snap = await ref.get();
      if (snap.exists) {
        const data = snap.data() as Record<string, any>;
        await ref.set({
          selectedPlan: plan,
          paymentStatus: data?.paymentStatus || "unpaid",
          status: data?.status || "active",
          currency: "AED",
        }, { merge: true });
      }
    } catch (e) {
      logger.warn("Pre-check listing failed", e);
    }

    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      currency,
      line_items: [
        {
          price_data: {
            currency,
            unit_amount: amount,
            product_data: {
              name: `Listing upgrade: ${plan.toUpperCase()}`,
              metadata: { listingId, selectedPlan: plan },
            },
          },
          quantity: 1,
        },
      ],
      success_url: "https://example.com/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "https://example.com/cancel",
      metadata: { listingId, selectedPlan: plan, userId: userId || "" },
      allow_promotion_codes: false,
      customer_creation: "if_required",
    });

    res.status(200).json({
      checkoutUrl: session.url,
      sessionId: session.id,
      amount,
      currency: "AED",
    });
  } catch (e: any) {
    logger.error("create_checkout_session error", e);
    res.status(500).json({ error: e?.message || String(e) });
  }
});
