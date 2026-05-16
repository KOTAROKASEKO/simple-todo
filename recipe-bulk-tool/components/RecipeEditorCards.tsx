"use client";

import { useCallback, useEffect, useState } from "react";
import {
  normalizeSearchTagsFromMultiline,
  type RecipeFirestoreDoc,
} from "@/lib/recipeSchema";

export function linesFromTextarea(text: string): string[] {
  return text
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
}

function CameraIcon() {
  return (
    <svg
      className="recipe-thumb-camera-svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      <path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z" />
      <circle cx="12" cy="13" r="3.5" />
    </svg>
  );
}

export type RecipeEditorCardsProps = {
  recipes: RecipeFirestoreDoc[];
  onRecipesChange: (next: RecipeFirestoreDoc[]) => void;
  /** 指定時は「Firestore に保存」で API 送信。未指定時は親 state へのマージのみ（サーバー未送信）。 */
  persistRecipe?: (merged: RecipeFirestoreDoc) => Promise<void>;
  saveButtonLabel?: string;
  /** true のとき「このレシピを除外する」を出す（JSON 検証後の一覧向け。Firestore からは削除しない） */
  canExcludeFromList?: boolean;
};

export function RecipeEditorCards({
  recipes,
  onRecipesChange,
  persistRecipe,
  saveButtonLabel,
  canExcludeFromList = false,
}: RecipeEditorCardsProps) {
  const [ingTextById, setIngTextById] = useState<Record<string, string>>({});
  const [stepTextById, setStepTextById] = useState<Record<string, string>>({});
  const [tagTextById, setTagTextById] = useState<Record<string, string>>({});
  const [pexelsQueryById, setPexelsQueryById] = useState<Record<string, string>>(
    {},
  );
  const [thumbBroken, setThumbBroken] = useState<Record<string, boolean>>({});
  const [savingId, setSavingId] = useState<string | null>(null);
  const [pexelsLoadingId, setPexelsLoadingId] = useState<string | null>(null);
  const [notice, setNotice] = useState<{ kind: "ok" | "error"; text: string } | null>(
    null,
  );

  const idsKey = recipes.map((r) => r.id).join("|");

  useEffect(() => {
    const ing: Record<string, string> = {};
    const st: Record<string, string> = {};
    const tg: Record<string, string> = {};
    const pq: Record<string, string> = {};
    for (const r of recipes) {
      ing[r.id] = r.ingredientLines.join("\n");
      st[r.id] = r.stepLines.join("\n");
      tg[r.id] = r.searchTags.join("\n");
      pq[r.id] = r.name;
    }
    setIngTextById(ing);
    setStepTextById(st);
    setTagTextById(tg);
    setPexelsQueryById(pq);
    setThumbBroken({});
  }, [idsKey]);

  const patchRecipe = useCallback(
    (id: string, patch: Partial<RecipeFirestoreDoc>) => {
      onRecipesChange(
        recipes.map((r) => (r.id === id ? { ...r, ...patch } : r)),
      );
    },
    [recipes, onRecipesChange],
  );

  const mergeRecipe = useCallback(
    (recipeId: string): RecipeFirestoreDoc | null => {
      const row = recipes.find((r) => r.id === recipeId);
      if (!row) return null;
      return {
        ...row,
        ingredientLines: linesFromTextarea(ingTextById[recipeId] ?? ""),
        stepLines: linesFromTextarea(stepTextById[recipeId] ?? ""),
        searchTags: normalizeSearchTagsFromMultiline(
          tagTextById[recipeId] ?? "",
        ),
        thumbUrl: row.thumbUrl?.trim() ?? "",
      };
    },
    [recipes, ingTextById, stepTextById, tagTextById],
  );

  const fetchPexelsThumb = useCallback(
    async (recipeId: string) => {
      setNotice(null);
      const row = recipes.find((r) => r.id === recipeId);
      if (!row) return;
      const q = (pexelsQueryById[recipeId] ?? row.name).trim() || row.name.trim();
      if (!q) {
        setNotice({
          kind: "error",
          text: "Pexels 検索語が空です。レシピ名を入力するか、検索語欄を埋めてください。",
        });
        return;
      }
      setPexelsLoadingId(recipeId);
      try {
        const res = await fetch(
          `/api/pexels-search?q=${encodeURIComponent(q)}`,
        );
        const raw = await res.text();
        let data: { imageUrl?: string; error?: string; hint?: string };
        try {
          data = raw ? (JSON.parse(raw) as typeof data) : {};
        } catch {
          setNotice({ kind: "error", text: "Pexels の応答が JSON ではありません。" });
          return;
        }
        if (!res.ok) {
          const hint = data.hint ? `\n${data.hint}` : "";
          setNotice({
            kind: "error",
            text: `${data.error ?? `Pexels HTTP ${res.status}`}${hint}`,
          });
          return;
        }
        const url = data.imageUrl?.trim();
        if (!url) {
          setNotice({ kind: "error", text: "画像 URL が返りませんでした。" });
          return;
        }
        patchRecipe(recipeId, { thumbUrl: url });
        setThumbBroken((prev) => ({ ...prev, [recipeId]: false }));
        setNotice({
          kind: "ok",
          text: persistRecipe
            ? "画像をセットしました。「Firestore に保存」で書き込みます。"
            : "画像をセットしました。「一覧へ反映（ローカルのみ）」で一覧データに含めます。",
        });
      } catch (e) {
        setNotice({
          kind: "error",
          text: e instanceof Error ? e.message : String(e),
        });
      } finally {
        setPexelsLoadingId(null);
      }
    },
    [recipes, pexelsQueryById, patchRecipe, persistRecipe],
  );

  const saveRow = useCallback(
    async (recipeId: string) => {
      setNotice(null);
      const merged = mergeRecipe(recipeId);
      if (!merged) return;
      if (persistRecipe) {
        setSavingId(recipeId);
        try {
          await persistRecipe(merged);
          const next = recipes.map((r) => (r.id === recipeId ? merged : r));
          onRecipesChange(next);
          setIngTextById((prev) => ({
            ...prev,
            [recipeId]: merged.ingredientLines.join("\n"),
          }));
          setStepTextById((prev) => ({
            ...prev,
            [recipeId]: merged.stepLines.join("\n"),
          }));
          setTagTextById((prev) => ({
            ...prev,
            [recipeId]: merged.searchTags.join("\n"),
          }));
          setNotice({ kind: "ok", text: `保存しました: ${recipeId}` });
        } catch (e) {
          setNotice({
            kind: "error",
            text: e instanceof Error ? e.message : String(e),
          });
        } finally {
          setSavingId(null);
        }
      } else {
        onRecipesChange(
          recipes.map((r) => (r.id === recipeId ? merged : r)),
        );
        setIngTextById((prev) => ({
          ...prev,
          [recipeId]: merged.ingredientLines.join("\n"),
        }));
        setStepTextById((prev) => ({
          ...prev,
          [recipeId]: merged.stepLines.join("\n"),
        }));
        setTagTextById((prev) => ({
          ...prev,
          [recipeId]: merged.searchTags.join("\n"),
        }));
        setNotice({ kind: "ok", text: `一覧データを更新しました: ${recipeId}` });
      }
    },
    [mergeRecipe, persistRecipe, onRecipesChange, recipes],
  );

  const labelSave =
    saveButtonLabel ??
    (persistRecipe ? "Firestore に保存" : "一覧へ反映（ローカルのみ）");

  if (recipes.length === 0) return null;

  return (
    <div className="recipe-editor-cards-wrap">
      {notice && (
        <div
          className={
            notice.kind === "error" ? "alert-error recipe-editor-alert" : "msg-ok recipe-editor-ok"
          }
          role={notice.kind === "error" ? "alert" : undefined}
        >
          {notice.text}
        </div>
      )}
      <ul className="recipe-editor-list">
        {recipes.map((r) => {
          const broken = thumbBroken[r.id] === true;
          const url = r.thumbUrl?.trim();
          const showImg = Boolean(url) && !broken;
          const pexBusy = pexelsLoadingId === r.id;
          return (
            <li key={r.id} className="recipe-editor-card">
              <div className="recipe-editor-card-head">
                <button
                  type="button"
                  className="recipe-thumb-hit"
                  disabled={pexBusy}
                  onClick={() => void fetchPexelsThumb(r.id)}
                  title="タップで Pexels から画像を取得"
                >
                  {showImg ? (
                    <img
                      src={url}
                      alt=""
                      className="recipe-thumb-img"
                      onError={() =>
                        setThumbBroken((prev) => ({ ...prev, [r.id]: true }))
                      }
                    />
                  ) : (
                    <span className="recipe-thumb-placeholder">
                      {pexBusy ? (
                        <span className="recipe-thumb-spinner" aria-hidden />
                      ) : (
                        <CameraIcon />
                      )}
                    </span>
                  )}
                </button>
                <div className="recipe-editor-fields">
                  <label className="form-label recipe-editor-label-tight">
                    Pexels 検索語
                    <input
                      type="text"
                      value={pexelsQueryById[r.id] ?? ""}
                      onChange={(e) =>
                        setPexelsQueryById((prev) => ({
                          ...prev,
                          [r.id]: e.target.value,
                        }))
                      }
                      className="input-field"
                      placeholder={r.name}
                    />
                  </label>
                  <label className="form-label recipe-editor-label-tight">
                    サムネ URL（手入力可）
                    <input
                      type="text"
                      value={r.thumbUrl ?? ""}
                      onChange={(e) => {
                        patchRecipe(r.id, { thumbUrl: e.target.value });
                        setThumbBroken((prev) => ({ ...prev, [r.id]: false }));
                      }}
                      className="input-field"
                      placeholder="https://…"
                    />
                  </label>
                  <label className="form-label recipe-editor-label-tight">
                    レシピ名
                    <input
                      type="text"
                      value={r.name}
                      onChange={(e) => patchRecipe(r.id, { name: e.target.value })}
                      className="input-field"
                    />
                  </label>
                  <label className="form-checkbox recipe-editor-checkbox">
                    <input
                      type="checkbox"
                      checked={r.isPublic}
                      onChange={(e) =>
                        patchRecipe(r.id, { isPublic: e.target.checked })
                      }
                    />
                    <span>公開する (isPublic)</span>
                  </label>
                </div>
              </div>
              <label className="form-label recipe-editor-label-tight">
                検索タグ（1 行 1 タグ・# 可・小文字化・最大 24 個）
                <textarea
                  value={tagTextById[r.id] ?? ""}
                  onChange={(e) =>
                    setTagTextById((prev) => ({
                      ...prev,
                      [r.id]: e.target.value,
                    }))
                  }
                  className="textarea-code recipe-editor-textarea-sm"
                  rows={3}
                  spellCheck={false}
                  placeholder={"pasta\nquick dinner"}
                />
              </label>
              <label className="form-label recipe-editor-label-tight">
                説明
                <textarea
                  value={r.description ?? ""}
                  onChange={(e) =>
                    patchRecipe(r.id, {
                      description: e.target.value.trim()
                        ? e.target.value
                        : undefined,
                    })
                  }
                  className="textarea-code recipe-editor-textarea-sm"
                  rows={2}
                />
              </label>
              <label className="form-label recipe-editor-label-tight">
                材料（1 行 1 項目）
                <textarea
                  value={ingTextById[r.id] ?? ""}
                  onChange={(e) =>
                    setIngTextById((prev) => ({
                      ...prev,
                      [r.id]: e.target.value,
                    }))
                  }
                  className="textarea-code recipe-editor-textarea-sm"
                  rows={4}
                />
              </label>
              <label className="form-label recipe-editor-label-tight">
                手順（1 行 1 ステップ）
                <textarea
                  value={stepTextById[r.id] ?? ""}
                  onChange={(e) =>
                    setStepTextById((prev) => ({
                      ...prev,
                      [r.id]: e.target.value,
                    }))
                  }
                  className="textarea-code recipe-editor-textarea-sm"
                  rows={4}
                />
              </label>
              <div className="btn-row recipe-editor-save-row">
                {canExcludeFromList && (
                  <button
                    type="button"
                    className="btn btn-secondary"
                    disabled={savingId === r.id}
                    onClick={() => {
                      setNotice(null);
                      onRecipesChange(recipes.filter((x) => x.id !== r.id));
                    }}
                  >
                    このレシピを除外する
                  </button>
                )}
                <button
                  type="button"
                  className="btn btn-primary"
                  disabled={savingId === r.id}
                  onClick={() => void saveRow(r.id)}
                >
                  {savingId === r.id ? "保存中…" : labelSave}
                </button>
                <code className="recipe-editor-docid">{r.id}</code>
              </div>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
