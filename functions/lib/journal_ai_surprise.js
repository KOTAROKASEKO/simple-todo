"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.deliverRandomJournalAiFeedback = exports.onJournalEntryAiRequestedQueueAi = exports.onJournalEntryCreatedQueueAi = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions/v1"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firebase_functions_1 = require("firebase-functions");
const journal_character_voice_1 = require("./journal_character_voice");
const journal_reflection_ai_1 = require("./journal_reflection_ai");
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
];
function pickRandomSurpriseDelayMs() {
    const i = Math.floor(Math.random() * SURPRISE_DELAY_MS_CHOICES.length);
    return SURPRISE_DELAY_MS_CHOICES[i];
}
/**
 * Legacy create trigger remains deployed but intentionally no-ops; AI requests are
 * queued by the update trigger below. Uses Firestore v1 trigger (not Eventarc) to
 * avoid first-time Eventarc Service Agent permission errors on deploy.
 */
exports.onJournalEntryCreatedQueueAi = functions
    .region("us-central1")
    .runWith({ memory: "256MB" })
    .firestore.document("todo/{userId}/journal_entries/{entryId}")
    .onCreate(async () => {
    return;
});
/**
 * On update: queue exactly one AI reply when user makes a new explicit request.
 *
 * A request is identified by `journalAiReplyRequestedAt` timestamp changing.
 */
exports.onJournalEntryAiRequestedQueueAi = functions
    .region("us-central1")
    .runWith({ memory: "256MB" })
    .firestore.document("todo/{userId}/journal_entries/{entryId}")
    .onUpdate(async (change, context) => {
    const before = change.before.data() ?? {};
    const after = change.after.data() ?? {};
    const userId = context.params.userId;
    const entryId = context.params.entryId;
    const requestedAtBefore = before.journalAiReplyRequestedAt;
    const requestedAtAfter = after.journalAiReplyRequestedAt;
    const requestChanged = requestedAtAfter != null &&
        (requestedAtBefore == null ||
            requestedAtBefore.toMillis?.() !== requestedAtAfter.toMillis?.());
    if (!requestChanged) {
        return;
    }
    const content = (after.content ?? "").toString().trim();
    if (!content) {
        return;
    }
    const delayMs = pickRandomSurpriseDelayMs();
    const deliverAfter = admin.firestore.Timestamp.fromMillis(Date.now() + delayMs);
    await admin.firestore().collection(PENDING_COLLECTION).add({
        userId,
        entryId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        deliverAfter,
        requestedAt: requestedAtAfter,
    });
    firebase_functions_1.logger.info("Journal AI queued from explicit request", {
        userId,
        entryId,
        delayMinutes: Math.round(delayMs / 60000),
    });
});
/**
 * Delivers at most one pending entry whose deliverAfter time has passed.
 * Runs every 10 minutes so surprise delays stay unpredictable but still timely.
 */
