import {VertexAI} from "@google-cloud/vertexai";

export type JournalReflectionPayload = {
  affirmation: string;
  advice: string;
};

export type JournalRecentHistoryItem = {
  summary: string;
  createdAtMillis: number;
  category?: string;
};

export function parseJournalReflectionJson(
  text: string,
): JournalReflectionPayload {
  const trimmed = text.trim();
  let raw = trimmed;
  const fence = trimmed.match(/^```(?:json)?\s*([\s\S]*?)```$/m);
  if (fence) {
    raw = fence[1].trim();
  }
  try {
    const o = JSON.parse(raw) as Record<string, unknown>;
    const affirmation =
      typeof o.affirmation === "string" ? o.affirmation.trim() : "";
    const advice = typeof o.advice === "string" ? o.advice.trim() : "";
    if (affirmation.length > 0 || advice.length > 0) {
      return {affirmation, advice};
    }
  } catch {
    // fall through
  }
  return {
    affirmation: "",
    advice: trimmed || "No response generated.",
  };
}

/**
 * Gemini: web-Gemini-style reply in two JSON string fields (Markdown inside values).
 */
const MAX_PERSONALIZATION_IN_PROMPT = 8000;
const MAX_IMPORTANT_PROFILE_CHARS = 5000;
const MAX_RECENT_HISTORY_ITEMS_IN_PROMPT = 3;
const MAX_RECENT_SUMMARY_CHARS = 400;

const JOURNAL_AI_CHARACTERS: Record<string, string> = {
  default:
    "You are a therapist-like assistant: warm, grounding, practical, and clear. " +
    "You do not insist on a personal name; if needed, refer to yourself neutrally (e.g. journal companion).",
  gyaru:
    "Your name is 美咲 (Misaki). You are a super positive gyaru-style AI: upbeat, friendly, fast-paced, and encouraging. " +
    "Stay playful but never crude or aggressive. You may sign or refer to yourself as 美咲 when natural.",
  kopitiam_uncle:
    "Your name is Wong. You are a kopitiam uncle persona: calm, warm, practical, and grounded. " +
    "Share short, useful life wisdom. You may refer to yourself as Wong when natural.",
  chinese_auntie:
    "Your name is Yin (阿姨 Yin). You are an energetic Chinese auntie persona: caring, direct, lively, and motivating. " +
    "Be strong but affectionate, never threatening or violent. You may refer to yourself as Yin / 阿姨 when natural.",
};

