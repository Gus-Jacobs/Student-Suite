// EDIT_NUMBER: 1.0.17 (Surgical update: Final robust implementation of processIAPReceipt)
// September 4, 2025

// Load environment variables from .env files
require('dotenv').config({ path: `.env.${process.env.NODE_ENV || 'production'}` });
require('dotenv').config(); // Load .env as fallback or for local testing

// Add logs to confirm loading during startup
console.log(`DEBUG_ENV_LOAD: NODE_ENV is ${process.env.NODE_ENV}. Attempting to load .env files.`);
console.log(`DEBUG_ENV_LOAD: CHECKOUT_SUCCESS_URL is ${process.env.CHECKOUT_SUCCESS_URL}`);
console.log(`DEBUG_ENV_LOAD: CHECKOUT_CANCEL_URL is ${process.env.CHECKOUT_CANCEL_URL}`);
// HELPER FUNCTIONS AND IMPORTS
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const { VertexAI } = require("@google-cloud/vertexai");
const { OpenAI } = require("openai");
const axios = require("axios");
const jwt = require("jsonwebtoken");
const { AppStoreServerAPIClient, Environment } = require("@apple/app-store-server-library");
const { google } = require("googleapis"); // ✅ for Android verification

// ADDED: Node built-ins to load certs and create HTTPS agent
//const fs = require("fs");
//const path = require("path");
//const https = require("https");
const logger = require("firebase-functions/logger");

// const appleCerts = [
//   "AppleRootCA-G2.pem",
//   "AppleRootCA-G3.pem",
// ].map((file) =>
//   fs.readFileSync(path.join(__dirname, "apple_root_certs", file))
// );

// Custom HTTPS agent that trusts Apple’s root certificates
// const appleCaAgent = new https.Agent({
//   ca: appleCerts,
//   keepAlive: true,
// });

// v2 imports
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { auth } = require("firebase-functions/v1");

const fetch = global.fetch || require('node-fetch');

// Initialize Firebase Admin SDK ONCE at the top level of your script.
if (!admin.apps.length) {
  admin.initializeApp();
}

// Your email address where you want to receive the feedback.
const ADMIN_EMAIL = "pegumaxinc@gmail.com";

// IAP Verification endpoint URLs
const APPLE_VERIFICATION_URL = "https://buy.itunes.apple.com/verifyReceipt";
const APPLE_SANDBOX_VERIFICATION_URL = "https://sandbox.itunes.apple.com/verifyReceipt";
const GOOGLE_VERIFICATION_URL = "https://www.googleapis.com/androidpublisher/v3/applications";

// --- Helper: Normalize Apple Private Key ---
// function normalizePrivateKey(key) {
//   if (!key) return "";
//   return key
//     .replace(/\\n/g, "\n")
//     .replace(/\r\n/g, "\n")
//     .replace(/\r/g, "\n")
//     .trim();
// }

// --- Helper: Load Apple Root Certs ---
// let appleCaAgent = null;
// (function initAppleCaAgent() {
//   try {
//     const useCustom = process.env.USE_CUSTOM_APPLE_CA !== "false";
//     const certDir = path.join(__dirname, "apple_root_certs");
//     const certFiles = [
//       "AppleIncRootCertificate.pem",
//       "Apple_App_Attestation_Root_CA.pem",
//       "AppleRootCA-G2.pem",
//       "AppleRootCA-G3.pem",
//     ];
//     const cas = [];
//     if (fs.existsSync(certDir)) {
//       certFiles.forEach((fname) => {
//         const p = path.join(certDir, fname);
//         if (fs.existsSync(p)) {
//           try {
//             const content = fs.readFileSync(p, "utf8");
//             cas.push(content);
//             console.log(`DEBUG: Loaded Apple CA file: ${p}`);
//           } catch (e) {
//             console.error(`DEBUG: Failed to read ${p}:`, e.message);
//           }
//         }
//       });
//     }
//     if (cas.length > 0 && useCustom) {
//       appleCaAgent = new https.Agent({ ca: cas.join("\n") });
//       console.log("DEBUG: appleCaAgent created with custom Apple root CAs.");
//     } else {
//       console.log("DEBUG: No custom Apple root CA loaded; using system default CAs.");
//     }
//   } catch (err) {
//     console.error("DEBUG: Error initializing Apple CA agent:", err);
//     appleCaAgent = null;
//   }
// })();

// --- Helper: Verify Google Purchase ---
async function verifyGooglePurchase(packageName, productId, purchaseToken) {
  if (!packageName || !productId || !purchaseToken) {
    throw new Error("Missing packageName, productId, or purchaseToken for Android verification.");
  }

  try {
    const authClient = new google.auth.GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    const client = await authClient.getClient();
    const androidPublisher = google.androidpublisher({ version: "v3", auth: client });

    const res = await androidPublisher.purchases.subscriptions.get({
      packageName,
      subscriptionId: productId,
      token: purchaseToken,
    });
    // Typically you'll inspect res.data.status, expiryTimeMillis, etc.
    return res.data;
  } catch (err) {
    const wrapped = new Error("Google Play receipt verification failed: " + (err.message || err));
    wrapped.raw = err;
    if (err.response?.data) wrapped.googleResponse = err.response.data;
    throw wrapped;
  }
}

// Replace existing persistIapError with this version
async function persistIapError(uid, stage, err) {
  const debugEnabled = process.env.ENABLE_IAP_DEBUG_LOGS === "true";

  // Always log to Cloud Logging for debugging visibility
  logger.error("IAP error", {
    uid: uid || null,
    stage,
    message: err?.message || String(err),
    stack: err?.stack || null,
    appleResponse: err?.appleResponse || null,
    raw: err?.raw || null,
  });

  if (!debugEnabled) {
    return; // 🚫 Skip Firestore logging unless debugging is enabled
  }

  try {
    const now = new Date();
    const expireAt = new Date(now.getTime() + 24 * 60 * 60 * 1000); // +1 day

    await admin.firestore().collection("iap_debug_logs").add({
      uid: uid || null,
      stage,
      message: err?.message || String(err),
      stack: err?.stack || null,
      appleResponse: err?.appleResponse || null,
      raw: err?.raw || null,
      ts: admin.firestore.FieldValue.serverTimestamp(),
      expireAt: expireAt,
    });
  } catch (e) {
    console.error("persistIapError failed:", e);
  }
}


// verifyAppleReceipt.js
// Verifies an iOS in-app purchase receipt with Apple servers.
// Handles the 21007 sandbox-vs-production case by retrying against sandbox.
// Returns the Apple response object (parsed JSON).

/**
 * Call Apple verifyReceipt endpoint.
 * @param {string} endpoint - Apple endpoint URL
 * @param {Object} payload - JSON payload to post
 * @param {Object} opts - axios options
 */
async function postToApple(endpoint, payload, opts = {}) {
  const res = await axios.post(endpoint, payload, {
    timeout: opts.timeout || 10000,
    httpsAgent: opts.httpsAgent,
    headers: { "Content-Type": "application/json" },
  });
  return res.data;
}

/**
 * verifyAppleReceipt
 * @param {string} receiptData - base64 receipt string
 * @param {boolean} isSandbox - whether caller requested sandbox (optional)
 * @param {string} uid - optional uid for logs
 * @param {Object} opts - optional settings { httpsAgent }
 * @returns {Object} Apple response JSON
 */

function getAppleSharedSecret() {
  if (process.env.APPLE_SHARED_SECRET) return process.env.APPLE_SHARED_SECRET;
  console.warn('DEBUG: APPLE_SHARED_SECRET not found in process.env. Please provision it via Secret Manager and bind to the function.');
  return null;
}

async function verifyAppleReceipt(receiptData, isSandbox) {
  try {
    const endpoint = isSandbox
      ? APPLE_SANDBOX_VERIFICATION_URL
      : APPLE_VERIFICATION_URL;

    const sharedSecret = getAppleSharedSecret();
    if (!sharedSecret) {
      throw new Error("Apple shared secret not configured");
    }

    console.debug(`[verifyAppleReceipt] Sending receipt to ${endpoint}`);

    const response = await axios.post(endpoint, {
      "receipt-data": receiptData,
      password: sharedSecret,
      "exclude-old-transactions": true,
    }, {
      timeout: 10000,
      headers: { "Content-Type": "application/json" },
    });

    return response.data;
  } catch (err) {
    console.error("[verifyAppleReceipt] Exception:", err);
    throw err;
  }
}




// END HELPER FUNCTIONS AND IMPORT

/**
 * Callable function to send feedback and support emails.
 */
exports.sendAppEmail = onCall({ secrets: ["GMAIL_EMAIL", "GMAIL_PASSWORD"] }, async (request) => {
    // Check for authentication if this email should only be sent by logged-in users
    // if (!request.auth) {
    //     throw new HttpsError(
    //         "unauthenticated",
    //         "The function must be called while authenticated.",
    //     );
    // }

    const { userId, email, type, category, message, version, platform } = request.data;

    // Validate input
    if (!message || !category || !type) {
        throw new HttpsError(
            "invalid-argument",
            "Missing required email fields (message, category, or type).",
        );
    }

    const gmailEmail = process.env.GMAIL_EMAIL; // Access secret via process.env
    const gmailPassword = process.env.GMAIL_PASSWORD; // Access secret via process.env

    if (!gmailEmail || !gmailPassword) {
        console.error("GMAIL_EMAIL or GMAIL_PASSWORD secret is not set for sendAppEmail.");
        throw new HttpsError("internal", "Server email configuration is missing.");
    }

    const mailTransport = nodemailer.createTransport({
        service: 'gmail',
        auth: {
            user: gmailEmail,
            pass: gmailPassword,
        },
    });

    const mailOptions = {
        from: `"${type} from Student Suite" <${gmailEmail}>`, // Sender's display name and email
        to: ADMIN_EMAIL, // Recipient: your company's admin email
        subject: `${type} [${category}] from ${email || 'Anonymous'}`, 
        html: `
            <h1>${type} Received</h1>
            <p><b>Category:</b> ${category}</p>
            <p><b>From:</b> ${email || 'Anonymous User'} (User ID: ${userId || 'N/A'})</p>
            <p><b>Platform:</b> ${platform || 'N/A'}</p>
            <p><b>App Version:</b> ${version || 'N/A'}</p>
            <hr>
            <h2>Message:</h2>
            <p>${message.replace(/\n/g, "<br>")}</p>
        `,
    };

    try {
        await mailTransport.sendMail(mailOptions);
        console.log(`Email '${type}' from user ${userId || 'anonymous'} sent successfully.`);
        return { success: true, message: "Email sent successfully" };
    } catch (error) {
        console.error("Error sending email:", error);
        throw new HttpsError(
            "internal",
            "Failed to send email.",
            error,
        );
    }
});