exports.deliverRandomJournalAiFeedback = (0, scheduler_1.onSchedule)({
    schedule: "every 10 minutes",
    region: "us-central1",
    timeZone: "UTC",
    memory: "512MiB",
    timeoutSeconds: 120,
}, async () => {
    const toRecentHistory = (raw) => {
        if (!Array.isArray(raw))
            return [];
        const out = [];
        for (const row of raw) {
            if (typeof row !== "object" || row == null)
                continue;
            const obj = row;
            const summary = (obj.summary ?? "").toString().trim();
            if (!summary)
                continue;
            const createdAtMillisRaw = obj.createdAtMillis;
            const createdAtMillis = typeof createdAtMillisRaw === "number" &&
                Number.isFinite(createdAtMillisRaw)
                ? createdAtMillisRaw
                : Date.now();
            const categoryRaw = obj.category;
            const category = typeof categoryRaw === "string" && categoryRaw.trim().length > 0
                ? categoryRaw.trim()
                : undefined;
            out.push({ summary, createdAtMillis, category });
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
        candidates = legacySnap.docs.filter((d) => d.get("deliverAfter") == null);
        if (candidates.length === 0) {
            return;
        }
    }
    const pick = candidates[Math.floor(Math.random() * candidates.length)];
    const row = pick.data();
    const userId = row.userId?.trim();
    const entryId = row.entryId?.trim();
    if (!userId || !entryId) {
        await pick.ref.delete();
        return;
    }
    const project = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT;
    if (!project) {
        firebase_functions_1.logger.error("Journal AI: no GCP project id");
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
    const journalPersonalization = typeof pRaw === "string" ? pRaw : "";
    const profileRaw = userData.journalImportantProfile;
    const journalImportantProfile = profileRaw != null && typeof profileRaw === "object"
        ? profileRaw
        : null;
    const characterRaw = userData.journalAiCharacter;
    const journalAiCharacter = typeof characterRaw === "string" && characterRaw.trim().length > 0
        ? characterRaw.trim()
        : "default";
    const greetRaw = userData.journalDailyReminderGreetingName;
    const journalUserNickname = typeof greetRaw === "string" ? greetRaw : "";
    const recentHistory = toRecentHistory(userData.journalRecentConversationHistory);
    let affirmation;
    let advice;
    try {
        const r = await (0, journal_reflection_ai_1.generateJournalReflection)(project, content, category, journalPersonalization, journalImportantProfile, recentHistory, journalAiCharacter, journalUserNickname);
        affirmation = r.affirmation;
        advice = r.advice;
    }
    catch (err) {
        firebase_functions_1.logger.error("Journal AI: generate failed", { userId, entryId, err });
        await pick.ref.delete();
        return;
    }
    await journalRef.set({
        aiReflection: {
            affirmation,
            advice,
            character: journalAiCharacter,
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            deliveredVia: "surprise_notification",
        },
    }, { merge: true });
    const responseText = [affirmation, advice]
        .map((s) => s.trim())
        .filter((s) => s.length > 0)
        .join("\n\n")
        .slice(0, 600);
    const entrySummary = content.slice(0, 180);
    const historySummary = `User: ${entrySummary}\nAI: ${responseText}`;
    const newHistoryItem = {
        summary: historySummary,
        createdAtMillis: Date.now(),
        category: category || undefined,
    };
    const mergedHistory = [newHistoryItem, ...recentHistory]
        .sort((a, b) => b.createdAtMillis - a.createdAtMillis)
        .slice(0, MAX_RECENT_HISTORY_ITEMS);
    await db.collection("todo").doc(userId).set({ journalRecentConversationHistory: mergedHistory }, { merge: true });
    const tokensSnap = await db
        .collection("todo")
        .doc(userId)
        .collection("deviceTokens")
        .get();
    const tokens = tokensSnap.docs
        .map((d) => d.get("token"))
        .filter((t) => typeof t === "string" && t.length > 0);
    if (tokens.length > 0) {
        const snippet = affirmation.length > 0
            ? affirmation.length > 140
                ? `${affirmation.slice(0, 140)}…`
                : affirmation
            : advice.length > 140
                ? `${advice.slice(0, 140)}…`
                : advice;
        const lead = (0, journal_character_voice_1.journalSurpriseNotificationLead)(journalAiCharacter, journalUserNickname);
        const notifTitle = (0, journal_character_voice_1.journalSurpriseNotificationTitle)(journalAiCharacter);
        const bodyCore = [lead, snippet || "開いてみてね"]
            .map((s) => s.trim())
            .filter((s) => s.length > 0)
            .join("\n\n");
        const body = bodyCore.length > 320 ? `${bodyCore.slice(0, 317)}…` : bodyCore;
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
        const invalidTokens = [];
        sendResult.responses.forEach((response, index) => {
            if (response.success)
                return;
            const code = response.error?.code ?? "";
            if (code === "messaging/registration-token-not-registered" ||
                code === "messaging/invalid-registration-token") {
                invalidTokens.push(tokens[index]);
            }
        });
        if (invalidTokens.length > 0) {
            const userRef = db.collection("todo").doc(userId);
            await Promise.all(invalidTokens.map((token) => userRef.collection("deviceTokens").doc(token).delete()));
        }
    }
    await pick.ref.delete();
    firebase_functions_1.logger.info("Journal AI delivered", { userId, entryId });
});
