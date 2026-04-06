import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions";
import {generateJournalReflection} from "./journal_reflection_ai";

/**
 * Journal “surprise” AI comments — product rules:
 *
 * 1. **Often no comment** — On each new journal post (when the user allows AI), we roll
 *    once. Most posts are never queued, so there is no AI comment for that entry.
 * 2. **When chosen** — We queue the entry; the comment is generated and delivered only
 *    after **exactly one** of **30, 60, or 120 minutes** from post time (picked at
 *    random). The scheduler may add up to ~10 minutes slack before the job runs.
 */

/** Server-only queue for “surprise” journal AI feedback (unpredictable timing). */
const PENDING_COLLECTION = "journal_ai_pending";

/** Chance (0–1) this post gets any AI comment at all; rest get none. */
const JOURNAL_AI_PICKUP_PROBABILITY = 0.35;

/** If picked, delay from post time until we generate & deliver (one of these, uniform). */
const DELAY_MS_CHOICES = [
  30 * 60 * 1000,
  60 * 60 * 1000,
  2 * 60 * 60 * 1000,
] as const;

/**
 * On create: maybe queue for later AI; if queued, deliverAfter is post time + 30m|60m|120m.
 *
 * Uses Firestore v1 trigger (not Eventarc) to avoid first-time Eventarc Service Agent
 * permission errors on deploy.
 */
export const onJournalEntryCreatedQueueAi = functions
  .region("us-central1")
  .runWith({memory: "256MB"})
  .firestore.document("todo/{userId}/journal_entries/{entryId}")
  .onCreate(async (snap, context) => {
    const userId = context.params.userId;
    const entryId = context.params.entryId;
    const data = snap.data();
    const content = (data?.content ?? "").toString().trim();
    if (!content) {
      return;
    }
    const existing = data?.aiReflection;
    if (existing != null && typeof existing === "object") {
      return;
    }

    const aiRequested = data?.journalAiFeedbackRequested;
    if (aiRequested === false) {
      logger.info("Journal AI skipped (user opted out)", {userId, entryId});
      return;
    }

    if (Math.random() >= JOURNAL_AI_PICKUP_PROBABILITY) {
      logger.info("Journal AI: not picked this time (random)", {userId, entryId});
      return;
    }

    const delayMs =
      DELAY_MS_CHOICES[Math.floor(Math.random() * DELAY_MS_CHOICES.length)];
    const deliverAfter = admin.firestore.Timestamp.fromMillis(
      Date.now() + delayMs,
    );

    await admin.firestore().collection(PENDING_COLLECTION).add({
      userId,
      entryId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      deliverAfter,
    });
    logger.info("Journal AI queued", {
      userId,
      entryId,
      delayMinutes: Math.round(delayMs / 60000),
    });
  });

/**
 * Delivers at most one pending entry whose deliverAfter time has passed.
 * Runs often enough to hit ~30m / 1h / 2h windows without large drift.
 */
export const deliverRandomJournalAiFeedback = onSchedule(
  {
    schedule: "every 10 minutes",
    region: "us-central1",
    timeZone: "UTC",
    memory: "512MiB",
    timeoutSeconds: 120,
  },
  async () => {
    const db = admin.firestore();
    const messaging = admin.messaging();
    const now = admin.firestore.Timestamp.now();

    const dueSnap = await db
      .collection(PENDING_COLLECTION)
      .where("deliverAfter", "<=", now)
      .orderBy("deliverAfter", "asc")
      .limit(50)
      .get();

    let candidates = dueSnap.docs;

    // Pre-migration rows had no deliverAfter — drain them as “due now”.
    if (candidates.length === 0) {
      const legacySnap = await db
        .collection(PENDING_COLLECTION)
        .orderBy("createdAt", "asc")
        .limit(40)
        .get();
      candidates = legacySnap.docs.filter(
        (d) => d.get("deliverAfter") == null,
      );
      if (candidates.length === 0) {
        return;
      }
    }

    const pick =
      candidates[Math.floor(Math.random() * candidates.length)];
    const row = pick.data() as {userId?: string; entryId?: string};
    const userId = row.userId?.trim();
    const entryId = row.entryId?.trim();
    if (!userId || !entryId) {
      await pick.ref.delete();
      return;
    }

    const project = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT;
    if (!project) {
      logger.error("Journal AI: no GCP project id");
      return;
    }

    const journalRef = db
      .collection("todo")
      .doc(userId)
      .collection("journal_entries")
      .doc(entryId);

    const journalSnap = await journalRef.get();
    if (!journalSnap.exists) {
      await pick.ref.delete();
      return;
    }

    const j = journalSnap.data() ?? {};
    if (j.aiReflection != null && typeof j.aiReflection === "object") {
      await pick.ref.delete();
      return;
    }

    let content = (j.content ?? "").toString().trim();
    if (!content) {
      await pick.ref.delete();
      return;
    }
    const maxChars = 32000;
    if (content.length > maxChars) {
      content = content.slice(0, maxChars);
    }
    const category = (j.category ?? "").toString().trim();

    const userSnap = await db.collection("todo").doc(userId).get();
    const userData = userSnap.data() ?? {};
    const pRaw = userData.journalPersonalization;
    const journalPersonalization =
      typeof pRaw === "string" ? pRaw : "";

    let affirmation: string;
    let advice: string;
    try {
      const r = await generateJournalReflection(
        project,
        content,
        category,
        journalPersonalization,
      );
      affirmation = r.affirmation;
      advice = r.advice;
    } catch (err) {
      logger.error("Journal AI: generate failed", {userId, entryId, err});
      await pick.ref.delete();
      return;
    }

    await journalRef.set(
      {
        aiReflection: {
          affirmation,
          advice,
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          deliveredVia: "surprise_notification",
        },
      },
      {merge: true},
    );

    const tokensSnap = await db
      .collection("todo")
      .doc(userId)
      .collection("deviceTokens")
      .get();
    const tokens = tokensSnap.docs
      .map((d) => d.get("token"))
      .filter((t): t is string => typeof t === "string" && t.length > 0);

    if (tokens.length > 0) {
      const snippet =
        affirmation.length > 0
          ? affirmation.length > 140
            ? `${affirmation.slice(0, 140)}…`
            : affirmation
          : advice.length > 140
            ? `${advice.slice(0, 140)}…`
            : advice;

      const sendResult = await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: "ジャーナルにひとこと",
          body: snippet || "開いてみてね",
        },
        data: {
          type: "journal_ai_feedback",
          entryId,
        },
      });

      const invalidTokens: string[] = [];
      sendResult.responses.forEach((response, index) => {
        if (response.success) return;
        const code = response.error?.code ?? "";
        if (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
        ) {
          invalidTokens.push(tokens[index]);
        }
      });

      if (invalidTokens.length > 0) {
        const userRef = db.collection("todo").doc(userId);
        await Promise.all(
          invalidTokens.map((token) =>
            userRef.collection("deviceTokens").doc(token).delete(),
          ),
        );
      }
    }

    await pick.ref.delete();
    logger.info("Journal AI delivered", {userId, entryId});
  },
);
