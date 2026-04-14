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
exports.sendJournalDailyReminders = exports.journalDailyReminderCopy = void 0;
const admin = __importStar(require("firebase-admin"));
const firebase_functions_1 = require("firebase-functions");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const journal_character_voice_1 = require("./journal_character_voice");
const db = admin.firestore();
const messaging = admin.messaging();
/** Local wall-clock hour (0–23) to nudge diary writing — 20 = 8 PM. */
const JOURNAL_REMINDER_LOCAL_HOUR = 20;
/** Only fire in the first N minutes of that hour (same idea as daily task check). */
const JOURNAL_REMINDER_MINUTE_WINDOW = 20;
var journal_character_voice_2 = require("./journal_character_voice");
Object.defineProperty(exports, "journalDailyReminderCopy", { enumerable: true, get: function () { return journal_character_voice_2.journalDailyReminderCopy; } });
function localYmdKey(now, offsetMinutes) {
    const shiftedMs = now.getTime() + offsetMinutes * 60000;
    const s = new Date(shiftedMs);
    const y = s.getUTCFullYear();
    const m = String(s.getUTCMonth() + 1).padStart(2, "0");
    const d = String(s.getUTCDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
}
/**
 * Every 15 minutes: users with `journalDailyReminderEnabled` get one FCM per local day
 * at 8 PM (their saved offset), with title/body matching `journalAiCharacter`.
 */
exports.sendJournalDailyReminders = (0, scheduler_1.onSchedule)({
    schedule: "every 15 minutes",
    region: "us-central1",
    timeZone: "UTC",
}, async () => {
    const now = new Date();
    const utcMinutesSinceMidnight = now.getUTCHours() * 60 + now.getUTCMinutes();
    const snap = await db
        .collection("todo")
        .where("journalDailyReminderEnabled", "==", true)
        .get();
    if (snap.empty) {
        firebase_functions_1.logger.info("Journal daily reminder: no enabled users");
        return;
    }
    for (const doc of snap.docs) {
        const uid = doc.id;
        const data = doc.data();
        const offsetMin = typeof data.journalDailyReminderTimeZoneOffsetMinutes === "number"
            ? data.journalDailyReminderTimeZoneOffsetMinutes
            : 0;
        let localMinutes = utcMinutesSinceMidnight + offsetMin;
        localMinutes = ((localMinutes % (24 * 60)) + 24 * 60) % (24 * 60);
        const localHour = Math.floor(localMinutes / 60);
        const minuteInHour = localMinutes % 60;
        if (localHour !== JOURNAL_REMINDER_LOCAL_HOUR)
            continue;
        if (minuteInHour >= JOURNAL_REMINDER_MINUTE_WINDOW)
            continue;
        const todayKey = localYmdKey(now, offsetMin);
        const lastSent = (data.journalDailyReminderLastSentDayKey ?? "")
            .toString()
            .trim();
        if (lastSent === todayKey)
            continue;
        const characterId = typeof data.journalAiCharacter === "string"
            ? data.journalAiCharacter.trim()
            : "default";
        const greetingName = typeof data.journalDailyReminderGreetingName === "string"
            ? data.journalDailyReminderGreetingName
            : "";
        const tokensSnap = await doc.ref.collection("deviceTokens").get();
        const tokens = tokensSnap.docs
            .map((d) => d.get("token"))
            .filter((t) => typeof t === "string" && t.length > 0);
        if (tokens.length === 0) {
            firebase_functions_1.logger.info("Journal daily reminder: no tokens", { uid });
            continue;
        }
        const copy = (0, journal_character_voice_1.journalDailyReminderCopy)(characterId, greetingName);
        try {
            const sendResult = await messaging.sendEachForMulticast({
                tokens,
                notification: {
                    title: copy.title,
                    body: copy.body,
                },
                data: {
                    type: "journal_daily_reminder",
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
                await Promise.all(invalidTokens.map((token) => doc.ref.collection("deviceTokens").doc(token).delete()));
            }
            await doc.ref.set({ journalDailyReminderLastSentDayKey: todayKey }, { merge: true });
            firebase_functions_1.logger.info("Journal daily reminder: sent", { uid, characterId });
        }
        catch (err) {
            firebase_functions_1.logger.warn("Journal daily reminder: send failed", { uid, err });
        }
    }
    firebase_functions_1.logger.info("Journal daily reminder: scan done", { enabledCount: snap.size });
});
