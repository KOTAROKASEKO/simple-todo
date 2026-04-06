import {VertexAI} from "@google-cloud/vertexai";

export type JournalReflectionPayload = {
  affirmation: string;
  advice: string;
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

export async function generateJournalReflection(
  project: string,
  content: string,
  category: string,
  journalPersonalization: string,
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

  const prompt =
    personalizationBlock +
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
    `---\n` +
    `Output contract (required for this app):\n` +
    `Reply as ONE JSON object only (no markdown code fence around the whole reply, no text before or after the JSON).\n` +
    `Shape: {"affirmation":"...","advice":"..."}\n` +
    `Put your main reply in "affirmation" and optional follow-up (or "") in "advice"; split content across them however fits.\n` +
    `Apply sections 1–3 inside those two string values using Markdown. Escape quotes and newlines properly in JSON.\n\n` +
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
