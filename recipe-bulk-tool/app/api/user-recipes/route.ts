import { FieldValue } from "firebase-admin/firestore";
import { NextResponse } from "next/server";
import { firestoreDataToRecipe } from "@/lib/firestoreRecipeFromData";
import { getAdminFirestore, getFirebaseProjectId } from "@/lib/firebaseAdmin";
import { checkImportSecret } from "@/lib/importAuth";
import { toFirestoreFields, type RecipeFirestoreDoc } from "@/lib/recipeSchema";

export const runtime = "nodejs";

const LIST_LIMIT = 200;

function isUid(v: unknown): v is string {
  return typeof v === "string" && v.length >= 1 && v.length <= 128;
}

export async function GET(request: Request) {
  try {
    if (!checkImportSecret(request)) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const { searchParams } = new URL(request.url);
    const uid = searchParams.get("uid");
    if (!isUid(uid)) {
      return NextResponse.json(
        { error: "uid クエリ（1〜128 文字）が必要です。" },
        { status: 400 },
      );
    }

    const db = getAdminFirestore();
    const projectId = getFirebaseProjectId();
    const snap = await db
      .collection("todo")
      .doc(uid)
      .collection("user_recipes")
      .limit(LIST_LIMIT)
      .get();

    const recipes: RecipeFirestoreDoc[] = [];
    for (const doc of snap.docs) {
      const data = doc.data() as Record<string, unknown>;
      recipes.push(firestoreDataToRecipe(doc.id, data));
    }

    return NextResponse.json({
      ok: true,
      projectId,
      collectionPath: `todo/${uid}/user_recipes`,
      recipes,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return NextResponse.json(
      { error: `一覧の取得に失敗しました: ${message}` },
      { status: 500 },
    );
  }
}

export async function PATCH(request: Request) {
  try {
    if (!checkImportSecret(request)) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    let body: { uid?: unknown; recipe?: RecipeFirestoreDoc };
    try {
      body = (await request.json()) as { uid?: unknown; recipe?: RecipeFirestoreDoc };
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

    const recipe = body.recipe;
    if (
      !recipe ||
      typeof recipe.id !== "string" ||
      !recipe.id.trim() ||
      typeof recipe.name !== "string" ||
      !recipe.name.trim()
    ) {
      return NextResponse.json(
        { error: "recipe with id and name is required" },
        { status: 400 },
      );
    }

    const docId = recipe.id.trim();
    const db = getAdminFirestore();
    const ref = db.collection("todo").doc(uid).collection("user_recipes").doc(docId);

    const fields = toFirestoreFields(recipe);
    const payload: Record<string, unknown> = {
      ...fields,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (recipe.thumbUrl !== undefined) {
      if (recipe.thumbUrl.trim()) {
        payload.thumbUrl = recipe.thumbUrl.trim();
      } else {
        payload.thumbUrl = FieldValue.delete();
      }
    }

    await ref.set(payload, { merge: true });

    return NextResponse.json({
      ok: true,
      projectId: getFirebaseProjectId(),
      docId,
    });
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e);
    return NextResponse.json(
      { error: `更新に失敗しました: ${message}` },
      { status: 500 },
    );
  }
}
