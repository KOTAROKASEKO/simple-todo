/**
 * Matches Flutter `UserRecipe` / `toFirestoreFields()` (timestamps added in app).
 */

export type RecipeDraftInput = {
  id?: string;
  /** From `public_recipes` / Algolia export — used as doc id when `id` is missing. */
  recipeId?: unknown;
  /** Algolia `ownerUid__recipeId` — last segment used as doc id if `id` / `recipeId` missing. */
  objectID?: unknown;
  ownerUid?: unknown;
  path?: unknown;
  updatedAt?: unknown;
  name?: unknown;
  description?: unknown;
  thumbUrl?: unknown;
  ingredientLines?: unknown;
  stepLines?: unknown;
  isPublic?: unknown;
  searchTags?: unknown;
};

export type RecipeFirestoreDoc = {
  id: string;
  name: string;
  ingredientLines: string[];
  stepLines: string[];
  isPublic: boolean;
  searchTags: string[];
  description?: string;
  thumbUrl?: string;
};

function asTrimmedString(v: unknown): string | undefined {
  if (typeof v !== "string") return undefined;
  const t = v.trim();
  return t.length ? t : undefined;
}

function asStringArray(v: unknown, field: string): string[] {
  if (!Array.isArray(v)) {
    throw new Error(`${field} must be an array of strings`);
  }
  return v
    .map((x) => String(x).trim())
    .filter((s) => s.length > 0);
}

/** Mirrors Dart `UserRecipe.normalizeSearchTags` (one tag per line in a single string). */
export function normalizeSearchTagsFromMultiline(raw: string): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  for (const line of raw.split(/\r?\n/)) {
    let t = line.trim().toLowerCase();
    if (t.startsWith("#")) t = t.slice(1).trim();
    if (!t) continue;
    if (t.length > 40) t = t.slice(0, 40);
    if (seen.has(t)) continue;
    seen.add(t);
    out.push(t);
    if (out.length >= 24) break;
  }
  return out;
}

export function normalizeSearchTagsArray(tags: unknown): string[] {
  if (tags == null) return [];
  if (Array.isArray(tags)) {
    const raw = tags.map((t) => String(t).trim()).filter(Boolean).join("\n");
    return normalizeSearchTagsFromMultiline(raw);
  }
  if (typeof tags === "string") {
    return normalizeSearchTagsFromMultiline(tags);
  }
  throw new Error("searchTags must be string[], string, or omitted");
}

function normalizeUserDocId(raw: string): string {
  const t = raw.trim();
  if (!t) return "";
  return t.startsWith("user-") ? t : `user-${t.replace(/^user-/, "")}`;
}

/** `id` → `recipeId` → `objectID` (suffix after `__`) → generated. */
function resolveUserRecipeDocId(o: RecipeDraftInput, index: number): string {
  const idRaw = asTrimmedString(o.id);
  if (idRaw) return normalizeUserDocId(idRaw);

  const recipeId = asTrimmedString(o.recipeId);
  if (recipeId) return normalizeUserDocId(recipeId);

  const objectID = asTrimmedString(o.objectID);
  if (objectID && objectID.includes("__")) {
    const suffix = objectID.split("__").pop()!.trim();
    if (suffix) return normalizeUserDocId(suffix);
  }

  return `user-${Date.now()}-${index}-${Math.random().toString(36).slice(2, 9)}`;
}

export function parseRecipeDraft(
  raw: unknown,
  index: number,
): RecipeFirestoreDoc {
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) {
    throw new Error(`Item ${index}: must be a JSON object`);
  }
  const o = raw as RecipeDraftInput;
  const name = asTrimmedString(o.name);
  if (!name) throw new Error(`Item ${index}: "name" is required`);

  const ingredientLines = asStringArray(
    o.ingredientLines ?? [],
    `Item ${index}.ingredientLines`,
  );
  const stepLines = asStringArray(o.stepLines ?? [], `Item ${index}.stepLines`);

  let isPublic = true;
  if (o.isPublic !== undefined) {
    if (typeof o.isPublic !== "boolean") {
      throw new Error(`Item ${index}: "isPublic" must be boolean`);
    }
    isPublic = o.isPublic;
  }

  const searchTags = normalizeSearchTagsArray(o.searchTags);

  const description = asTrimmedString(o.description);
  const thumbUrl = asTrimmedString(o.thumbUrl);

  const id = resolveUserRecipeDocId(o, index);

  const doc: RecipeFirestoreDoc = {
    id,
    name,
    ingredientLines,
    stepLines,
    isPublic,
    searchTags,
  };
  if (description) doc.description = description;
  if (thumbUrl) doc.thumbUrl = thumbUrl;
  return doc;
}

export function parseRecipeArray(jsonText: string): {
  ok: true;
  recipes: RecipeFirestoreDoc[];
} {
  let parsed: unknown;
  try {
    parsed = JSON.parse(jsonText);
  } catch {
    throw new Error("Invalid JSON");
  }
  if (Array.isArray(parsed)) {
    const recipes = parsed.map((item, i) => parseRecipeDraft(item, i));
    return { ok: true, recipes };
  }
  if (parsed !== null && typeof parsed === "object") {
    return { ok: true, recipes: [parseRecipeDraft(parsed, 0)] };
  }
  throw new Error(
    "Root JSON must be an array of recipe objects, or a single recipe object",
  );
}

export function toFirestoreFields(r: RecipeFirestoreDoc): Record<string, unknown> {
  const out: Record<string, unknown> = {
    name: r.name,
    ingredientLines: r.ingredientLines,
    stepLines: r.stepLines,
    isPublic: r.isPublic,
    searchTags: r.searchTags,
  };
  if (r.description) out.description = r.description;
  if (r.thumbUrl) out.thumbUrl = r.thumbUrl;
  return out;
}
