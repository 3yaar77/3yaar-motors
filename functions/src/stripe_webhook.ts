import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import Stripe from "stripe";
import * as admin from "firebase-admin";

// Initialize Admin SDK once
try { admin.app(); } catch { admin.initializeApp(); }

// Webhooks must not verify Firebase Auth; we validate using Stripe signature
export const stripe_webhook = onRequest({ cors: false, region: "us-central1" }, async (req, res) => {
  const stripeSecret = process.env.STRIPE_SECRET_KEY || process.env.STRIPE_API_KEY;
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!stripeSecret || !webhookSecret) {
    res.status(500).send("Stripe not configured");
    return;
  }

  const stripe = new Stripe(stripeSecret, { apiVersion: "2024-06-20" });

  const sig = req.headers["stripe-signature"] as string | undefined;
  const rawBody = (req as any).rawBody as Buffer | undefined;
  if (!sig || !rawBody) {
    res.status(400).send("Missing signature or rawBody");
    return;
  }

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(rawBody, sig, webhookSecret);
  } catch (err: any) {
    logger.error("Webhook signature verification failed", err);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        const listingId = (session.metadata?.listingId || "").toString();
        const selectedPlan = (session.metadata?.selectedPlan || "").toString();
        // Retrieve payment intent to get id and amount
        const paymentIntentId = (session.payment_intent as string) || "";
        let amount = 0; let currency = (session.currency || "aed").toUpperCase();
        if (paymentIntentId) {
          try {
            const pi = await stripe.paymentIntents.retrieve(paymentIntentId);
            amount = (pi.amount_received || pi.amount || 0) as number; // in minor units
            currency = (pi.currency || currency).toUpperCase();
          } catch (e) {
            logger.warn("Failed to fetch payment intent", e);
          }
        }

        if (listingId) {
          const ref = admin.firestore().collection("listings").doc(listingId);
          const paidAt = admin.firestore.FieldValue.serverTimestamp();
          const update: Record<string, any> = {
            paymentStatus: "paid",
            status: "active",
            paymentId: paymentIntentId || session.id,
            paymentProvider: "stripe",
            paidAt,
            amount: Math.round(amount),
            currency: currency || "AED",
            selectedPlan,
          };
          // Set flags based on plan (idempotent)
          if (selectedPlan === "vip") update.isVip = true;
          if (selectedPlan === "featured") update.isFeatured = true;
          if (selectedPlan === "urgent") update.isUrgent = true;
          await ref.set(update, { merge: true });
          logger.info(`Listing ${listingId} marked paid with plan ${selectedPlan}`);
        }
        break;
      }
      default:
        logger.debug(`Unhandled event type ${event.type}`);
    }
    res.status(200).send("ok");
  } catch (e) {
    logger.error("stripe_webhook handler error", e);
    res.status(500).send("error");
  }
});
