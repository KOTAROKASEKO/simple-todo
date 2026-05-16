"use client";

import { useCallback, useState } from "react";
import { RecipeEditorCards } from "@/components/RecipeEditorCards";
import { patchUserRecipeClient } from "@/lib/patchUserRecipeClient";
import type { RecipeFirestoreDoc } from "@/lib/recipeSchema";

type Props = {
  uid: string;
  importSecret: string;
  /** 一覧取得成功時（AI プロンプト用の既存名などに使う） */
  onListLoaded?: (recipes: RecipeFirestoreDoc[]) => void;
};

function authHeaders(importSecret: string): Record<string, string> {
  const h: Record<string, string> = {};
  if (importSecret.trim()) h["x-import-secret"] = importSecret.trim();
  return h;
}

export function FirestoreRecipeEditorPanel({
  uid,
  importSecret,
  onListLoaded,
}: Props) {
  const [rows, setRows] = useState<RecipeFirestoreDoc[]>([]);
  const [listLoading, setListLoading] = useState(false);
  const [editorError, setEditorError] = useState<string | null>(null);
  const [editorOk, setEditorOk] = useState<string | null>(null);

  const u = uid.trim();

  const fetchList = useCallback(async () => {
    setEditorError(null);
    setEditorOk(null);
    if (!u) {
      setEditorError("UID を入力してください。");
      return;
    }
    setListLoading(true);
    try {
      const res = await fetch(
        `/api/user-recipes?uid=${encodeURIComponent(u)}`,
        { headers: authHeaders(importSecret) },
      );
      const raw = await res.text();
      let data: {
        ok?: boolean;
        recipes?: RecipeFirestoreDoc[];
        error?: string;
      };
      try {
        data = raw ? (JSON.parse(raw) as typeof data) : {};
      } catch {
        setEditorError(`一覧の応答が JSON ではありません (${res.status})。`);
        return;
      }
      if (!res.ok) {
        setEditorError(data.error ?? `HTTP ${res.status}`);
        return;
      }
      const list = data.recipes ?? [];
      setRows(list);
      onListLoaded?.(list);
      setEditorOk(`${list.length} 件を読み込みました。`);
    } catch (e) {
      setEditorError(e instanceof Error ? e.message : String(e));
    } finally {
      setListLoading(false);
    }
  }, [u, importSecret, onListLoaded]);

  const persistRecipe = useCallback(
    async (merged: RecipeFirestoreDoc) => {
      await patchUserRecipeClient({
        uid: u,
        importSecret,
        recipe: merged,
      });
    },
    [u, importSecret],
  );

  return (
    <section className="panel recipe-editor-panel">
      <p className="section-title">Firestore の既存データ</p>
      <p className="section-hint">
        <code>todo/「uid」/user_recipes</code> を一覧し、サムネ・本文を編集して保存。サムネ枠タップで
        Pexels（<code>.env.local</code> の <code>PEXELS_API_KEY</code>）。
      </p>
      <div className="btn-row">
        <button
          type="button"
          className="btn btn-primary"
          disabled={listLoading}
          onClick={() => void fetchList()}
        >
          {listLoading ? "読み込み中…" : "一覧を取得"}
        </button>
      </div>
      {editorError && (
        <div className="alert-error recipe-editor-alert">{editorError}</div>
      )}
      {editorOk && !editorError && (
        <p className="msg-ok recipe-editor-ok">{editorOk}</p>
      )}

      {rows.length > 0 && (
        <RecipeEditorCards
          recipes={rows}
          onRecipesChange={setRows}
          persistRecipe={persistRecipe}
        />
      )}
    </section>
  );
}