export async function generateJournalReflection(
  project: string,
  content: string,
  category: string,
  journalPersonalization: string,
  importantProfile: Record<string, unknown> | null,
  recentHistory: JournalRecentHistoryItem[],
  characterId: string,
  userNickname: string,
): Promise<JournalReflectionPayload> {
  const vertexAI = new VertexAI({
    project: project,
    location: "us-central1",
  });

  const model = vertexAI.getGenerativeModel({
    model: "gemini-2.5-flash",
  });

  const categoryLine = category
    ? `Category: ${category}`
    : "Category: (unspecified)";

  const personalization = journalPersonalization.trim().slice(
    0,
    MAX_PERSONALIZATION_IN_PROMPT,
  );
  const personalizationBlock =
    personalization.length > 0
      ? `The user wrote the following notes so journal replies can feel personal (respect when it does not conflict with being helpful):\n---\n${personalization}\n---\n\n`
      : "";
  const importantProfileJson = importantProfile == null
    ? ""
    : JSON.stringify(importantProfile).slice(0, MAX_IMPORTANT_PROFILE_CHARS);
  const importantProfileBlock =
    importantProfileJson.length > 0
      ? `Important user profile JSON (if relevant, use this to personalize):\n${importantProfileJson}\n\n`
      : "";
  const recentForPrompt = recentHistory
    .slice(0, MAX_RECENT_HISTORY_ITEMS_IN_PROMPT)
    .map((h, i) => {
      const summary = h.summary
        .toString()
        .trim()
        .slice(0, MAX_RECENT_SUMMARY_CHARS);
      const when = Number.isFinite(h.createdAtMillis)
        ? new Date(h.createdAtMillis).toISOString()
        : "unknown-time";
      const cat = h.category ? ` (${h.category})` : "";
      return `${i + 1}. ${when}${cat}: ${summary}`;
    })
    .join("\n");
  const recentHistoryBlock =
    recentForPrompt.length > 0
      ? `Recent conversation history (latest first):\n${recentForPrompt}\n\n`
      : "";
  const characterInstruction =
    JOURNAL_AI_CHARACTERS[characterId] ?? JOURNAL_AI_CHARACTERS.default;
  const characterBlock = `Character instruction:\n${characterInstruction}\n\n`;
  const nick = userNickname.trim().slice(0, 40);
  const nicknameBlock =
    nick.length > 0
      ? `The user asked to be addressed as “${nick}” when it fits naturally (do not overuse; skip if it breaks tone).\n\n`
      : "";
  const preferredLanguageRaw =
    importantProfile != null && typeof importantProfile["language"] === "string"
      ? (importantProfile["language"] as string).trim()
      : "";
  const languageRuleBlock = preferredLanguageRaw.length > 0
    ? `Language rule: reply in the user's language. Primary signal is the journal entry text. If ambiguous, use "${preferredLanguageRaw}". Keep one language consistently; do not mix languages unless the user did.\n\n`
    : "Language rule: reply in the user's language. Primary signal is the journal entry text. Keep one language consistently; do not mix languages unless the user did.\n\n";

  const prompt =
    personalizationBlock +
    importantProfileBlock +
    recentHistoryBlock +
    characterBlock +
    nicknameBlock +
    languageRuleBlock +
    `As a kind, intelligent, and highly capable AI assistant, please strictly follow the guidelines below when responding to the user's private journal entry.\n\n` +
    `1. Persona & tone\n` +
    `Maintain a tone that is intelligent, adaptable, and friendly, with a touch of wit when appropriate.\n` +
    `Be empathetic, while also providing objective and honest professional opinions.\n` +
    `Avoid overly rigid or robotic language; use natural, conversational style in the same language as the journal entry (do not switch to English if the entry is not in English).\n\n` +
    `2. Structured responses (readability first)\n` +
    `Organize information so that it is easy to understand at a glance.\n` +
    `Use **bold** to highlight key points.\n` +
    `When appropriate, use:\n` +
    `Bullet points (*)\n` +
    `Headings (##, ###)\n` +
    `Horizontal rules (---)\n` +
    `Avoid long, dense blocks of text. Break content into clear paragraphs.\n\n` +
    `3. Quality of response\n` +
    `Understand the user's intent and go beyond simply answering—provide additional insights or helpful context.\n` +
    `If the request is ambiguous, respond with the most likely interpretation, and ask clarifying questions if necessary.\n\n` +
    `4. Small daily happening (light fiction)\n` +
    `Include one short, vivid everyday happening as a creative touch (1-2 sentences max).\n` +
    `It may be invented, but keep it plausible, warm, and not dramatic.\n` +
    `Do not present dangerous, legal, medical, or financial misinformation as fact.\n` +
    `Blend it naturally into the response in the same language as the journal.\n\n` +
    `5. Looking forward to the next entry\n` +
    `When it fits the tone, include a brief warm sign-off that you are looking forward to their next journal (e.g. you are excited for tomorrow’s diary / the next time they write). One short phrase or sentence; match the user’s language. Skip if it would feel forced or repetitive.\n\n` +
    `---\n` +
    `Output contract (required for this app):\n` +
    `Reply as ONE JSON object only (no markdown code fence around the whole reply, no text before or after the JSON).\n` +
    `Shape: {"affirmation":"...","advice":"..."}\n` +
    `Put your main reply in "affirmation" and optional follow-up (or "") in "advice"; split content across them however fits.\n` +
    `Apply the guidelines above (sections 1–5) inside those two string values using Markdown. Escape quotes and newlines properly in JSON.\n\n` +
    `${categoryLine}\n\n` +
    `Journal entry:\n---\n${content}\n---`;

  const result = await model.generateContent({
    contents: [
      {
        role: "user",
        parts: [{text: prompt}],
      },
    ],
  });

  const response = result.response;
  const parts = response.candidates?.[0]?.content?.parts ?? [];
  const rawText = parts
    .map((p) => (p as {text?: string}).text ?? "")
    .join("\n")
    .trim();

  return parseJournalReflectionJson(rawText);
}
