import * as admin from "firebase-admin";
import {algoliasearch} from "algoliasearch";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {logger} from "firebase-functions";

const PUBLIC_COLLECTION = "public_recipes";
const DEFAULT_INDEX_NAME = "public_recipes";

function publicDocId(ownerUid: string, recipeId: string): string {
  return `${ownerUid}__${recipeId}`;
}

function stringList(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return v
    .map((e) => String(e).trim())
    .filter((s) => s.length > 0);
}

function getAlgolia(): {client: ReturnType<typeof algoliasearch>; indexName: string} | null {
  const appId = process.env.ALGOLIA_APP_ID?.trim();
  const apiKey = process.env.ALGOLIA_ADMIN_API_KEY?.trim();
  const indexName =
    process.env.ALGOLIA_PUBLIC_RECIPES_INDEX?.trim() || DEFAULT_INDEX_NAME;
  if (!appId || !apiKey) return null;
  return {client: algoliasearch(appId, apiKey), indexName};
}

function algoliaRecordFromRecipe(
  objectID: string,
  ownerUid: string,
  recipeId: string,
  data: admin.firestore.DocumentData,
): Record<string, unknown> {
  const name = typeof data.name === "string" ? data.name.trim() : "";
  const description =
    typeof data.description === "string" ? data.description.trim() : "";
  const thumbUrl =
    typeof data.thumbUrl === "string" ? data.thumbUrl.trim() : "";
  const ingredientLines = stringList(data.ingredientLines);
  const searchTags = stringList(data.searchTags);
  const ingredientsText = ingredientLines.join(" ").slice(0, 4000);
  return {
    objectID,
    ownerUid,
    recipeId,
    name,
    description,
    thumbUrl: thumbUrl || undefined,
    searchTags,
    ingredientsText,
  };
}

function firestorePublicFields(
  ownerUid: string,
  recipeId: string,
  data: admin.firestore.DocumentData,
): Record<string, unknown> {
  const name = typeof data.name === "string" ? data.name.trim() : "";
  const description =
    typeof data.description === "string" ? data.description.trim() : "";
  const thumbUrl =
    typeof data.thumbUrl === "string" ? data.thumbUrl.trim() : "";
  // Plain `set()` cannot use FieldValue.delete(); omit optional fields instead.
  const out: Record<string, unknown> = {
    ownerUid,
    recipeId,
    name,
    ingredientLines: stringList(data.ingredientLines),
    stepLines: stringList(data.stepLines),
    searchTags: stringList(data.searchTags),
    updatedAt:
      data.updatedAt instanceof admin.firestore.Timestamp
        ? data.updatedAt
        : admin.firestore.FieldValue.serverTimestamp(),
  };
  if (description.length > 0) out.description = description;
  if (thumbUrl.length > 0) out.thumbUrl = thumbUrl;
  return out;
}

async function deletePublicAndAlgolia(
  db: admin.firestore.Firestore,
  ownerUid: string,
  recipeId: string,
): Promise<void> {
  const id = publicDocId(ownerUid, recipeId);
  await db.collection(PUBLIC_COLLECTION).doc(id).delete().catch(() => undefined);
  const algolia = getAlgolia();
  if (!algolia) return;
  try {
    await algolia.client.deleteObject({
      indexName: algolia.indexName,
      objectID: id,
    });
  } catch (e) {
    logger.warn("Algolia deleteObject failed", {id, err: String(e)});
  }
}

async function upsertPublicAndAlgolia(
  db: admin.firestore.Firestore,
  ownerUid: string,
  recipeId: string,
  data: admin.firestore.DocumentData,
): Promise<void> {
  const id = publicDocId(ownerUid, recipeId);
  const fields = firestorePublicFields(ownerUid, recipeId, data);
  await db.collection(PUBLIC_COLLECTION).doc(id).set(fields);

  const algolia = getAlgolia();
  if (!algolia) return;
  const record = algoliaRecordFromRecipe(id, ownerUid, recipeId, data);
  try {
    await algolia.client.saveObjects({
      indexName: algolia.indexName,
      objects: [record],
    });
  } catch (e) {
    logger.error("Algolia saveObjects failed", {id, err: String(e)});
  }
}

/**
 * Mirrors public user recipes to `public_recipes/{ownerUid}__{recipeId}` and Algolia
 * when `todo/{uid}/user_recipes/{id}` is public; removes when private or deleted.
 *
 * Env (optional Algolia): ALGOLIA_APP_ID, ALGOLIA_ADMIN_API_KEY, ALGOLIA_PUBLIC_RECIPES_INDEX.
 */
export const onUserRecipeWrittenSyncPublicRecipes = onDocumentWritten(
  {
    document: "todo/{userId}/user_recipes/{recipeId}",
    region: "us-central1",
  },
  async (event) => {
    const change = event.data;
    if (!change) return;

    const ownerUid = event.params.userId;
    const recipeId = event.params.recipeId;
    const db = admin.firestore();

    const after = change.after;
    if (!after.exists) {
      await deletePublicAndAlgolia(db, ownerUid, recipeId);
      return;
    }

    const data = after.data() ?? {};
    const isPublic = data.isPublic === true;
    if (!isPublic) {
      await deletePublicAndAlgolia(db, ownerUid, recipeId);
      return;
    }

    const name = typeof data.name === "string" ? data.name.trim() : "";
    if (!name) {
      await deletePublicAndAlgolia(db, ownerUid, recipeId);
      return;
    }

    await upsertPublicAndAlgolia(db, ownerUid, recipeId, data);
  },
);

/** Authenticated search over the public recipes Algolia index. */
export const searchPublicRecipes = onCall(
  {region: "us-central1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }

    const algolia = getAlgolia();
    if (!algolia) {
      return {hits: [] as Record<string, unknown>[]};
    }

    const raw = request.data as {query?: unknown; hitsPerPage?: unknown};
    const query = typeof raw.query === "string" ? raw.query.trim() : "";
    let hitsPerPage = 24;
    if (typeof raw.hitsPerPage === "number" && Number.isFinite(raw.hitsPerPage)) {
      hitsPerPage = Math.min(50, Math.max(1, Math.floor(raw.hitsPerPage)));
    }

    const res = await algolia.client.searchSingleIndex({
      indexName: algolia.indexName,
      searchParams: {
        query: query || "",
        hitsPerPage,
      },
    });

    const hits = (res.hits ?? []).map((h) => {
      const hit = h as Record<string, unknown>;
      return {
        objectID: hit.objectID,
        ownerUid: hit.ownerUid,
        recipeId: hit.recipeId,
        name: hit.name,
        description: hit.description,
        thumbUrl: hit.thumbUrl,
      };
    });

    return {hits};
  },
);
