import * as admin from "firebase-admin";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {journalDailyReminderCopy} from "./journal_character_voice";

const db = admin.firestore();
const messaging = admin.messaging();

/** Local wall-clock hour (0–23) to nudge diary writing — 20 = 8 PM. */
const JOURNAL_REMINDER_LOCAL_HOUR = 20;
/** Only fire in the first N minutes of that hour (same idea as daily task check). */
const JOURNAL_REMINDER_MINUTE_WINDOW = 20;

export {journalDailyReminderCopy} from "./journal_character_voice";

function localYmdKey(now: Date, offsetMinutes: number): string {
  const shiftedMs = now.getTime() + offsetMinutes * 60_000;
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
export const sendJournalDailyReminders = onSchedule(
  {
    schedule: "every 15 minutes",
    region: "us-central1",
    timeZone: "UTC",
  },
  async () => {
    const now = new Date();
    const utcMinutesSinceMidnight =
      now.getUTCHours() * 60 + now.getUTCMinutes();

    const snap = await db
      .collection("todo")
      .where("journalDailyReminderEnabled", "==", true)
      .get();

    if (snap.empty) {
      logger.info("Journal daily reminder: no enabled users");
      return;
    }

    for (const doc of snap.docs) {
      const uid = doc.id;
      const data = doc.data();
      const offsetMin =
        typeof data.journalDailyReminderTimeZoneOffsetMinutes === "number"
          ? data.journalDailyReminderTimeZoneOffsetMinutes
          : 0;

      let localMinutes = utcMinutesSinceMidnight + offsetMin;
      localMinutes = ((localMinutes % (24 * 60)) + 24 * 60) % (24 * 60);
      const localHour = Math.floor(localMinutes / 60);
      const minuteInHour = localMinutes % 60;

      if (localHour !== JOURNAL_REMINDER_LOCAL_HOUR) continue;
      if (minuteInHour >= JOURNAL_REMINDER_MINUTE_WINDOW) continue;

      const todayKey = localYmdKey(now, offsetMin);
      const lastSent = (data.journalDailyReminderLastSentDayKey ?? "")
        .toString()
        .trim();
      if (lastSent === todayKey) continue;

      const characterId =
        typeof data.journalAiCharacter === "string"
          ? data.journalAiCharacter.trim()
          : "default";
      const greetingName =
        typeof data.journalDailyReminderGreetingName === "string"
          ? data.journalDailyReminderGreetingName
          : "";

      const tokensSnap = await doc.ref.collection("deviceTokens").get();
      const tokens = tokensSnap.docs
        .map((d) => d.get("token"))
        .filter((t): t is string => typeof t === "string" && t.length > 0);

      if (tokens.length === 0) {
        logger.info("Journal daily reminder: no tokens", {uid});
        continue;
      }

      const copy = journalDailyReminderCopy(characterId, greetingName);

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
          await Promise.all(
            invalidTokens.map((token) =>
              doc.ref.collection("deviceTokens").doc(token).delete(),
            ),
          );
        }

        await doc.ref.set(
          {journalDailyReminderLastSentDayKey: todayKey},
          {merge: true},
        );

        logger.info("Journal daily reminder: sent", {uid, characterId});
      } catch (err) {
        logger.warn("Journal daily reminder: send failed", {uid, err});
      }
    }

    logger.info("Journal daily reminder: scan done", {enabledCount: snap.size});
  },
);
