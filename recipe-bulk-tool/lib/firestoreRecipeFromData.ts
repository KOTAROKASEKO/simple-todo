import type { RecipeFirestoreDoc } from "@/lib/recipeSchema";
import { normalizeSearchTagsArray } from "@/lib/recipeSchema";

function asStringArrayLoose(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return v.map((x) => String(x).trim()).filter(Boolean);
}

/** Build a recipe model from a Firestore `user_recipes` document (best-effort). */
export function firestoreDataToRecipe(
  docId: string,
  data: Record<string, unknown>,
): RecipeFirestoreDoc {
  const name =
    typeof data.name === "string" && data.name.trim()
      ? data.name.trim()
      : "(無題)";
  const ingredientLines = asStringArrayLoose(data.ingredientLines);
  const stepLines = asStringArrayLoose(data.stepLines);
  let isPublic = false;
  if (typeof data.isPublic === "boolean") isPublic = data.isPublic;
  let searchTags: string[] = [];
  try {
    searchTags = normalizeSearchTagsArray(data.searchTags);
  } catch {
    searchTags = [];
  }
  const description =
    typeof data.description === "string" && data.description.trim()
      ? data.description.trim()
      : undefined;
  const thumbUrl =
    typeof data.thumbUrl === "string" && data.thumbUrl.trim()
      ? data.thumbUrl.trim()
      : undefined;

  const doc: RecipeFirestoreDoc = {
    id: docId,
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
