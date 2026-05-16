import * as admin from "firebase-admin";
import * as functions from "firebase-functions/v1";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions";
import {
  journalSurpriseNotificationLead,
  journalSurpriseNotificationTitle,
} from "./journal_character_voice";
import {
  generateJournalReflection,
  JournalRecentHistoryItem,
} from "./journal_reflection_ai";

/**
 * Journal AI replies are opt-in per entry from app long-press actions.
 * Delivery timing is chosen server-side so the notification feels like a surprise.
 */

/** Server-only queue for “surprise” journal AI feedback (unpredictable timing). */
const PENDING_COLLECTION = "journal_ai_pending";
const MAX_RECENT_HISTORY_ITEMS = 3;

/** Millisecond delays (server-picked) so users never see a fixed “in X minutes” promise. */
const SURPRISE_DELAY_MS_CHOICES = [
  22 * 60 * 1000,
  30 * 60 * 1000,
  38 * 60 * 1000,
  45 * 60 * 1000,
  55 * 60 * 1000,
  60 * 60 * 1000,
  72 * 60 * 1000,
  85 * 60 * 1000,
  95 * 60 * 1000,
  105 * 60 * 1000,
  120 * 60 * 1000,
] as const;

function pickRandomSurpriseDelayMs(): number {
  const i = Math.floor(Math.random() * SURPRISE_DELAY_MS_CHOICES.length);
  return SURPRISE_DELAY_MS_CHOICES[i]!;
}

/**
 * Legacy create trigger remains deployed but intentionally no-ops; AI requests are
 * queued by the update trigger below. Uses Firestore v1 trigger (not Eventarc) to
 * avoid first-time Eventarc Service Agent permission errors on deploy.
 */
export const onJournalEntryCreatedQueueAi = functions
  .region("us-central1")
  .runWith({memory: "256MB"})
  .firestore.document("todo/{userId}/journal_entries/{entryId}")
  .onCreate(async () => {
    return;
  });

/**
 * On update: queue exactly one AI reply when user makes a new explicit request.
 *
 * A request is identified by `journalAiReplyRequestedAt` timestamp changing.
 */
export const onJournalEntryAiRequestedQueueAi = functions
  .region("us-central1")
  .runWith({memory: "256MB"})
  .firestore.document("todo/{userId}/journal_entries/{entryId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() ?? {};
    const after = change.after.data() ?? {};
    const userId = context.params.userId;
    const entryId = context.params.entryId;

    const requestedAtBefore = before.journalAiReplyRequestedAt;
    const requestedAtAfter = after.journalAiReplyRequestedAt;
    const requestChanged =
      requestedAtAfter != null &&
      (
        requestedAtBefore == null ||
        requestedAtBefore.toMillis?.() !== requestedAtAfter.toMillis?.()
      );
    if (!requestChanged) {
      return;
    }

    const content = (after.content ?? "").toString().trim();
    if (!content) {
      return;
    }

    const delayMs = pickRandomSurpriseDelayMs();

    const deliverAfter = admin.firestore.Timestamp.fromMillis(
      Date.now() + delayMs,
    );

    await admin.firestore().collection(PENDING_COLLECTION).add({
      userId,
      entryId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      deliverAfter,
      requestedAt: requestedAtAfter,
    });
    logger.info("Journal AI queued from explicit request", {
      userId,
      entryId,
      delayMinutes: Math.round(delayMs / 60000),
    });
  });

/**
 * Delivers at most one pending entry whose deliverAfter time has passed.
 * Runs every 10 minutes so surprise delays stay unpredictable but still timely.
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
    const toRecentHistory = (
      raw: unknown,
    ): JournalRecentHistoryItem[] => {
      if (!Array.isArray(raw)) return [];
      const out: JournalRecentHistoryItem[] = [];
      for (const row of raw) {
        if (typeof row !== "object" || row == null) continue;
        const obj = row as Record<string, unknown>;
        const summary = (obj.summary ?? "").toString().trim();
        if (!summary) continue;
        const createdAtMillisRaw = obj.createdAtMillis;
        const createdAtMillis =
          typeof createdAtMillisRaw === "number" &&
          Number.isFinite(createdAtMillisRaw)
            ? createdAtMillisRaw
            : Date.now();
        const categoryRaw = obj.category;
        const category =
          typeof categoryRaw === "string" && categoryRaw.trim().length > 0
            ? categoryRaw.trim()
            : undefined;
        out.push({summary, createdAtMillis, category});
      }
      out.sort((a, b) => b.createdAtMillis - a.createdAtMillis);
      return out.slice(0, MAX_RECENT_HISTORY_ITEMS);
    };

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
    const profileRaw = userData.journalImportantProfile;
    const journalImportantProfile =
      profileRaw != null && typeof profileRaw === "object"
        ? (profileRaw as Record<string, unknown>)
        : null;
    const characterRaw = userData.journalAiCharacter;
    const journalAiCharacter =
      typeof characterRaw === "string" && characterRaw.trim().length > 0
        ? characterRaw.trim()
        : "default";
    const greetRaw = userData.journalDailyReminderGreetingName;
    const journalUserNickname =
      typeof greetRaw === "string" ? greetRaw : "";
    const recentHistory = toRecentHistory(userData.journalRecentConversationHistory);

    let affirmation: string;
    let advice: string;
    try {
      const r = await generateJournalReflection(
        project,
        content,
        category,
        journalPersonalization,
        journalImportantProfile,
        recentHistory,
        journalAiCharacter,
        journalUserNickname,
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
          character: journalAiCharacter,
          generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          deliveredVia: "surprise_notification",
        },
      },
      {merge: true},
    );

    const responseText = [affirmation, advice]
      .map((s) => s.trim())
      .filter((s) => s.length > 0)
      .join("\n\n")
      .slice(0, 600);
    const entrySummary = content.slice(0, 180);
    const historySummary = `User: ${entrySummary}\nAI: ${responseText}`;
    const newHistoryItem: JournalRecentHistoryItem = {
      summary: historySummary,
      createdAtMillis: Date.now(),
      category: category || undefined,
    };
    const mergedHistory = [newHistoryItem, ...recentHistory]
      .sort((a, b) => b.createdAtMillis - a.createdAtMillis)
      .slice(0, MAX_RECENT_HISTORY_ITEMS);
    await db.collection("todo").doc(userId).set(
      {journalRecentConversationHistory: mergedHistory},
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

      const lead = journalSurpriseNotificationLead(
        journalAiCharacter,
        journalUserNickname,
      );
      const notifTitle = journalSurpriseNotificationTitle(journalAiCharacter);
      const bodyCore = [lead, snippet || "開いてみてね"]
        .map((s) => s.trim())
        .filter((s) => s.length > 0)
        .join("\n\n");
      const body =
        bodyCore.length > 320 ? `${bodyCore.slice(0, 317)}…` : bodyCore;

      const sendResult = await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: notifTitle,
          body: body.length > 0 ? body : "開いてみてね",
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
