const { onMessagePublished } = require("firebase-functions/v2/pubsub");
const admin = require("firebase-admin");

admin.initializeApp({
  databaseURL: process.env.FIREBASE_DATABASE_URL || "https://heckle-golf-sim-default-rtdb.firebaseio.com"
});

const PAUSE_MESSAGE =
  "Multiplayer is temporarily paused for the remainder of the month as the developer's monthly budget has been reached, sorry for the inconvenience.";

// Triggered by Google Cloud Billing Budget notifications on Pub/Sub topic "budget-alerts"
// Default hard cutoff is $9.50 (50c buffer below the $10.00 monthly credit so in-flight requests never exceed $10.00)
const HARD_CAP_USD = parseFloat(process.env.MONTHLY_BUDGET_CAP_USD || "9.50");

exports.enforceBudgetCap = onMessagePublished("budget-alerts", async (event) => {
  const data = event.data.message.json || {};
  const costAmount = parseFloat(data.costAmount || 0);
  const budgetAmount = parseFloat(data.budgetAmount || 10.0);
  const periodStart = data.costIntervalStart || new Date().toISOString().slice(0, 7);

  const db = admin.firestore();
  const rtdb = admin.database();
  const statusRef = db.doc("system/status");
  const currentSnap = await statusRef.get();
  const current = currentSnap.exists ? currentSnap.data() : { paused: false };

  if (costAmount >= HARD_CAP_USD || costAmount >= budgetAmount) {
    if (!current.paused) {
      const payload = {
        schema_version: 1,
        paused: true,
        reason: "monthly_budget_reached",
        paused_month: String(periodStart).slice(0, 7),
        cost_usd: costAmount,
        budget_usd: budgetAmount,
        updated_at: Math.floor(Date.now() / 1000),
        message: PAUSE_MESSAGE,
      };
      await Promise.all([
        statusRef.set(payload, { merge: true }),
        rtdb.ref("system/status").set(payload),
      ]);
      console.warn(`[BudgetGuard] Monthly spend ($${costAmount}) reached cap ($${HARD_CAP_USD}). Multiplayer PAUSED.`);
    }
  } else if (costAmount < 1.0 && current.paused && current.reason === "monthly_budget_reached") {
    // New billing month started (cost reset near $0) -> automatically unpause!
    const payload = {
      schema_version: 1,
      paused: false,
      reason: "",
      paused_month: "",
      cost_usd: costAmount,
      budget_usd: budgetAmount,
      updated_at: Math.floor(Date.now() / 1000),
      message: PAUSE_MESSAGE,
    };
    await Promise.all([
      statusRef.set(payload, { merge: true }),
      rtdb.ref("system/status").set(payload),
    ]);
    console.info(`[BudgetGuard] New billing cycle detected ($${costAmount}). Multiplayer RESUMED.`);
  }
});
