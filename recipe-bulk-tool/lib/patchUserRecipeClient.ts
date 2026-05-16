import type { RecipeFirestoreDoc } from "@/lib/recipeSchema";

function authHeaders(importSecret: string): Record<string, string> {
  const h: Record<string, string> = {};
  if (importSecret.trim()) h["x-import-secret"] = importSecret.trim();
  return h;
}

/** ブラウザから `/api/user-recipes` へ PATCH（単一レシピ更新） */
export async function patchUserRecipeClient(params: {
  uid: string;
  importSecret: string;
  recipe: RecipeFirestoreDoc;
}): Promise<void> {
  const uid = params.uid.trim();
  const res = await fetch("/api/user-recipes", {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      ...authHeaders(params.importSecret),
    },
    body: JSON.stringify({ uid, recipe: params.recipe }),
  });
  const raw = await res.text();
  let data: { ok?: boolean; error?: string };
  try {
    data = raw ? (JSON.parse(raw) as typeof data) : {};
  } catch {
    throw new Error(`更新の応答が JSON ではありません (${res.status})。`);
  }
  if (!res.ok) {
    const hint =
      res.status === 401
        ? " RECIPE_IMPORT_SECRET と「インポート用シークレット」を確認してください。"
        : "";
    throw new Error(`${data.error ?? `HTTP ${res.status}`}${hint}`);
  }
}
