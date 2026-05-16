"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.searchPublicRecipes = exports.onUserRecipeWrittenSyncPublicRecipes = void 0;
const admin = __importStar(require("firebase-admin"));
const algoliasearch_1 = require("algoliasearch");
const firestore_1 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const PUBLIC_COLLECTION = "public_recipes";
const DEFAULT_INDEX_NAME = "public_recipes";
function publicDocId(ownerUid, recipeId) {
    return `${ownerUid}__${recipeId}`;
}
function stringList(v) {
    if (!Array.isArray(v))
        return [];
    return v
        .map((e) => String(e).trim())
        .filter((s) => s.length > 0);
}
function getAlgolia() {
    const appId = process.env.ALGOLIA_APP_ID?.trim();
    const apiKey = process.env.ALGOLIA_ADMIN_API_KEY?.trim();
    const indexName = process.env.ALGOLIA_PUBLIC_RECIPES_INDEX?.trim() || DEFAULT_INDEX_NAME;
    if (!appId || !apiKey)
        return null;
    return { client: (0, algoliasearch_1.algoliasearch)(appId, apiKey), indexName };
}
function algoliaRecordFromRecipe(objectID, ownerUid, recipeId, data) {
    const name = typeof data.name === "string" ? data.name.trim() : "";
    const description = typeof data.description === "string" ? data.description.trim() : "";
    const thumbUrl = typeof data.thumbUrl === "string" ? data.thumbUrl.trim() : "";
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
function firestorePublicFields(ownerUid, recipeId, data) {
    const name = typeof data.name === "string" ? data.name.trim() : "";
    const description = typeof data.description === "string" ? data.description.trim() : "";
    const thumbUrl = typeof data.thumbUrl === "string" ? data.thumbUrl.trim() : "";
    // Plain `set()` cannot use FieldValue.delete(); omit optional fields instead.
    const out = {
        ownerUid,
        recipeId,
        name,
        ingredientLines: stringList(data.ingredientLines),
        stepLines: stringList(data.stepLines),
        searchTags: stringList(data.searchTags),
        updatedAt: data.updatedAt instanceof admin.firestore.Timestamp
            ? data.updatedAt
            : admin.firestore.FieldValue.serverTimestamp(),
    };
    if (description.length > 0)
        out.description = description;
    if (thumbUrl.length > 0)
        out.thumbUrl = thumbUrl;
    return out;
}
async function deletePublicAndAlgolia(db, ownerUid, recipeId) {
    const id = publicDocId(ownerUid, recipeId);
    await db.collection(PUBLIC_COLLECTION).doc(id).delete().catch(() => undefined);
    const algolia = getAlgolia();
    if (!algolia)
        return;
    try {
        await algolia.client.deleteObject({
            indexName: algolia.indexName,
            objectID: id,
        });
    }
    catch (e) {
        firebase_functions_1.logger.warn("Algolia deleteObject failed", { id, err: String(e) });
    }
}
async function upsertPublicAndAlgolia(db, ownerUid, recipeId, data) {
    const id = publicDocId(ownerUid, recipeId);
    const fields = firestorePublicFields(ownerUid, recipeId, data);
    await db.collection(PUBLIC_COLLECTION).doc(id).set(fields);
    const algolia = getAlgolia();
    if (!algolia)
        return;
    const record = algoliaRecordFromRecipe(id, ownerUid, recipeId, data);
    try {
        await algolia.client.saveObjects({
            indexName: algolia.indexName,
            objects: [record],
        });
    }
    catch (e) {
        firebase_functions_1.logger.error("Algolia saveObjects failed", { id, err: String(e) });
    }
}
/**
 * Mirrors public user recipes to `public_recipes/{ownerUid}__{recipeId}` and Algolia
 * when `todo/{uid}/user_recipes/{id}` is public; removes when private or deleted.
 *
 * Env (optional Algolia): ALGOLIA_APP_ID, ALGOLIA_ADMIN_API_KEY, ALGOLIA_PUBLIC_RECIPES_INDEX.
 */
exports.onUserRecipeWrittenSyncPublicRecipes = (0, firestore_1.onDocumentWritten)({
    document: "todo/{userId}/user_recipes/{recipeId}",
    region: "us-central1",
}, async (event) => {
    const change = event.data;
    if (!change)
        return;
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
});
/** Authenticated search over the public recipes Algolia index. */
exports.searchPublicRecipes = (0, https_1.onCall)({ region: "us-central1" }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Sign in required.");
    }
    const algolia = getAlgolia();
    if (!algolia) {
        return { hits: [] };
    }
    const raw = request.data;
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
        const hit = h;
        return {
            objectID: hit.objectID,
            ownerUid: hit.ownerUid,
            recipeId: hit.recipeId,
            name: hit.name,
            description: hit.description,
            thumbUrl: hit.thumbUrl,
        };
    });
    return { hits };
});
