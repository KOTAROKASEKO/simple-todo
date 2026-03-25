import * as admin from "firebase-admin";
import {logger} from "firebase-functions";
import {onSchedule} from "firebase-functions/v2/scheduler";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

type TaskDoc = {
  title?: string;
  isRecurringDaily?: boolean;
  remindAt?: FirebaseFirestore.Timestamp;
};

export const sendDueTaskReminders = onSchedule(
  {
    schedule: "every 1 minutes",
    region: "us-central1",
    timeZone: "UTC",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const dueTasks = await db
      .collectionGroup("tasks")
      .where("reminderPending", "==", true)
      .where("remindAt", "<=", now)
      .limit(200)
      .get();

    if (dueTasks.empty) {
      logger.info("No due reminders");
      return;
    }

    for (const doc of dueTasks.docs) {
      const data = doc.data() as TaskDoc;
      const taskRef = doc.ref;
      const userDocRef = taskRef.parent.parent;
      if (!userDocRef) {
        logger.warn("Task has no user parent", {taskPath: taskRef.path});
        continue;
      }

      const tokensSnapshot = await userDocRef.collection("deviceTokens").get();
      const tokens = tokensSnapshot.docs
        .map((d) => d.get("token"))
        .filter((t): t is string => typeof t === "string" && t.length > 0);

      if (tokens.length === 0) {
        logger.info("No tokens for due reminder", {
          taskPath: taskRef.path,
          uid: userDocRef.id,
        });
        continue;
      }

      const title = data.title ?? "Task";
      const sendResult = await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: "Task Reminder",
          body: title,
        },
        data: {
          taskPath: taskRef.path,
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
            userDocRef.collection("deviceTokens").doc(token).delete(),
          ),
        );
      }

      if (data.isRecurringDaily === true) {
        const prev = data.remindAt?.toDate() ?? new Date();
        const next = new Date(prev);
        next.setUTCDate(next.getUTCDate() + 1);
        await taskRef.set(
          {
            remindAt: admin.firestore.Timestamp.fromDate(next),
            reminderPending: true,
            reminderLastSentAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      } else {
        await taskRef.set(
          {
            reminderPending: false,
            reminderLastSentAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
      }
    }

    logger.info("Processed due reminders", {count: dueTasks.size});
  },
);

/** Notification settings stored at dailyCheckSettings/{uid} */
type DailyCheckSettingsDoc = {
  reminderHours?: number[];
  timeZoneOffsetMinutes?: number;
};

/**
 * Scheduled every 15 minutes. Sends "Check your tasks" FCM to users whose
 * local time is in one of their reminder hours (first 15 min of that hour).
 */
export const sendDailyCheckReminders = onSchedule(
  {
    schedule: "every 15 minutes",
    region: "us-central1",
    timeZone: "UTC",
  },
  async () => {
    const settingsSnap = await db.collection("dailyCheckSettings").get();
    if (settingsSnap.empty) {
      logger.info("No notification settings for daily check");
      return;
    }

    const now = new Date();
    const utcMinutesSinceMidnight =
      now.getUTCHours() * 60 + now.getUTCMinutes();

    for (const doc of settingsSnap.docs) {
      const data = doc.data() as DailyCheckSettingsDoc;
      const reminderHours = data.reminderHours;
      if (
        !Array.isArray(reminderHours) ||
        reminderHours.length === 0
      ) {
        continue;
      }

      const offsetMin = data.timeZoneOffsetMinutes ?? 0;
      let localMinutes =
        utcMinutesSinceMidnight + offsetMin;
      localMinutes = ((localMinutes % (24 * 60)) + 24 * 60) % (24 * 60);
      const localHour = Math.floor(localMinutes / 60);
      const minuteInHour = localMinutes % 60;

      if (minuteInHour >= 20) continue;
      if (!reminderHours.includes(localHour)) continue;

      const uid = doc.id;
      const userDocRef = db.collection("todo").doc(uid);

      const tokensSnap = await userDocRef.collection("deviceTokens").get();
      const tokens = tokensSnap.docs
        .map((d) => d.get("token"))
        .filter((t): t is string => typeof t === "string" && t.length > 0);

      if (tokens.length === 0) {
        logger.info("Daily check: no tokens", {uid});
        continue;
      }

      logger.info("Daily check: sending", {
        uid,
        tokenCount: tokens.length,
        localHour,
        minuteInHour,
      });

      try {
        const sendResult = await messaging.sendEachForMulticast({
          tokens,
          notification: {
            title: "Check your tasks",
            body: "Take a moment to review your todo list.",
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
              userDocRef.collection("deviceTokens").doc(token).delete(),
            ),
          );
        }
        logger.info("Daily check: sent", {uid});
      } catch (err) {
        logger.warn("Failed to send daily check reminder", {
          uid: userDocRef.id,
          error: err,
        });
      }
    }

    logger.info("Processed daily check reminders", {
      settingsCount: settingsSnap.size,
    });
  },
);
