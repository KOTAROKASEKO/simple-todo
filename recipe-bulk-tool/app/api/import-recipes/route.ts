import { FieldValue } from "firebase-admin/firestore";
import { NextResponse } from "next/server";
import { getAdminFirestore, getFirebaseProjectId } from "@/lib/firebaseAdmin";
import { checkImportSecret } from "@/lib/importAuth";
import {
  type RecipeFirestoreDoc,
  toFirestoreFields,
} from "@/lib/recipeSchema";

export const runtime = "nodejs";

type Body = {
  uid?: string;
  recipes?: RecipeFirestoreDoc[];
};

function isUid(v: unknown): v is string {
  return typeof v === "string" && v.length >= 1 && v.length <= 128;
}

export async function POST(request: Request) {
  try {
    if (!checkImportSecret(request)) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    let body: Body;
    try {
      body = (await request.json()) as Body;
    } catch {
      return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
    }

    const uid = body.uid;
    if (!isUid(uid)) {
      return NextResponse.json(
        { error: "uid (string) is required" },
        { status: 400 },
      );
    }

    const recipes = body.recipes;
    if (!Array.isArray(recipes) || recipes.length === 0) {
      return NextResponse.json(
        { error: "recipes (non-empty array) is required" },
        { status: 400 },
      );
    }

    if (recipes.length > 500) {
      return NextResponse.json(
        { error: "recipes: max 500 per request (split the batch)" },
        { status: 400 },
      );
    }

    const db = getAdminFirestore();
    const projectId = getFirebaseProjectId();
    const col = db.collection("todo").doc(uid).collection("user_recipes");

    const concurrency = 20;
    const errors: string[] = [];

    for (let i = 0; i < recipes.length; i += concurrency) {
      const chunk = recipes.slice(i, i + concurrency);
      const results = await Promise.all(
        chunk.map(async (r) => {
          try {
            if (!r || typeof r.id !== "string" || !r.id.trim()) {
              return { ok: false as const, error: "invalid recipe id" };
            }
            if (typeof r.name !== "string" || !r.name.trim()) {
              return {
                ok: false as const,
                error: `invalid recipe ${r.id}`,
              };
            }
            const ref = col.doc(r.id.trim());
            const snap = await ref.get();
            const fields = toFirestoreFields(r);
            const payload: Record<string, unknown> = {
              ...fields,
              updatedAt: FieldValue.serverTimestamp(),
            };
            if (!snap.exists) {
              payload.createdAt = FieldValue.serverTimestamp();
            }
            await ref.set(payload, { merge: true });
            return { ok: true as const };
          } catch (e) {
            return {
              ok: false as const,
              error: e instanceof Error ? e.message : String(e),
            };
          }
        }),
      );
      for (const r of results) {
        if (r.ok) continue;
        errors.push(r.error);
      }
    }

    const written = recipes.length - errors.length;

    return NextResponse.json({
      ok: true,
      projectId,
      collectionPath: `todo/${uid}/user_recipes/{docId}`,
      written,
      failed: errors.length,
      errors: errors.length ? errors.slice(0, 20) : undefined,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return NextResponse.json(
      { error: `Firestore 書き込みの準備に失敗しました: ${message}` },
      { status: 500 },
    );
  }
}