/**
 * Creates a Stripe Checkout session and writes session metadata back to the Firestore doc.
 * Drop-in replacement for existing createStripeCheckout function.
 */
exports.createStripeCheckout = onDocumentCreated({
    document: "users/{userId}/checkout_sessions/{sessionId}",
    secrets: ["STRIPE_SECRET_KEY"]
  }, async (event) => {
  // --- MOST BASIC LOG ---
  console.log(`DEBUG_ENTRY: createStripeCheckout triggered for path: ${event.data.ref.path}`); 

  const snap = event.data;
  const data = snap.data() || {};
  const userId = event.params.userId;
  // Destructure couponId from input data
  const { price, success_url, cancel_url, couponId } = data;

  // --- SECRET CHECK ---
  let stripeSecretKey;
  try {
      stripeSecretKey = process.env.STRIPE_SECRET_KEY;
      if (!stripeSecretKey || stripeSecretKey.length < 10) {
          throw new Error("STRIPE_SECRET_KEY not found or is too short in process.env");
      }
      console.log(`DEBUG_SECRET: STRIPE_SECRET_KEY loaded. Length: ${stripeSecretKey.length}, Starts with: ${stripeSecretKey.substring(0, 8)}...`);
  } catch (secretError) {
      console.error("CRITICAL_ERROR_SECRET: Failed to load STRIPE_SECRET_KEY.", secretError);
      await snap.ref.set({ error: { message: `CRITICAL: Server configuration error - Stripe secret key failed to load: ${secretError.message}` } }, { merge: true });
      return; 
  }

  // --- STRIPE LIBRARY INITIALIZATION CHECK ---
  let stripe;
  try {
      stripe = require("stripe")(stripeSecretKey);
      if (!stripe || typeof stripe.checkout !== 'object') {
         throw new Error("Stripe library loaded but seems incomplete or invalid.");
      }
      console.log("DEBUG_STRIPE_INIT: Stripe library initialized successfully.");
  } catch (initError) {
      console.error("CRITICAL_ERROR_STRIPE_INIT: Failed to initialize Stripe library!", initError);
      await snap.ref.set({ error: { message: `Stripe library initialization failed: ${initError.message}` } }, { merge: true });
      return; 
  }

  // --- MAIN LOGIC ---
  try {
      console.log(`DEBUG_GET_USER: Fetching Auth user ${userId}`);
      const user = await admin.auth().getUser(userId);
      console.log(`DEBUG_GET_USER_DOC: Fetching Firestore user doc ${userId}`);
      const userDocRef = admin.firestore().collection("users").doc(userId);
      const userDoc = await userDocRef.get();

      let customerId = userDoc.data()?.stripeCustomerId;

      if (!customerId) {
          console.log(`DEBUG_CREATE_CUSTOMER: No Stripe Customer ID found for ${userId}, creating new customer.`);
          const customer = await stripe.customers.create({
              email: user.email,
              metadata: { firebaseUID: userId },
          });
          customerId = customer.id;
          await userDocRef.update({ stripeCustomerId: customerId });
          console.log(`DEBUG_CREATE_CUSTOMER_SUCCESS: Created new Stripe Customer ID: ${customerId} for user ${userId}.`);
      } else {
          console.log(`DEBUG_EXISTING_CUSTOMER: Found Stripe Customer ID: ${customerId} for user ${userId}.`);
      }

      if (!price) {
          throw new Error('Missing required field `price` in checkout_sessions document.');
      }

      const successUrlFinal = success_url || process.env.CHECKOUT_SUCCESS_URL || process.env.APP_URL || null;
      const cancelUrlFinal = cancel_url || process.env.CHECKOUT_CANCEL_URL || process.env.APP_URL || null;
      if (!successUrlFinal || !cancelUrlFinal) {
          throw new Error('Missing success_url or cancel_url; configure them in doc or env vars.');
      }

      console.log(`DEBUG_CREATE_SESSION: About to call stripe.checkout.sessions.create for customer ${customerId} with price ${price}. Coupon: ${couponId || "None"}`);
      
      // Build Session Config
      const sessionConfig = {
          payment_method_types: ["card"],
          mode: "subscription",
          customer: customerId,
          line_items: [{ price, quantity: 1 }],
          success_url: successUrlFinal,
          cancel_url: cancelUrlFinal,
          // APPLY COUPON IF PROVIDED
          discounts: couponId ? [{ coupon: couponId }] : undefined,
      };

      const session = await stripe.checkout.sessions.create(sessionConfig);

      console.log(`DEBUG_CREATE_SESSION_SUCCESS: Stripe Checkout session created: id=${session.id}`);

      await snap.ref.set({
          url: session.url,
          sessionId: session.id,
          sessionMode: session.mode || "subscription",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      await admin.firestore().collection("users").doc(userId).collection("checkout").doc(session.id).set({
          sessionId: session.id,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          price,
          couponId: couponId || null, // Track if a coupon was used
          status: "created",
      }, { merge: true });

      console.log("DEBUG_SUCCESS: --- createStripeCheckout FUNCTION END (Success) ---");

  } catch (error) {
      // Log specific errors more clearly
      console.error("ERROR_DURING_EXECUTION: createStripeCheckout failed.", {
         errorMessage: error.message,
         errorStack: error.stack,
         errorType: error.type, 
         errorCode: error.code, 
         userId: userId,
         path: snap.ref.path,
      });
      await snap.ref.set({ error: { message: `Execution Error: ${error.message || String(error)}` } }, { merge: true });
      console.log("DEBUG_FAILURE: --- createStripeCheckout FUNCTION END (Failure) ---");
  }
});


/**
 * HTTP CloudEvent endpoint for createStripeCheckout.
 * Purpose: some Eventarc delivery modes (Pub/Sub binding/protobuf) don't
 * always get decoded by the v2 Firestore wrapper. This HTTP endpoint
 * accepts the CloudEvent (binary or structured), extracts the Firestore
 * document resource name from the CloudEvent subject or message attributes,
 * reads the document via Admin SDK, and runs the same Stripe checkout flow.
 *
 * This is a compatible fallback: Eventarc triggers can be pointed at the
 * same Cloud Run service and will successfully invoke this handler.
 */
exports.createStripeCheckoutHttp = onRequest({ secrets: ["STRIPE_SECRET_KEY"] }, async (req, res) => {
  console.log('DEBUG: --- createStripeCheckoutHttp START ---');
  try {
    // Inspect common CloudEvent locations for the document resource name.
    // 1) Binary-mode CloudEvents often supply the subject in the ce-subject header.
    // 2) Pub/Sub push-style bodies may include message.attributes.subject or message.attributes['googclient_something']
    let subject = req.header && (req.header('ce-subject') || req.header('Ce-Subject'));

    if (!subject && req.headers && (req.headers['ce-subject'] || req.headers['Ce-Subject'])) {
      subject = req.headers['ce-subject'] || req.headers['Ce-Subject'];
    }

    // Try structured body fields as a fallback. Eventarc may deliver a Pub/Sub
    // push with { message: { data: '<base64>', attributes: { ... } } }
    if (!subject && req.body) {
      // 1) CloudEvent structured mode may include 'subject'
      if (req.body['subject']) subject = req.body['subject'];

      // 2) Pub/Sub push: message.attributes.subject or attributes['googclient_resource']
      if (!subject && req.body.message && req.body.message.attributes) {
        subject = req.body.message.attributes.subject || req.body.message.attributes['googclient_resource'] || subject;
      }

      // 3) Pub/Sub push: decode message.data (base64) and try to parse a nested CloudEvent
      if (!subject && req.body.message && req.body.message.data) {
        try {
          const b64 = req.body.message.data;
          const json = JSON.parse(Buffer.from(b64, 'base64').toString('utf8'));
          // CloudEvent structured payload may contain 'subject' or 'protoPayload'
          if (json.subject) subject = json.subject;
          else if (json.protoPayload && json.protoPayload.resource && json.protoPayload.resource.name) subject = json.protoPayload.resource.name;
          else if (json['@type'] && json['resource'] && json['resource']['name']) subject = json['resource']['name'];
        } catch (e) {
          // ignore parse errors - we'll report missing subject later
        }
      }
    }

    if (!subject || typeof subject !== 'string') {
      console.warn('DEBUG: createStripeCheckoutHttp - no subject found in CloudEvent. Headers:', req.headers, 'Body keys:', Object.keys(req.body || {}));
      return res.status(400).send('Missing CloudEvent subject');
    }

    // Subject typically contains the full resource name, extract path after '/documents/'
  const docMatch = subject.match(/\/documents\/(.+)$/);
    if (!docMatch || !docMatch[1]) {
      console.error('DEBUG: createStripeCheckoutHttp - failed to parse document path from subject:', subject);
      return res.status(400).send('Invalid CloudEvent subject for Firestore document');
    }

    const docPath = docMatch[1]; // e.g. users/UID/checkout_sessions/SESSION
    console.log('DEBUG: createStripeCheckoutHttp - resolved docPath=', docPath);

    const docRef = admin.firestore().doc(docPath);
    const snap = await docRef.get();
    if (!snap.exists) {
      console.warn('DEBUG: createStripeCheckoutHttp - document not found at', docPath);
      return res.status(404).send('Document not found');
    }

    const data = snap.data() || {};
    const userId = docPath.split('/')[1] || null;

    // Use only env vars for secrets in gen2 runtimes
    const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
    if (!stripeSecretKey) {
      console.error('STRIPE_SECRET_KEY is not set for createStripeCheckoutHttp.');
      await docRef.set({ error: { message: 'Server configuration error: Stripe secret key missing.' } }, { merge: true });
      return res.status(500).send('Stripe secret missing');
    }
    const stripe = require('stripe')(stripeSecretKey);

    try {
      const user = userId ? await admin.auth().getUser(userId) : null;
      const userDocRef = admin.firestore().collection('users').doc(userId);
      const userDoc = await userDocRef.get();

      let customerId = userDoc.data()?.stripeCustomerId;
      if (!customerId) {
        console.log(`DEBUG: (http) No Stripe Customer ID found for ${userId}, creating new customer.`);
        const customer = await stripe.customers.create({ email: user?.email, metadata: { firebaseUID: userId } });
        customerId = customer.id;
        await userDocRef.update({ stripeCustomerId: customerId });
        console.log(`DEBUG: (http) Created new Stripe Customer ID: ${customerId} for user ${userId}.`);
      }

      const price = data.price;
      const success_url = data.success_url || data.successUrl || data.successUrlString || process.env.CHECKOUT_SUCCESS_URL || process.env.APP_URL || null;
      const cancel_url = data.cancel_url || data.cancelUrl || data.cancelUrlString || process.env.CHECKOUT_CANCEL_URL || process.env.APP_URL || null;

      if (!price) {
        const msg = 'Missing required field `price` in checkout_sessions document.';
        console.error('DEBUG (http):', msg);
        await docRef.set({ error: { message: msg } }, { merge: true });
        return res.status(400).send(msg);
      }
      if (!success_url || !cancel_url) {
        const msg = 'Missing success/cancel URLs; include them in the checkout_sessions doc or set CHECKOUT_SUCCESS_URL/CHECKOUT_CANCEL_URL env vars.';
        console.error('DEBUG (http):', msg);
        await docRef.set({ error: { message: msg } }, { merge: true });
        return res.status(400).send(msg);
      }

      console.log(`DEBUG: (http) Creating Stripe Checkout session for customer ${customerId} with price ${price}.`);
      const session = await stripe.checkout.sessions.create({
        payment_method_types: ['card'],
        mode: 'subscription',
        customer: customerId,
        line_items: [{ price, quantity: 1 }],
        success_url,
        cancel_url
      });

      console.log(`DEBUG: (http) Stripe Checkout session created: id=${session.id}, url=${session.url}`);

      await docRef.set({ url: session.url, sessionId: session.id, sessionMode: session.mode || 'subscription', createdAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });

      await admin.firestore().collection('users').doc(userId).collection('checkout').doc(session.id).set({ sessionId: session.id, createdAt: admin.firestore.FieldValue.serverTimestamp(), price, status: 'created' }, { merge: true });

      console.log('DEBUG: --- createStripeCheckoutHttp END ---');
      return res.status(200).send('ok');
    } catch (error) {
      console.error('Stripe Checkout Error (http):', error);
      await docRef.set({ error: { message: (error && error.message) || String(error) } }, { merge: true });
      return res.status(500).send('checkout error');
    }
  } catch (err) {
    console.error('createStripeCheckoutHttp unexpected error:', err);
    return res.status(500).send('internal error');
  }
});


/**
 * Creates a Stripe Customer Portal session to allow users to manage their
 * subscriptions.
 */
exports.createStripePortalLink = onDocumentCreated({
  document: "users/{userId}/portal_links/{linkId}",
  secrets: ["STRIPE_SECRET_KEY"]
}, async (event) => {
    // --- DEBUG LOGGING START ---
    console.log("DEBUG: --- createStripePortalLink FUNCTION START ---");
    console.log("DEBUG: STRIPE_SECRET_KEY access:", typeof process.env.STRIPE_SECRET_KEY !== 'undefined' && process.env.STRIPE_SECRET_KEY !== '' ? "SET and has value" : "NOT SET or empty");
    console.log("DEBUG: All available environment variables (CAUTION: review sensitive info in logs):", process.env);
    console.log("DEBUG: Input data for createStripePortalLink:", event.data.data()); // Log input document data
    // --- DEBUG LOGGING END ---

    const snap = event.data;
    const {return_url} = snap.data();
    const userId = event.params.userId;

    // Read Stripe secret from environment variables (gen2 best practice)
    const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
    if (!stripeSecretKey) {
        console.error("STRIPE_SECRET_KEY is not set for createStripePortalLink.");
        await snap.ref.set({error: {message: "Server configuration error: Stripe secret key missing."}}, {merge: true});
        return;
    }
    const stripe = require("stripe")(stripeSecretKey);

    try {
        const userDoc = await admin.firestore()
            .collection("users").doc(userId).get();
        const customerId = userDoc.data()?.stripeCustomerId;

        if (!customerId) {
            console.error(`DEBUG: User ${userId} does not have a Stripe Customer ID. Cannot create portal link.`);
            throw new Error("User does not have a Stripe Customer ID.");
        }
        console.log(`DEBUG: Creating Stripe Customer Portal session for customer ${customerId}.`);
        const session = await stripe.billingPortal.sessions.create({
            customer: customerId,
            return_url,
        });
        console.log(`DEBUG: Stripe Customer Portal session created with URL: ${session.url}.`);

        await snap.ref.set({url: session.url}, {merge: true});
    } catch (error) {
        console.error("Stripe Portal Error:", error);
        await snap.ref.set({error: {message: error.message}}, {merge: true});
    }
    console.log("DEBUG: --- createStripePortalLink FUNCTION END ---");
});

/**
 * Robust Stripe webhook handler that updates Firestore user docs and calls updateUserRole.
 * Drop-in replacement for existing stripeWebhook function.
 */
exports.stripeWebhook = onRequest({ secrets: ["STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET"] }, async (req, res) => {
  console.log("DEBUG: --- stripeWebhook FUNCTION START ---");
  const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
  const stripeWebhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  if (!stripeSecretKey || !stripeWebhookSecret) {
    console.error("Stripe secrets (STRIPE_SECRET_KEY or STRIPE_WEBHOOK_SECRET) are not set for stripeWebhook.");
    return res.status(500).send("Server configuration error: Stripe secrets missing.");
  }
  const stripe = require("stripe")(stripeSecretKey);

  const signature = req.headers["stripe-signature"];
  const endpointSecret = stripeWebhookSecret;

  let event;
  try {
    // Ensure we pass a Buffer or string to stripe.webhooks.constructEvent.
    // req.rawBody is preferred (it will be a Buffer). If not present,
    // stringify the body which yields the raw bytes that were delivered.
    // This improves compatibility between different runtimes that may
    // or may not populate rawBody.
    let payload = req.rawBody;
    if (!payload) {
      try {
        // If body is already a string, use it. Otherwise stringify.
        payload = typeof req.body === 'string' ? req.body : JSON.stringify(req.body || {});
      } catch (e) {
        payload = '';
      }
    }

    event = stripe.webhooks.constructEvent(payload, signature, endpointSecret);
    console.log(`DEBUG: Stripe event type received: ${event.type}`);
  } catch (err) {
    console.error("Webhook signature verification failed.", err && err.message);
    return res.status(400).send(`Webhook Error: ${err && err.message}`);
  }

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object;
        console.log("DEBUG: checkout.session.completed:", session.id);
        // session.customer is the stripe customer id
        if (session.customer) {
          // Write audit info to user checkout subcollection (if user has customerId mapping)
          const usersQuery = await admin.firestore().collection("users").where("stripeCustomerId", "==", session.customer).limit(1).get();
          if (!usersQuery.empty) {
            const userDoc = usersQuery.docs[0];
            await userDoc.ref.collection("checkout").doc(session.id).set({
              sessionId: session.id,
              status: "completed",
              session: session,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            console.log(`DEBUG: Recorded checkout.session.completed for user ${userDoc.id}`);
          } else {
            console.warn("DEBUG: checkout.session.completed - no user found for customer id:", session.customer);
          }
        }
        break;
      }

      case "customer.subscription.created":
      case "customer.subscription.updated": {
        const subscription = event.data.object;
        const customerId = subscription.customer;
        const stripeSubscriptionId = subscription.id;
        const status = subscription.status; // active, past_due, canceled...
        const periodEnd = subscription.current_period_end; // seconds epoch

        console.log(`DEBUG: customer.subscription.updated -> customer=${customerId}, subscription=${stripeSubscriptionId}, status=${status}, periodEnd=${periodEnd}`);

        // Find the user document by stripeCustomerId
        const usersQuery = await admin.firestore().collection("users").where("stripeCustomerId", "==", customerId).limit(1).get();
        if (!usersQuery.empty) {
          const userDoc = usersQuery.docs[0];
          const userRef = userDoc.ref;

          // Persist subscription metadata on user document
          const updatePayload = {
            stripeSubscriptionId,
            stripeRole: (status === "active" ? "pro" : "free"),
            subscription: {
              platform: "stripe",
              productId: subscription.items && subscription.items.data && subscription.items.data[0] ? (subscription.items.data[0].price?.id || subscription.items.data[0].plan?.id || null) : null,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              expiresDate: periodEnd ? new Date(periodEnd * 1000).toISOString() : null,
            }
          };

          try {
            await userRef.update(updatePayload);
            console.log(`DEBUG: Updated user ${userDoc.id} with stripe subscription info.`);
          } catch (err) {
            console.error("DEBUG: Failed to update user with subscription info:", err);
          }

          // Call shared updateUserRole logic to set custom claims & finalize role
          await updateUserRole(customerId, status === "active" ? "active" : "inactive", "stripe"); // <-- PASS customerId
        } else {
          console.warn("DEBUG: customer.subscription.updated - no user found for stripe customer:", customerId);
        }
        break;
      }

      case "customer.subscription.deleted": {
        const subscription = event.data.object;
        const customerId = subscription.customer;
        console.log(`DEBUG: customer.subscription.deleted -> customer=${customerId}, subscription=${subscription.id}`);
        const usersQuery = await admin.firestore().collection("users").where("stripeCustomerId", "==", customerId).limit(1).get();
        if (!usersQuery.empty) {
          const userDoc = usersQuery.docs[0];
          try {
            await userDoc.ref.update({
              stripeSubscriptionId: admin.firestore.FieldValue.delete(),
              stripeRole: "free",
              "subscription.platform": "stripe",
              "subscription.updatedAt": admin.firestore.FieldValue.serverTimestamp(),
              "subscription.expiresDate": null,
            });
            console.log(`DEBUG: Cleared subscription info for user ${userDoc.id} after deletion.`);
            await updateUserRole(customerId, "canceled", "stripe");
          } catch (err) {
            console.error("DEBUG: Error clearing subscription info on delete:", err);
          }
        } else {
          console.warn("DEBUG: customer.subscription.deleted - no user found for stripe customer:", customerId);
        }
        break;
      }

      case "invoice.payment_succeeded": {
        const invoice = event.data.object;
        const subscriptionId = invoice.subscription;
        const customerId = invoice.customer;
        console.log(`DEBUG: invoice.payment_succeeded for subscription=${subscriptionId}, customer=${customerId}`);
        // Find the user and mark active
        const usersQuery = await admin.firestore().collection("users").where("stripeCustomerId", "==", customerId).limit(1).get();
        if (!usersQuery.empty) {
          const userDoc = usersQuery.docs[0];
          // update role / last paid time
          await userDoc.ref.update({
            stripeRole: "pro",
            "subscription.updatedAt": admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          await updateUserRole(customerId, "active", "stripe"); // <-- PASS customerId
        }
        break;
      }

      case "invoice.payment_failed": {
        const invoice = event.data.object;
        const customerId = invoice.customer;
        console.log(`DEBUG: invoice.payment_failed for customer=${customerId}`);
        const usersQuery = await admin.firestore().collection("users").where("stripeCustomerId", "==", customerId).limit(1).get();
        if (!usersQuery.empty) {
          const userDoc = usersQuery.docs[0];
          try {
            await userDoc.ref.update({
              stripeRole: "free",
              "subscription.updatedAt": admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            await updateUserRole(customerId, "past_due", "stripe");
          } catch (err) {
            console.error("DEBUG: invoice.payment_failed - update error:", err);
          }
        }
        break;
      }

      default:
        console.log(`DEBUG: Unhandled Stripe event type ${event.type}`);
    }

    console.log("DEBUG: --- stripeWebhook FUNCTION END ---");
    return res.status(200).send();
  } catch (err) {
    console.error("DEBUG: Exception handling stripe webhook:", err);
    return res.status(500).send(`Webhook handler error: ${err.message || String(err)}`);
  }
});


// Replace or drop-in for exports.processIAPReceipt in index.js

// Helper: normalize/clean incoming receipt string for Apple endpoint
function normalizeReceiptForServer(raw) {
  if (!raw) return null;
  let s = String(raw).trim();

  // Remove surrounding quotes
  if (s.startsWith('"') && s.endsWith('"') && s.length > 1) {
    s = s.substring(1, s.length - 1).trim();
  }

  // Remove whitespace/newlines
  s = s.replace(/\s+/g, '');

  // If it looks like JSON, try to extract common fields
  if (s.startsWith('{')) {
    try {
      const parsed = JSON.parse(raw);
      // common wrapper keys that might contain base64 payload
      const keys = ['data', 'receipt', 'signedTransactionInfo', 'transactionReceipt', 'payload'];
      for (const k of keys) {
        if (parsed[k] && typeof parsed[k] === 'string' && parsed[k].trim().length > 0) {
          return parsed[k].trim();
        }
      }
      // if there's a nested object with 'data' field
      for (const v of Object.values(parsed)) {
        if (v && typeof v === 'object') {
          for (const k of keys) {
            if (v[k] && typeof v[k] === 'string' && v[k].trim().length > 0) {
              return v[k].trim();
            }
          }
        }
      }
    } catch (e) {
      // ignore JSON parse errors; continue to other heuristics
    }
  }

  // If it's a JWT-like token (contains '.'), try to extract base64 parts from payload
  if (s.indexOf('.') >= 0) {
    try {
      const parts = s.split('.');
      if (parts.length >= 2) {
        let payload = parts[1];
        // base64url -> base64
        payload = payload.replace(/-/g, '+').replace(/_/g, '/');
        while (payload.length % 4 !== 0) payload += '=';
        const decoded = Buffer.from(payload, 'base64').toString('utf8');
        try {
          const decodedJson = JSON.parse(decoded);
          const candidateKeys = ['receipt', 'data', 'signedTransactionInfo', 'transactionReceipt', 'payload'];
          for (const key of candidateKeys) {
            if (decodedJson[key] && typeof decodedJson[key] === 'string' && decodedJson[key].trim().length > 0) {
              return decodedJson[key].trim().replace(/\s+/g, '');
            }
          }
        } catch (e) {
          // not parseable JSON; continue
        }
      }
    } catch (e) {
      // ignore
    }
  }

  // Convert base64url to base64 if it contains '-' or '_' but not dots
  if (s.indexOf('-') >= 0 || s.indexOf('_') >= 0) {
    s = s.replace(/-/g, '+').replace(/_/g, '/');
    while (s.length % 4 !== 0) s += '=';
  }

  // Strip any leftover non-base64 characters (rare) - but keep a copy for diagnostics upstream
  s = s.replace(/[^A-Za-z0-9+/=]/g, '');

  return s;
}

// DROP-IN: Robust processIAPReceipt callable
exports.processIAPReceipt = onCall({ secrets: ["APPLE_SHARED_SECRET"] }, async (request) => {
  console.debug("[processIAPReceipt] Start - incoming data keys:", Object.keys(request.data || {}));

  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be authenticated");
  }

  const uid = request.auth.uid;

  // Accept both shapes: Flutter may send 'platform' or 'source'
  // Also accept productIdentifier | productId
  const incoming = request.data || {};
  let {
    receiptData: rawReceipt,
    platform: incomingPlatform,
    source,
    isSandbox = false,
    productIdentifier,
    productId,
  } = incoming;

  // Map platform from various inputs (source used in previous Flutter call)
  let platform = null;
  if (incomingPlatform && typeof incomingPlatform === "string") {
    platform = incomingPlatform.toLowerCase();
  } else if (source && typeof source === "string") {
    const s = source.toLowerCase();
    if (s === "app_store" || s === "appstore" || s === "apple" || s === "ios") platform = "ios";
    else if (s === "play_store" || s === "playstore" || s === "android") platform = "android";
    else platform = s;
  }

  // Accept either productIdentifier or productId
  const productIdentifierFinal = productIdentifier || productId || null;

  console.debug(`[processIAPReceipt] uid=${uid}, platform=${platform}, productIdentifier=${productIdentifierFinal}, isSandbox=${isSandbox}`);

  // Basic validation
  if (!rawReceipt || (!platform && platform !== "ios" && platform !== "android")) {
    await persistIapError(uid, "missing_arguments", { provided: Object.keys(incoming) });
    throw new HttpsError("invalid-argument", "Missing receiptData or platform/source. Expect receiptData and platform/source ('app_store'|'play_store').");
  }

  // Normalize incoming receipt using your helper
  let receiptData = normalizeReceiptForServer(rawReceipt);

  // Validate base64-ish string (no dots, only base64 chars)
  const isString = typeof receiptData === "string";
  const base64Regex = /^[A-Za-z0-9+/=]+$/;
  if (!isString || !base64Regex.test(receiptData) || receiptData.indexOf('.') >= 0) {
    await persistIapError(uid, "receipt_normalization_failed", { rawLength: String(rawReceipt).length, sample: String(rawReceipt).slice(0, 200) });
    throw new HttpsError("invalid-argument", "receiptData must be a base64 string after normalization.");
  }

  try {
    // PLATFORM-SPECIFIC VERIFICATION
    if (platform === "ios") {
      console.debug("[processIAPReceipt] Verifying receipt with Apple (prod then sandbox fallback if needed).");
      // ask Apple to verify (production by default)
      let appleResp = await verifyAppleReceipt(receiptData, isSandbox);

      // If Apple says 21007, receipt is from sandbox — retry against sandbox endpoint
      if (appleResp && appleResp.status === 21007) {
        console.log("[processIAPReceipt] Apple returned 21007 -> retrying sandbox endpoint");
        appleResp = await verifyAppleReceipt(receiptData, true);
      }

      // Validate Apple response structure
      if (!appleResp || typeof appleResp.status === "undefined") {
        await persistIapError(uid, "apple_response_format", { response: appleResp });
        throw new HttpsError("internal", "Invalid response from Apple verification.");
      }

      if (appleResp.status !== 0) {
        // non-zero means failure; log response for debugging
        await persistIapError(uid, "apple_verification_failed", { status: appleResp.status, appleResponse: appleResp });
        throw new HttpsError("invalid-argument", `Apple verification failed with status ${appleResp.status}`);
      }

      // Apple returned success — inspect latest_receipt_info (array) for expiry and product id
      const latestInfoArray = appleResp.latest_receipt_info || appleResp.in_app || [];
      // Normalize to an array and pick the most-recent by expiry (expires_date_ms)
      const latest = Array.isArray(latestInfoArray) && latestInfoArray.length
        ? latestInfoArray.slice().sort((a, b) => {
            const aMs = parseInt(a.expires_date_ms || a.expires_date || "0", 10) || 0;
            const bMs = parseInt(b.expires_date_ms || b.expires_date || "0", 10) || 0;
            return bMs - aMs;
          })[0]
        : null;

      if (!latest) {
        await persistIapError(uid, "apple_no_latest_info", { appleResponse: appleResp });
        throw new HttpsError("failed-precondition", "No purchase data found in Apple response.");
      }

      // Parse expiry (apple uses expires_date_ms typically)
      const expiresMs = parseInt(latest.expires_date_ms || latest.expires_date || "0", 10);
      const nowMs = Date.now();

      if (!expiresMs || isNaN(expiresMs) || expiresMs < nowMs) {
        await persistIapError(uid, "apple_subscription_expired", { expiresMs, nowMs, latest });
        throw new HttpsError("failed-precondition", "Subscription expired or not active.");
      }

      // Derive product id from latest entry if not supplied
      const detectedProductId = latest.product_id || latest.productIdentifier || productIdentifierFinal || null;

      // Persist subscription info: product, platform, expiry
      await admin.firestore().collection("users").doc(uid).set({
        subscription: {
          productId: detectedProductId,
          platform: "ios",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresDate: new Date(expiresMs).toISOString(),
        }
      }, { merge: true });

      // Update role
      await updateUserRole(uid, "active", "iap");

      console.log(`[processIAPReceipt] Apple verification success for uid=${uid}, product=${detectedProductId}, expires=${new Date(expiresMs).toISOString()}`);
      return { success: true };

    } else if (platform === "android") {
      console.debug("[processIAPReceipt] Verifying receipt with Google Play.");

      // Android receipts often come as JSON with purchaseToken, packageName, productId
      let parsed;
      try {
        parsed = typeof rawReceipt === "string" ? JSON.parse(rawReceipt) : rawReceipt;
      } catch (e) {
        parsed = rawReceipt;
      }

      const purchaseToken = parsed?.purchaseToken || parsed?.token || parsed?.purchase_token;
      const packageName = parsed?.packageName || parsed?.package_name || parsed?.package || null;
      const productId = parsed?.productId || parsed?.productId || productIdentifierFinal || null;

      if (!purchaseToken || !packageName || !productId) {
        await persistIapError(uid, "android_missing_fields", { parsedSample: JSON.stringify(parsed).slice(0, 300) });
        throw new HttpsError("invalid-argument", "Android verification requires purchaseToken, packageName, and productId.");
      }

      const googleResp = await verifyGooglePurchase(packageName, productId, purchaseToken);

      // googleResp structure varies — try a few possible fields for expiry/acknowledge
      const expiryTimeMillis = googleResp?.expiryTimeMillis || googleResp?.expiryTime || googleResp?.expiry_time_millis;
      const acknowledged = (typeof googleResp?.acknowledgementState !== "undefined")
        ? googleResp.acknowledgementState === 1
        : (typeof googleResp?.acknowledged !== "undefined" ? !!googleResp.acknowledged : true);

      const nowMs = Date.now();
      const expiryMs = expiryTimeMillis ? parseInt(expiryTimeMillis, 10) : 0;

      if (!googleResp) {
        await persistIapError(uid, "google_no_response", { packageName, productId, purchaseToken });
        throw new HttpsError("internal", "Invalid response from Google Play verification.");
      }

      if (!acknowledged) {
        await persistIapError(uid, "google_not_acknowledged", { googleResp });
        throw new HttpsError("failed-precondition", "Android purchase not acknowledged.");
      }

      if (!expiryMs || isNaN(expiryMs) || expiryMs < nowMs) {
        await persistIapError(uid, "google_subscription_expired", { expiryMs, nowMs, googleResp });
        throw new HttpsError("failed-precondition", "Android subscription not active or expired.");
      }

      // Persist subscription info
      await admin.firestore().collection("users").doc(uid).set({
        subscription: {
          productId: productId,
          platform: "android",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresDate: new Date(expiryMs).toISOString(),
        }
      }, { merge: true });

      // Update role
      await updateUserRole(uid, "active", "iap");

      console.log(`[processIAPReceipt] Google verification success for uid=${uid}, product=${productId}, expires=${new Date(expiryMs).toISOString()}`);
      return { success: true };

    } else {
      await persistIapError(uid, "unsupported_platform", { platform });
      throw new HttpsError("invalid-argument", "Unsupported platform. Expect 'ios' or 'android'.");
    }
  } catch (err) {
    // If it's already an HttpsError, rethrow so Cloud Functions returns the appropriate status
    console.error("[processIAPReceipt] Error during verification:", err && err.message ? err.message : err);

    // Persist details for debugging (non-blocking)
    try {
      await persistIapError(uid, "verification_exception", {
        message: err?.message || String(err),
        stack: err?.stack,
        rawReceiptSample: String((rawReceipt || "")).slice(0, 300)
      });
    } catch (persistErr) {
      console.error("[processIAPReceipt] persistIapError failed:", persistErr);
    }

    if (err instanceof HttpsError) throw err;

    // Wrap unexpected errors
    throw new HttpsError("internal", "Verification failed due to an internal error.", err?.message || String(err));
  }
});

/**
 * updateUserRole - Updates Firestore role fields and Auth custom claims based on subscription status.
 * - customerId: either stripeCustomerId (for 'stripe') or uid (for 'iap')
 * - status: "active", "past_due", "canceled", "trialing", etc. (from Stripe/IAP)
 * - platform: 'stripe' | 'iap'
 */
async function updateUserRole(customerId, status, platform) {
  // --- START: Detailed logging ---
  const logPrefix = `DEBUG_UpdateRole [${platform}] User: ${customerId}, Status: ${status} ->`;
  console.log(`${logPrefix} --- Function START ---`);
  // --- END: Detailed logging ---

  let userDocRef = null;
  // let userDoc = null; // We don't need the initial snapshot here anymore
  let userId = null; // Use userId consistently for Firebase UID

  try {
    // --- Step 1: Find Firebase User ID ---
    if (platform === 'stripe') {
      const stripeCustomerId = customerId; // Rename for clarity
      console.log(`${logPrefix} Finding user by stripeCustomerId: ${stripeCustomerId}`);
      const usersQuery = await admin.firestore().collection("users").where("stripeCustomerId", "==", stripeCustomerId).limit(1).get();
      if (usersQuery.empty) {
        console.error(`${logPrefix} ERROR: No user found for Stripe Customer ID: ${stripeCustomerId}. Cannot update role.`);
        return null; // Stop if user not found
      }
      // userDoc = usersQuery.docs[0]; // Not needed here
      userDocRef = usersQuery.docs[0].ref;
      userId = usersQuery.docs[0].id; // Get the Firebase UID
      console.log(`${logPrefix} Found Firebase userId: ${userId}`);
    } else if (platform === 'iap') {
      userId = customerId; // For IAP, customerId IS the Firebase UID
      console.log(`${logPrefix} Using provided userId for IAP: ${userId}`);
      userDocRef = admin.firestore().collection("users").doc(userId);
      // We'll check existence later during the Firestore update/fetch
    } else {
      console.error(`${logPrefix} ERROR: Invalid platform provided.`);
      return null;
    }

    // --- Step 2: Determine Target Role ---
    const targetRole = (status === "active" || status === "trialing") ? "pro" : "free";
    console.log(`${logPrefix} Determined targetRole: '${targetRole}' based on status '${status}'.`);

    // --- Step 3: Update Firestore ---
    const roleField = platform === "stripe" ? "stripeRole" : "iapRole";
    console.log(`${logPrefix} Will update Firestore field: '${roleField}'.`);
    const updatePayload = {};
    updatePayload[roleField] = targetRole;
    updatePayload[`${platform}RoleUpdatedAt`] = admin.firestore.FieldValue.serverTimestamp(); // Add timestamp

    try {
      console.log(`${logPrefix} Attempting Firestore update:`, updatePayload);
      // Use set with merge: true for robustness - creates doc if missing (e.g., race condition) or updates if exists
      await userDocRef.set(updatePayload, { merge: true });
      console.log(`${logPrefix} Firestore update SUCCESSFUL (using set merge).`);
    } catch (firestoreError) {
      console.error(`${logPrefix} ERROR during Firestore update:`, firestoreError);
      // If Firestore fails, we probably shouldn't proceed to claims
      throw firestoreError; // Rethrow to be caught by the outer try/catch
    }

    // --- Step 4: Compute Final isPro Status ---
    console.log(`${logPrefix} Fetching user document AFTER update to compute final isPro status.`);
    const updatedUserDocSnap = await userDocRef.get(); // Fetch the doc we just updated/set
    if (!updatedUserDocSnap.exists) {
        // This should be rare after a successful set/merge, but handle it.
        console.error(`${logPrefix} ERROR: User document ${userId} does not exist even after update attempt.`);
        return null;
    }
    const userData = updatedUserDocSnap.data() || {}; // Use fresh data

    const finalStripeRole = userData.stripeRole || "free";
    const finalIapRole = userData.iapRole || "free";
    const isFounder = userData.isFounder === true || userData.serverCalculatedFounder === true; // Explicit boolean check

    console.log(`${logPrefix} Calculating isPro based on: finalStripeRole='${finalStripeRole}', finalIapRole='${finalIapRole}', isFounder='${isFounder}'`);

    const finalIsPro = (finalStripeRole === "pro") ||
                       (finalIapRole === "pro");

    console.log(`${logPrefix} Calculated finalIsPro = ${finalIsPro}`);

    // --- Step 5: Set Custom Claims ---
    try {
      console.log(`${logPrefix} Getting current custom claims for user ${userId}.`);
      const authUser = await admin.auth().getUser(userId);
      const currentClaims = authUser.customClaims || {};
      console.log(`${logPrefix} Current custom claims:`, currentClaims);

      if (currentClaims && typeof currentClaims.isPro !== 'undefined' && currentClaims.isPro === finalIsPro) {
        console.log(`${logPrefix} Custom claim 'isPro' is already ${finalIsPro}. No update needed.`);
      } else {
        console.log(`${logPrefix} Attempting to set custom claim 'isPro' to ${finalIsPro} (merging with existing).`);
        // **FIX APPLIED HERE:** Merge new claim with existing ones
        await admin.auth().setCustomUserClaims(userId, { ...currentClaims, isPro: finalIsPro });
        console.log(`${logPrefix} Custom claim 'isPro' set SUCCESSFUL.`);
      }
    } catch (claimsError) {
      console.error(`${logPrefix} ERROR setting custom claims:`, claimsError);
      // Log the error but allow the function to finish successfully otherwise
    }

    console.log(`${logPrefix} --- Function END (Success) ---`);
    return updatedUserDocSnap; // Return the updated snapshot

  } catch (error) {
    // Catch errors from finding user, Firestore update, or unexpected issues
    console.error(`${logPrefix} UNEXPECTED ERROR in function execution:`, {
        errorMessage: error.message,
        errorStack: error.stack,
        userIdAttempted: userId || customerId, // Log which ID we were working with
    });
    console.log(`${logPrefix} --- Function END (Failure) ---`);
    return null; // Indicate failure
  }
}




/**
 * Listens for new documents in the 'feedback' collection and sends an email.
 */
exports.sendFeedbackEmail = onDocumentCreated({
  document: "feedback/{feedbackId}",
  secrets: ["GMAIL_EMAIL", "GMAIL_PASSWORD"]
}, async (event) => {
    // --- DEBUG LOGGING START ---
    console.log("DEBUG: --- sendFeedbackEmail FUNCTION START ---");
    console.log("DEBUG: GMAIL_EMAIL access:", typeof process.env.GMAIL_EMAIL !== 'undefined' && process.env.GMAIL_EMAIL !== '' ? "SET and has value" : "NOT SET or empty");
    console.log("DEBUG: GMAIL_PASSWORD access:", typeof process.env.GMAIL_PASSWORD !== 'undefined' && process.env.GMAIL_PASSWORD !== '' ? "SET and has value" : "NOT SET or empty");
    console.log("DEBUG: All available environment variables (CAUTION: review sensitive info in logs):", process.env);
    console.log("DEBUG: Input data for sendFeedbackEmail:", event.data.data()); // Log input document data
    // --- DEBUG LOGGING END ---

    const snap = event.data;
    const nodemailer = require("nodemailer"); // Moved require inside

    const gmailEmail = process.env.GMAIL_EMAIL;
    const gmailPassword = process.env.GMAIL_PASSWORD;

    if (!gmailEmail || !gmailPassword) {
        console.error("DEBUG: GMAIL_EMAIL or GMAIL_PASSWORD secret is not set for sendFeedbackEmail.");
        return;
    }

    const mailTransport = nodemailer.createTransport({
        service: "gmail",
        auth: {
            user: gmailEmail,
            pass: gmailPassword,
        },
    });

    const feedbackData = snap.data();

    const mailOptions = {
        from: `"Student Suite Feedback" <${gmailEmail}>`,
        to: ADMIN_EMAIL,
        subject: `New Feedback [${feedbackData.category}] from ${feedbackData.displayName}`,
        html: `
            <h1>New Feedback Received</h1>
            <p><b>From:</b> ${feedbackData.displayName} (${feedbackData.email})</p>
            <p><b>User ID:</b> ${feedbackData.userId}</p>
            <p><b>Category:</b> ${feedbackData.category}</p>
            <p><b>Platform:</b> ${feedbackData.platform}</p>
            <p><b>App Version:</b> ${feedbackData.version}</p>
            <hr>
            <h2>Message:</h2>
            <p>${feedbackData.message.replace(/\n/g, "<br>")}</p>
        `,
    };

    try {
        console.log("DEBUG: Attempting to send feedback email.");
        await mailTransport.sendMail(mailOptions);
        console.log("DEBUG: Feedback email sent successfully for:", event.params.feedbackId);
    } catch (error) {
        console.error("DEBUG: There was an error while sending the feedback email:", error);
    }
    console.log("DEBUG: --- sendFeedbackEmail FUNCTION END ---");
});

/**
 * A new Cloud Function to handle user-initiated subscription cancellation for Stripe.
 * Listens for a new document in the 'stripe_commands' subcollection.
 */
exports.cancelStripeSubscription = onDocumentCreated({
  document: "users/{userId}/stripe_commands/{commandId}",
  secrets: ["STRIPE_SECRET_KEY"]
}, async (event) => {
    // --- DEBUG LOGGING START ---
    console.log("DEBUG: --- cancelStripeSubscription FUNCTION START ---");
    console.log("DEBUG: STRIPE_SECRET_KEY access:", typeof process.env.STRIPE_SECRET_KEY !== 'undefined' && process.env.STRIPE_SECRET_KEY !== '' ? "SET and has value" : "NOT SET or empty");
    console.log("DEBUG: All available environment variables (CAUTION: review sensitive info in logs):", process.env);
    console.log("DEBUG: Input data for cancelStripeSubscription:", event.data.data()); // Log input document data
    // --- DEBUG LOGGING END ---

    const snap = event.data;
    const command = snap.data();
    const {userId} = event.params;

    // Read stripe secret from process.env only (gen2-friendly)
    const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
    if (!stripeSecretKey) {
        console.error("DEBUG: STRIPE_SECRET_KEY is not set for cancelStripeSubscription.");
        return;
    }
    const stripe = require("stripe")(stripeSecretKey);

    if (command.command === "cancel_subscription") {
        console.log(`DEBUG: Attempting to cancel Stripe subscription for user: ${userId}`);

        const userDoc = await admin.firestore().collection("users").doc(userId).get();
        const customerId = userDoc.data()?.stripeCustomerId;
        const stripeSubscriptionId = userDoc.data()?.stripeSubscriptionId;

        if (!customerId || !stripeSubscriptionId) {
            console.error(`DEBUG: User ${userId} has no Stripe Customer ID (${customerId}) or Subscription ID (${stripeSubscriptionId}). Cannot cancel.`);
            return null;
        }

        try {
            console.log(`DEBUG: Calling Stripe API to cancel subscription ${stripeSubscriptionId} for customer ${customerId}.`);
            await stripe.subscriptions.cancel(stripeSubscriptionId);
            console.log(`DEBUG: Successfully cancelled Stripe subscription for user: ${userId}`);
        } catch (error) {
            console.error(`DEBUG: Error cancelling Stripe subscription for user ${userId}:`, error);
        }
    }
    return null;
});

/**
 * Cleans up user data from Firestore and Storage when a user is deleted.
 * SAFE VERSION: Matches your existing v1 import style.
 */
exports.onUserDeleted = functions
  .runWith({ secrets: ["STRIPE_SECRET_KEY"] }) // <--- FIX: runWith is required for secrets in v1
  .auth.user()
  .onDelete(async (user) => {
    const userId = user.uid;
    console.log(`DEBUG: [1/5] Starting Cleanup for User: ${userId}`);

    // Initialize Admin if needed
    if (admin.apps.length === 0) {
      admin.initializeApp();
    }

    const db = admin.firestore();
    const storage = admin.storage().bucket();

    // 1. ARCHIVE DATA TO GLOBALS
    try {
      const now = new Date();
      const monthYear = `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, "0")}`;
      
      const userAiRef = db.collection("users").doc(userId).collection("aiUsage").doc(monthYear);
      const userAiSnap = await userAiRef.get();
      let userData = { cost: 0, requests: 0, inputTokens: 0, outputTokens: 0 };
      
      if (userAiSnap.exists) {
          userData = userAiSnap.data();
      }

      const globalMetaRef = db.collection("globals").doc("metadata");
      // Increment Deleted User Count
      await globalMetaRef.set({
          deletedUserCount: admin.firestore.FieldValue.increment(1),
          // Accumulate deleted user usage so it isn't lost from reports
          deletedAiCost: admin.firestore.FieldValue.increment(userData.cost || 0),
          deletedAiRequests: admin.firestore.FieldValue.increment(userData.requests || 0),
      }, { merge: true });

      console.log("DEBUG: [2/5] Globals updated.");
    } catch (e) {
      console.error("ERROR updating globals:", e);
    }

    // 2. STRIPE CANCELLATION
    const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
    if (stripeSecretKey) {
        try {
            const stripe = require("stripe")(stripeSecretKey);
            const userDoc = await db.collection("users").doc(userId).get();
            const subId = userDoc.data()?.stripeSubscriptionId;
            if (subId) {
                await stripe.subscriptions.cancel(subId);
                console.log("DEBUG: [3/5] Stripe subscription cancelled.");
            }
        } catch (e) {
            console.error("DEBUG: Stripe error (ignored):", e.message);
        }
    }

    // 3. RECURSIVE FIRESTORE WIPE
    try {
        await db.recursiveDelete(db.collection("users").doc(userId));
        console.log(`DEBUG: [4/5] Firestore data nuked.`);
    } catch (e) {
        console.error("CRITICAL ERROR during Firestore delete:", e);
    }

    // 4. STORAGE WIPE
    try {
        const profileFile = storage.file(`profile_pics/${userId}/profile.jpg`);
        const [exists] = await profileFile.exists();
        if (exists) await profileFile.delete();
        await storage.deleteFiles({ prefix: `uploads/${userId}/` }).catch(() => {});
        await storage.deleteFiles({ prefix: `user_files/${userId}/` }).catch(() => {});
        console.log("DEBUG: [5/5] Storage cleanup done.");
    } catch (e) {
        console.log("DEBUG: Storage delete info:", e.message);
    }
});

/**
 * A callable function to validate a referral code securely on the server.
 * @param {object} data The data passed to the function.
 * @param {string} data.code The referral code to validate.
 * @returns {Promise<{referrerId: string|null}>} The UID of the referrer or null.
 */
exports.validateReferralCode = onCall(async (request) => {
    // --- DEBUG LOGGING START ---
    console.log("DEBUG: --- validateReferralCode FUNCTION START ---");
    console.log("DEBUG: All available environment variables (CAUTION: review sensitive info in logs):", process.env);
    console.log("DEBUG: Input data for validateReferralCode:", request.data);
    // --- DEBUG LOGGING END ---

    const {data} = request;
    const code = data.code;
    if (!code || typeof code !== "string" || code.length === 0) {
        throw new HttpsError(
            "invalid-argument",
            "The function must be called with a 'code' argument.",
        );
    }

    try { // Added try-catch for the query itself
        const usersRef = admin.firestore().collection("users");
        const snapshot = await usersRef.where("uid_prefix", "==", code.toUpperCase()).limit(1).get();

        if (snapshot.empty) {
            console.log(`DEBUG: Referral code ${code} not found.`);
            return {referrerId: null};
        }
        console.log(`DEBUG: Referral code ${code} found, referrer ID: ${snapshot.docs[0].id}`);
        return {referrerId: snapshot.docs[0].id};
    } catch (error) {
        console.error("DEBUG: Error validating referral code:", error);
        throw new HttpsError(
            "internal",
            "Failed to validate referral code.",
            error,
        );
    } finally {
        console.log("DEBUG: --- validateReferralCode FUNCTION END ---");
    }
});

/**
 * A new callable function to handle referral code redemption logic for IAP.
 * @param {object} data The data passed to the function.
 * @param {string} data.referrerId The UID of the user who referred the new subscriber.
 * @returns {Promise<{success: boolean}>}
 */
exports.rewardReferrer = onCall(async (request) => {
    // --- DEBUG LOGGING START ---
    console.log("DEBUG: --- rewardReferrer FUNCTION START ---");
    console.log("DEBUG: All available environment variables (CAUTION: review sensitive info in logs):", process.env);
    console.log("DEBUG: Input data for rewardReferrer:", request.data);
    // --- DEBUG LOGGING END ---

    const {data} = request;
    if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "The function must be called while authenticated.",
        );
    }
    const userId = request.auth.uid; // This is the new subscriber
    const {referrerId} = data;

    if (!referrerId) {
        throw new HttpsError(
            "invalid-argument",
            "The function must be called with a 'referrerId'.",
        );
    }

    try {
        const referrerDocRef = admin.firestore().collection("users").doc(referrerId);
        const newSubscriberDocRef = admin.firestore().collection("users").doc(userId);

        // Track the referral in Firestore for both users
        await admin.firestore().runTransaction(async (transaction) => {
            const referrerDoc = await transaction.get(referrerDocRef);
            const newSubscriberDoc = await transaction.get(newSubscriberDocRef);

            if (!referrerDoc.exists) {
                console.error(`DEBUG: Referrer ${referrerId} not found.`);
                throw new HttpsError("not-found", "Referrer not found.");
            }

            // Check if this referral has already been processed for this user
            if (newSubscriberDoc.data()?.referralCreditGiven) { // Added null-check for data()
                console.log(`DEBUG: Referral from ${userId} to ${referrerId} already processed.`);
                return; // Exit if already processed
            }

            const referrerData = referrerDoc.data();
            const referralCount = (referrerData?.referralCount || 0) + 1; // Added null-check for data()

            // Update the referrer's document
            transaction.update(referrerDocRef, {
                referralCount: referralCount,
                lastReferralDate: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Update the new subscriber's document
            transaction.update(newSubscriberDocRef, {
                referredBy: referrerId,
                referralCreditGiven: true,
            });

            // TODO: You would now generate a new Offer Code for the referrer
            // or simply track their earned free months. This is a separate
            // integration with the App Store Server API that can be built out
            // here. For now, we are just tracking the count.
            console.log(`DEBUG: Referral from ${userId} to ${referrerId} successfully tracked. New count: ${referralCount}`);
        });

        return {success: true};
    } catch (error) {
        console.error("DEBUG: Error processing IAP referral:", error);
        throw new HttpsError(
            "internal",
            "Failed to process referral.",
        );
    } finally {
        console.log("DEBUG: --- rewardReferrer FUNCTION END ---");
    }
});

/**
 * A new callable function to get a promotional offer signature from Apple.
 * @param {object} data The data passed to the function.
 * @param {string} data.productIdentifier The product ID of the subscription.
 * @param {string} data.offerIdentifier The promotional offer ID.
 * @returns {Promise<{signature: string, nonce: string, timestamp: number, keyId: string}>}
 */
exports.getPromotionalOfferSignature = onCall({ 
  secrets: ["APPLE_IAP_KEY_ID", "APPLE_IAP_ISSUER_ID", "APPLE_IAP_PRIVATE_KEY"] 
}, async (request) => {
    // --- DEBUG LOGGING START ---
    console.log("DEBUG: --- getPromotionalOfferSignature FUNCTION START ---");
    console.log("DEBUG: APPLE_IAP_KEY_ID access:", typeof process.env.APPLE_IAP_KEY_ID !== 'undefined' && process.env.APPLE_IAP_KEY_ID !== '' ? "SET and has value" : "NOT SET or empty");
    console.log("DEBUG: APPLE_IAP_ISSUER_ID access:", typeof process.env.APPLE_IAP_ISSUER_ID !== 'undefined' && process.env.APPLE_IAP_ISSUER_ID !== '' ? "SET and has value" : "NOT SET or empty");
    console.log("DEBUG: APPLE_IAP_PRIVATE_KEY access:", typeof process.env.APPLE_IAP_PRIVATE_KEY !== 'undefined' && process.env.APPLE_IAP_PRIVATE_KEY !== '' ? "SET and has value" : "NOT SET or empty");
    console.log("DEBUG: All available environment variables (CAUTION: review sensitive info in logs):", process.env);
    console.log("DEBUG: Input data for getPromotionalOfferSignature:", request.data);
    // --- DEBUG LOGGING END ---

    const {data} = request;
    if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "The function must be called while authenticated.",
        );
    }
    const userId = request.auth.uid;
    const {productIdentifier, offerIdentifier} = data;

    if (!productIdentifier || !offerIdentifier) {
        throw new HttpsError(
            "invalid-argument",
            "productIdentifier and offerIdentifier must be provided.",
        );
    }

    const appleKeyId = process.env.APPLE_IAP_KEY_ID;
    const appleIssuerId = process.env.APPLE_IAP_ISSUER_ID;
    const applePrivateKey = process.env.APPLE_IAP_PRIVATE_KEY;

    if (!appleKeyId || !appleIssuerId || !applePrivateKey) {
        console.error("DEBUG: Apple IAP secrets missing (Key ID, Issuer ID, or Private Key).");
        throw new HttpsError("internal", "Server configuration error: Apple IAP secrets (Key ID, Issuer ID, or Private Key) missing.");
    }

    const crypto = require("crypto"); // Moved require inside
    // Generate a random nonce and current timestamp for the signature.
    const nonce = crypto.randomBytes(16).toString("hex");
    const timestamp = Date.now();
    console.log(`DEBUG: Generating Apple Promotional Offer Signature for userId: ${userId}`);
    const token = jwt.sign(
        {
            nonce: nonce,
            timestamp: timestamp,
            productIdentifier: productIdentifier,
            offerIdentifier: offerIdentifier,
        },
        applePrivateKey,
        {
            algorithm: "ES256",
            keyid: appleKeyId,
            issuer: appleIssuerId,
        },
    );
    console.log("DEBUG: Apple Promotional Offer Signature generated.");
    return {
        signature: token,
        nonce: nonce,
        timestamp: timestamp,
        keyId: appleKeyId,
    };
});


exports.monthlyReport = onSchedule({
  schedule: "0 9 1 * *",
  region: "us-central1",
  secrets: ["GMAIL_EMAIL", "GMAIL_PASSWORD"]
}, async (event) => {
  const gmailEmail = process.env.GMAIL_EMAIL;
  const gmailPassword = process.env.GMAIL_PASSWORD;
  if (!gmailEmail || !gmailPassword) return;

  const db = admin.firestore();
  const now = new Date();
  const lastMonthDate = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const monthYear = `${lastMonthDate.getFullYear()}-${(lastMonthDate.getMonth() + 1).toString().padStart(2, "0")}`;

  // 1. Get Metadata
  const metadataDoc = await db.collection("globals").doc("metadata").get();
  const meta = metadataDoc.data() || {};
  const totalUsers = meta.userCount || 0;
  const totalDeleted = meta.deletedUserCount || 0;
  const activeUsers = totalUsers - totalDeleted;

  // 2. Get Deleted AI Usage
  const deletedAiDoc = await db.collection("globals").doc("aiUsage").collection("history").doc(monthYear).get();
  const deletedAi = deletedAiDoc.data() || {};

  // 3. Tally Active User Usage
  let totalRequests = deletedAi.deletedUserRequests || 0;
  let totalCost = deletedAi.deletedUserCost || 0;
  let activeAiUsers = 0;

  const usersSnap = await db.collection("users").get();
  for (const doc of usersSnap.docs) {
      const aiSnap = await doc.ref.collection("aiUsage").doc(monthYear).get();
      if (aiSnap.exists) {
          const d = aiSnap.data();
          activeAiUsers++;
          totalRequests += (d.requests || 0);
          totalCost += (d.cost || 0);
      }
  }

  // Email Content
  const mailTransport = require("nodemailer").createTransport({
    service: "gmail",
    auth: { user: gmailEmail, pass: gmailPassword },
  });

  await mailTransport.sendMail({
    from: `"Student Suite Reports" <${gmailEmail}>`,
    to: ADMIN_EMAIL,
    subject: `Report: ${monthYear}`,
    html: `
      <h2>Monthly Report: ${monthYear}</h2>
      <ul>
        <li><b>Total Signups:</b> ${totalUsers}</li>
        <li><b>Deleted Users:</b> ${totalDeleted}</li>
        <li><b>Active Users:</b> ${activeUsers}</li>
        <li><b>Active AI Users:</b> ${activeAiUsers}</li>
      </ul>
      <hr>
      <h3>AI Usage (Active + Deleted)</h3>
      <ul>
        <li><b>Total Requests:</b> ${totalRequests}</li>
        <li><b>Total Cost:</b> $${totalCost.toFixed(4)}</li>
      </ul>
    `
  });
});

/* -------------------------
   _handleGeneration (AI) + endpoints
   ------------------------- */
async function _handleGeneration(request) {
  console.log("DEBUG: --- _handleGeneration (VertexAI) FUNCTION START ---");
  console.log("DEBUG: Input data for _handleGeneration:", request.data);

  if (admin.apps.length === 0) {
    admin.initializeApp();
  }

  if (!request.auth) {
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }

  const userId = request.auth.uid;
  const now = new Date();
  const monthYear = `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, "0")}`;
  const usageDocRef = admin.firestore().collection("users").doc(userId).collection("aiUsage").doc(monthYear);
  const usageDoc = await usageDocRef.get();

  const monthlyCostLimit = 3.0; // Your existing limit

  if (usageDoc.exists) {
    const currentCost = usageDoc.data().cost || 0;
    if (currentCost >= monthlyCostLimit) {
      throw new HttpsError("resource-exhausted", "You have reached your monthly AI usage limit. This will reset on the first of the next month.");
    }
  }

  const prompt = request.data.prompt;
  if (!prompt || typeof prompt !== "string") {
    throw new HttpsError("invalid-argument", "The function must be called with a 'prompt' argument.");
  }

  // Define models and pricing
  const GOOGLE_MODEL_NAME = "gemini-1.0-pro"; // Vertex AI model name
  const OPENAI_MODEL_NAME = "gpt-4o-mini";

  const modelPricing = {
    [GOOGLE_MODEL_NAME]: { input: 0.35 / 1000000, output: 0.70 / 1000000 }, // Check pricing, estimates
    [OPENAI_MODEL_NAME]: { input: 0.15 / 1000000, output: 0.60 / 1000000 },
  };
  
  // Get OpenAI key from secrets
  const openAiApiKey = process.env.OPENAI_API_KEY;

  // --- NEW API CONFIG ---
  // Vertex AI uses your project's built-in credentials (ADC), not API keys.
  // We only need the OpenAI key for the fallback.
  const apiConfigs = [
    { provider: "google-vertex", model: GOOGLE_MODEL_NAME },
  ];
  
  if (openAiApiKey) {
    apiConfigs.push({ provider: "openai", apiKey: openAiApiKey, model: OPENAI_MODEL_NAME });
  } else {
     console.warn("DEBUG: OPENAI_API_KEY not found. Fallback is disabled.");
  }

  if (apiConfigs.length === 0) {
    console.error("DEBUG: No AI API keys or configurations are available.");
    throw new HttpsError("internal", "Server configuration error: No AI providers configured.");
  }

  const errors = [];

  for (const config of apiConfigs) {
    try {
      let responseText = "";
      let usage = { inputTokens: 0, outputTokens: 0 };

      if (config.provider === "google-vertex") {
        // --- NEW VERTEX AI LOGIC ---
        console.log(`DEBUG: Attempting API call with ${config.provider} (${config.model}).`);
        const vertex_ai = new VertexAI({ project: 'student-suite2', location: 'us-east1' });
        
        const generativeModel = vertex_ai.getGenerativeModel({
          model: config.model,
        });

        const req = {
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
        };

        const result = await generativeModel.generateContent(req);
        
        if (!result.response || !result.response.candidates || !result.response.candidates[0]) {
           throw new Error("Invalid response structure from Vertex AI.");
        }
        
        // Extract text
        responseText = result.response.candidates[0].content.parts[0].text;
        
        // Extract usage
        const usageMetadata = result.response.usageMetadata;
        if (usageMetadata) {
          usage.inputTokens = usageMetadata.promptTokenCount || 0;
          usage.outputTokens = usageMetadata.totalTokenCount - usage.inputTokens; // Vertex gives total
        }
        // --- END NEW VERTEX AI LOGIC ---

      } else if (config.provider === "openai") {
        console.log(`DEBUG: Attempting API call with ${config.provider} (${config.model}).`);
        const openaiClient = new OpenAI({ apiKey: config.apiKey });
        const completion = await openaiClient.chat.completions.create({
          messages: [{ role: "user", content: prompt }],
          model: config.model,
        });
        responseText = completion.choices[0]?.message?.content ?? "";
        if (completion.usage) {
          usage.inputTokens = completion.usage.prompt_tokens || 0;
          usage.outputTokens = completion.usage.completion_tokens || 0;
        }
      }

      if (responseText.trim() === "") {
        throw new Error("Model returned an empty response.");
      }

      console.log(`DEBUG: ✅ Success with ${config.provider} (${config.model}).`);

  const pricing = modelPricing[config.model];
      if (pricing) {
        const cost = (usage.inputTokens * pricing.input) + (usage.outputTokens * pricing.output);
        await usageDocRef.set({
          cost: admin.firestore.FieldValue.increment(cost),
          requests: admin.firestore.FieldValue.increment(1),
          inputTokens: admin.firestore.FieldValue.increment(usage.inputTokens),
          outputTokens: admin.firestore.FieldValue.increment(usage.outputTokens),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        console.log(`DEBUG: AI usage recorded for user ${userId}. Cost: ${cost.toFixed(4)}`);
      }

      return { text: responseText };
    } catch (error) {
      const errorMessage = `DEBUG: 🚨 API call with ${config.provider} (${config.model}) failed: ${error.message}`;
      console.error(errorMessage);
      errors.push(errorMessage);
    }
  }

  console.error("DEBUG: All AI API calls failed. Errors:", errors);
  throw new HttpsError("unavailable", "The AI service is currently unavailable after multiple attempts. Please try again later.");
}

const aiSecrets = ["GOOGLE_API_KEY1", "GOOGLE_API_KEY2", "GOOGLE_API_KEY3", "OPENAI_API_KEY"];
exports.generateStudyNote = onCall({ secrets: aiSecrets }, _handleGeneration);
exports.generateFlashcards = onCall({ secrets: aiSecrets }, _handleGeneration);
exports.generateResume = onCall({ secrets: aiSecrets }, _handleGeneration);
exports.generateCoverLetter = onCall({ secrets: aiSecrets }, _handleGeneration);
exports.getTeacherResponse = onCall({ secrets: aiSecrets }, _handleGeneration);
exports.getInterviewerResponse = onCall({ secrets: aiSecrets }, _handleGeneration);
exports.getInterviewFeedback = onCall({ secrets: aiSecrets }, _handleGeneration);


/* -------------------------
   onUserCreate - auth.user().onCreate
   ------------------------- */
// This function triggers when a user is CREATED IN AUTH, and then
// it creates the corresponding document in FIRESTORE.
/* -------------------------
   onUserCreated - Fixed to prevent overwriting Client Data
   ------------------------- */
exports.onUserCreated = auth.user().onCreate(async (user) => {
  console.log("DEBUG: --- onUserCreated (Auth) FUNCTION START ---");
  const db = admin.firestore();
  const userDocRef = db.collection("users").doc(user.uid);
  const metadataRef = db.collection("globals").doc("metadata");

  try {
    await db.runTransaction(async (transaction) => {
      const metadataDoc = await transaction.get(metadataRef);
      let userCount = 0;
      if (metadataDoc.exists) {
        userCount = metadataDoc.data()?.userCount || 0;
      }

      // 1. Update Global Count
      transaction.set(metadataRef, { userCount: userCount + 1 }, { merge: true });

      const isFirst1000 = userCount < 1000;

      // 2. Create/Merge User Doc
      // CRITICAL FIX: We use { merge: true } and DO NOT set stripeRole/iapRole here.
      // This ensures we don't overwrite the "founder_discount" role set by the Flutter app.
      transaction.set(userDocRef, {
        email: user.email || null,
        displayName: user.displayName || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        // We only set isFounder if the client didn't already set it (server-side fallback)
        // logic: if < 1000, they are a founder.
        isFounder: isFirst1000,
        serverCalculatedFounder: isFirst1000,
        iapRole: 'free', // Default role
      }, { merge: true });
    });
    console.log(`DEBUG: User document ${user.uid} processed safely.`);
  } catch (e) {
    console.error("DEBUG: onUserCreated transaction failed: ", e);
  }
});
console.log("DEBUG: index.js loaded successfully at", new Date().toISOString());
