/**
 * Journal AI character display names + notification phrasing (no LLM).
 */

export type JournalReminderCopy = {title: string; body: string};

/** AI self-names used in prompts and notifications. */
export const JOURNAL_AI_SELF_NAMES: Record<string, string> = {
  default: "Assistant",
  gyaru: "美咲",
  kopitiam_uncle: "Wong",
  chinese_auntie: "Yin",
};

export function journalAiSelfName(characterId: string): string {
  return JOURNAL_AI_SELF_NAMES[characterId] ?? JOURNAL_AI_SELF_NAMES.default;
}

/** 8 PM local “write your diary” push — opens with nickname + character voice. */
export function journalDailyReminderCopy(
  characterId: string,
  greetingName: string,
): JournalReminderCopy {
  const n = greetingName.trim();
  const ai = journalAiSelfName(characterId);

  const templates: Record<string, JournalReminderCopy> = {
    default: {
      title: `Journal · ${ai}`,
      body: n
        ? `${n}, it’s about 8 in the evening — want to jot a few lines? I’m here with you.`
        : `It’s about 8 in the evening — want to jot a few lines in your journal?`,
    },
    gyaru: {
      title: `日記まだ？｜${ai}`,
      body: n
        ? `${n}、聞いて聞いて〜！そろそろジャーナル書こっか。${ai}待ってるね〜💕`
        : `${ai}だよ〜！そろそろジャーナル書こっか。一緒にやろ〜💕`,
    },
    kopitiam_uncle: {
      title: `Journal time · ${ai}`,
      body: n
        ? `${n}, 8pm liao — Wong here. Sit down awhile, write two lines also good, okay?`
        : `${ai} here — 8pm liao, write a bit in your journal lah.`,
    },
    chinese_auntie: {
      title: `该写日记啦｜${ai}`,
      body: n
        ? `${n}，阿姨${ai}跟你说～八点了喂！今天咋样，写两句日记嘛～`
        : `${ai}阿姨叫你啦～八点了，写两句日记好不好～`,
    },
  };
  return templates[characterId] ?? templates.default;
}

/** Short title for surprise-reply FCM. */
export function journalSurpriseNotificationTitle(characterId: string): string {
  const ai = journalAiSelfName(characterId);
  switch (characterId) {
    case "gyaru":
      return `${ai}から💕`;
    case "chinese_auntie":
      return `${ai}阿姨のひとこと`;
    case "kopitiam_uncle":
      return `${ai} · journal`;
    default:
      return `Journal · ${ai}`;
  }
}

/**
 * Line(s) prepended to the AI snippet in surprise push when user set a nickname.
 * Tone: thanks for journaling (user example vibe).
 */
export function journalSurpriseNotificationLead(
  characterId: string,
  greetingName: string,
): string {
  const n = greetingName.trim();
  if (!n) return "";
  const ai = journalAiSelfName(characterId);
  switch (characterId) {
    case "gyaru":
      return `${n}、聞いて聞いて〜！ジャーナルありがとうね〜。`;
    case "kopitiam_uncle":
      return `${n}, Wong here — thanks for the journal entry ah.`;
    case "chinese_auntie":
      return `${n}，${ai}阿姨看到啦，谢谢你写日记～`;
    default:
      return `${n}, thank you for your journal entry.`;
  }
}
