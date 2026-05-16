"use client";

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import { FirestoreRecipeEditorPanel } from "@/components/FirestoreRecipeEditorPanel";
import { RecipeEditorCards } from "@/components/RecipeEditorCards";
import { patchUserRecipeClient } from "@/lib/patchUserRecipeClient";
import {
  parseRecipeArray,
  toFirestoreFields,
  type RecipeFirestoreDoc,
} from "@/lib/recipeSchema";

/** Default Firestore owner UID for this tool (public reference). */
const DEFAULT_FIREBASE_UID = "3DWpEWThrOUVwepIeBGIP2w9Vh32";

/** AI に「この形で」と渡す用の public_recipes 風サンプル（1 オブジェクト）。 */
const SAMPLE_OBJECT = {
  ownerUid: DEFAULT_FIREBASE_UID,
  recipeId: "user-recipe-roti-canai",
  name: "Roti Canai",
  ingredientLines: ["flour", "water", "salt", "oil", "curry"],
  stepLines: [
    "knead dough",
    "rest dough",
    "stretch thin",
    "fold and fry",
    "serve with curry",
  ],
  searchTags: ["bread", "indian", "malaysia"],
  isPublic: true,
  updatedAt: 1776569481620,
  description: "crispy flatbread with curry",
  thumbUrl:
    "https://images.pexels.com/photos/33169387/pexels-photo-33169387.jpeg?auto=compress&cs=tinysrgb&h=650&w=940",
  path: `public_recipes/${DEFAULT_FIREBASE_UID}__user-recipe-roti-canai`,
  objectID: `${DEFAULT_FIREBASE_UID}__user-recipe-roti-canai`,
};

const SAMPLE = JSON.stringify(SAMPLE_OBJECT, null, 2);

function collectDedupedRecipeNames(
  firestore: readonly RecipeFirestoreDoc[],
  parsed: readonly RecipeFirestoreDoc[] | null,
): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const group of [firestore, parsed ?? []] as const) {
    for (const r of group) {
      const t = r.name.trim();
      if (!t) continue;
      const k = t.toLowerCase();
      if (seen.has(k)) continue;
      seen.add(k);
      out.push(t);
    }
  }
  return out;
}

function buildAiPromptBlock(names: string[], sampleJson: string): string {
  const nameBlock =
    names.length > 0
      ? names.map((n) => `- ${n}`).join("\n")
      : "（まだありません。Firestore タブで「一覧を取得」するか、JSON タブで検証すると、名前が「再生成」に反映されます。）";

  return [
    "【重要】以下の「既存レシピ名」と同じ名前の新規レシピは作らないでください（別レシピなら別名を付けてください）。",
    "",
    "## 既存レシピ名（重複除去済み・Firestore 一覧のあと JSON 検証分をマージ）",
    "",
    nameBlock,
    "",
    "## JSON のサンプル（ルートはオブジェクト 1 件または配列。必要ならこの形で出力してください）",
    "",
    "あなたは家庭で作れるとても簡単でシンプルだけど美味しい料理のレシピの専門家です。わかりやすくもシンプルなステップを楽しげな雰囲気で作成してください。",
    "",
    sampleJson,
  ].join("\n");
}

function downloadJson(filename: string, data: unknown) {
  const blob = new Blob([JSON.stringify(data, null, 2)], {
    type: "application/json;charset=utf-8",
  });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

function downloadText(filename: string, text: string) {
  const blob = new Blob([text], { type: "text/plain;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export default function HomePage() {
  const [text, setText] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [recipes, setRecipes] = useState<RecipeFirestoreDoc[] | null>(null);
  const [uid, setUid] = useState(DEFAULT_FIREBASE_UID);
  const [uploadAsPublic, setUploadAsPublic] = useState(true);
  const [importSecret, setImportSecret] = useState("");
  const [uploading, setUploading] = useState(false);
  const [uploadMessage, setUploadMessage] = useState<string | null>(null);
  const [uploadMessageKind, setUploadMessageKind] = useState<"ok" | "warn">(
    "ok",
  );
  const [mainTab, setMainTab] = useState<"json" | "firestore" | "money">("json");
  const [monthlyBudgetText, setMonthlyBudgetText] = useState("");
  const [elapsedDaysText, setElapsedDaysText] = useState("");
  const [spentAmountText, setSpentAmountText] = useState("");
  const [targetMonth, setTargetMonth] = useState(() => {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
  });
  const [firestoreRecipesSnapshot, setFirestoreRecipesSnapshot] = useState<
    RecipeFirestoreDoc[]
  >([]);
  const dedupedNamesForPrompt = useMemo(
    () => collectDedupedRecipeNames(firestoreRecipesSnapshot, recipes),
    [firestoreRecipesSnapshot, recipes],
  );
  const daysInTargetMonth = useMemo(() => {
    const [yearText, monthText] = targetMonth.split("-");
    const year = Number(yearText);
    const month = Number(monthText);
    if (!Number.isFinite(year) || !Number.isFinite(month)) return 30;
    return new Date(year, month, 0).getDate();
  }, [targetMonth]);
  const monthlyBudget = useMemo(() => {
    const normalized = monthlyBudgetText.replaceAll(",", "").trim();
    if (!normalized) return null;
    const value = Number(normalized);
    if (!Number.isFinite(value) || value < 0) return null;
    return value;
  }, [monthlyBudgetText]);
  const dailyBudget = useMemo(() => {
    if (monthlyBudget === null || daysInTargetMonth <= 0) return null;
    return monthlyBudget / daysInTargetMonth;
  }, [monthlyBudget, daysInTargetMonth]);
  const elapsedDays = useMemo(() => {
    const normalized = elapsedDaysText.trim();
    if (!normalized) return null;
    const value = Number(normalized);
    if (!Number.isFinite(value) || value < 0) return null;
    return Math.min(daysInTargetMonth, Math.floor(value));
  }, [elapsedDaysText, daysInTargetMonth]);
  const spentAmount = useMemo(() => {
    const normalized = spentAmountText.replaceAll(",", "").trim();
    if (!normalized) return null;
    const value = Number(normalized);
    if (!Number.isFinite(value) || value < 0) return null;
    return value;
  }, [spentAmountText]);
  const allowedSpendSoFar = useMemo(() => {
    if (dailyBudget === null || elapsedDays === null) return null;
    return dailyBudget * elapsedDays;
  }, [dailyBudget, elapsedDays]);
  const spendDelta = useMemo(() => {
    if (allowedSpendSoFar === null || spentAmount === null) return null;
    return spentAmount - allowedSpendSoFar;
  }, [allowedSpendSoFar, spentAmount]);
  const avgSpendPerDay = useMemo(() => {
    if (elapsedDays === null || elapsedDays <= 0 || spentAmount === null) return null;
    return spentAmount / elapsedDays;
  }, [elapsedDays, spentAmount]);
  const projectedMonthlySpend = useMemo(() => {
    if (avgSpendPerDay === null) return null;
    return avgSpendPerDay * daysInTargetMonth;
  }, [avgSpendPerDay, daysInTargetMonth]);
  const [aiPromptText, setAiPromptText] = useState(() =>
    buildAiPromptBlock([], SAMPLE),
  );
  const [aiPromptCopyHint, setAiPromptCopyHint] = useState<string | null>(null);
  const parseAnchorRef = useRef<HTMLDivElement>(null);
  const [parseTick, setParseTick] = useState(0);

  useEffect(() => {
    setFirestoreRecipesSnapshot([]);
  }, [uid]);

  useEffect(() => {
    if (parseTick === 0) return;
    parseAnchorRef.current?.scrollIntoView({
      behavior: "smooth",
      block: "nearest",
    });
  }, [parseTick]);

  const rebuildAiPromptFromSources = useCallback(() => {
    setAiPromptText(buildAiPromptBlock(dedupedNamesForPrompt, SAMPLE));
  }, [dedupedNamesForPrompt]);

  const copyAiPromptToClipboard = useCallback(async () => {
    setAiPromptCopyHint(null);
    setError(null);
    try {
      await navigator.clipboard.writeText(aiPromptText);
      setAiPromptCopyHint("クリップボードにコピーしました（AI のチャットに貼れます）");
      window.setTimeout(() => setAiPromptCopyHint(null), 3000);
    } catch {
      setError(
        "コピーに失敗しました。HTTPS で開いているか、ブラウザのクリップボード許可を確認してください。",
      );
    }
  }, [aiPromptText]);

  const runParse = useCallback(() => {
    setError(null);
    try {
      const t = text.trim();
      if (!t) {
        setRecipes(null);
        setError("JSON を入力してください。");
        setParseTick((n) => n + 1);
        return;
      }
      const { recipes: parsedList } = parseRecipeArray(t);
      setRecipes(parsedList);
      setParseTick((n) => n + 1);
    } catch (e) {
      setRecipes(null);
      setError(e instanceof Error ? e.message : String(e));
      setParseTick((n) => n + 1);
    }
  }, [text]);

  const exportBundle = useMemo(() => {
    if (!recipes?.length) return null;
    return {
      collectionPathHint: "todo/{uid}/user_recipes/{docId}",
      note:
        "Firestore の createdAt / updatedAt はアプリ側の FieldValue なので含めていません。set 時にマージしてください。",
      recipes: recipes.map((r) => ({
        docId: r.id,
        fields: toFirestoreFields(r),
      })),
    };
  }, [recipes]);

  const persistJsonRecipe = useCallback(
    async (merged: RecipeFirestoreDoc) => {
      const u = uid.trim();
      if (!u) {
        throw new Error("ページ上部の UID を入力してください。");
      }
      await patchUserRecipeClient({
        uid: u,
        importSecret,
        recipe: merged,
      });
    },
    [uid, importSecret],
  );

  const uploadToFirestore = useCallback(async () => {
    if (!recipes?.length) return;
    const u = uid.trim();
    if (!u) {
      setUploadMessage(null);
      setError("Firestore 用の UID を入力してください。");
      return;
    }
    setUploading(true);
    setUploadMessage(null);
    setError(null);
    try {
      const headers: Record<string, string> = {
        "Content-Type": "application/json",
      };
      if (importSecret.trim()) {
        headers["x-import-secret"] = importSecret.trim();
      }
      const recipesForUpload = uploadAsPublic
        ? recipes.map((r) => ({ ...r, isPublic: true }))
        : recipes;
      const res = await fetch("/api/import-recipes", {
        method: "POST",
        headers,
        body: JSON.stringify({ uid: u, recipes: recipesForUpload }),
      });
      const raw = await res.text();
      let data: {
        ok?: boolean;
        projectId?: string;
        collectionPath?: string;
        written?: number;
        failed?: number;
        errors?: string[];
        error?: string;
      };
      try {
        data = raw ? (JSON.parse(raw) as typeof data) : {};
      } catch {
        setError(
          `サーバー応答が JSON ではありません (${res.status})。開発サーバを再起動するか、ターミナルのログを確認してください。`,
        );
        return;
      }
      if (!res.ok) {
        const hint =
          res.status === 401
            ? " `.env.local` の RECIPE_IMPORT_SECRET と、下の「インポート用シークレット」が一致しているか確認してください。"
            : "";
        setError(`${data.error ?? `HTTP ${res.status}`}${hint}`);
        return;
      }
      const written = data.written ?? 0;
      const failed = data.failed ?? 0;
      const projectHint = data.projectId
        ? ` Firebase プロジェクト「${data.projectId}」の ${data.collectionPath ?? "todo/{uid}/user_recipes"} を確認してください。`
        : "";
      const errDetail =
        data.errors && data.errors.length
          ? data.errors.slice(0, 8).join(" | ")
          : "";
      if (written === 0 && failed > 0) {
        setUploadMessage(null);
        setError(
          `1 件も書き込めませんでした（${failed} 件）。${projectHint}\n${errDetail}`,
        );
        return;
      }
      if (failed > 0) {
        setUploadMessageKind("warn");
        setUploadMessage(
          `書き込み: 成功 ${written} 件 / 失敗 ${failed} 件。${projectHint}${errDetail ? `\n失敗理由（抜粋）: ${errDetail}` : ""}`,
        );
        return;
      }
      setUploadMessageKind("ok");
      setUploadMessage(`書き込み完了: ${written} 件。${projectHint}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setUploading(false);
    }
  }, [recipes, uid, importSecret, uploadAsPublic]);

  return (
    <main className="app-main">
      <h1 className="app-title">Recipe bulk JSON</h1>
      <p className="app-lead">
        タブで <strong>JSON インポート</strong> と{" "}
        <strong>Firestore 一覧</strong>、<strong>Money</strong> を切り替え。JSON /
        Firestore は同じ UID / シークレットを使います。
      </p>

      <section className="panel panel-user-context">
        <p className="section-title">接続（両タブ共通）</p>
        <form
          className="form-user-context"
          onSubmit={(e) => e.preventDefault()}
        >
          <label className="form-label">
            Firebase Auth UID（<code>todo/このuid/user_recipes</code>）
            <input
              type="text"
              name="firebase_uid"
              value={uid}
              onChange={(e) => setUid(e.target.value)}
              placeholder={DEFAULT_FIREBASE_UID}
              autoComplete="off"
              className="input-field"
            />
          </label>
          <label className="form-label">
            インポート用シークレット（任意）
            <input
              type="password"
              name="import_secret"
              value={importSecret}
              onChange={(e) => setImportSecret(e.target.value)}
              placeholder="RECIPE_IMPORT_SECRET と一致"
              autoComplete="new-password"
              className="input-field"
            />
          </label>
        </form>
      </section>

      <div className="main-tabs" role="tablist" aria-label="モード切替">
        <button
          type="button"
          role="tab"
          aria-selected={mainTab === "json"}
          className={`main-tab ${mainTab === "json" ? "main-tab-active" : ""}`}
          onClick={() => setMainTab("json")}
        >
          JSON インポート
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={mainTab === "firestore"}
          className={`main-tab ${mainTab === "firestore" ? "main-tab-active" : ""}`}
          onClick={() => setMainTab("firestore")}
        >
          Firestore 一覧
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={mainTab === "money"}
          className={`main-tab ${mainTab === "money" ? "main-tab-active" : ""}`}
          onClick={() => setMainTab("money")}
        >
          Money
        </button>
      </div>

      <section className="panel panel-ai-prompt">
        <p className="section-title">AI 用プロンプト（既存名一覧 + JSON サンプル）</p>
        <p className="section-hint">
          Firestore で「一覧を取得」した内容と、JSON タブで検証済みのレシピ名を重複なくまとめます。「再生成」でこの欄を置き換え、必要なら編集してから「コピー」してください。
        </p>
        <div className="btn-row">
          <button
            type="button"
            className="btn btn-secondary"
            onClick={rebuildAiPromptFromSources}
          >
            再生成（名前 {dedupedNamesForPrompt.length} 件を反映）
          </button>
          <button
            type="button"
            className="btn btn-primary"
            onClick={() => void copyAiPromptToClipboard()}
          >
            この内容をコピー
          </button>
        </div>
        {aiPromptCopyHint && (
          <p className="msg-ok copy-hint">{aiPromptCopyHint}</p>
        )}
        <textarea
          value={aiPromptText}
          onChange={(e) => setAiPromptText(e.target.value)}
          spellCheck={false}
          className="textarea-code textarea-ai-prompt"
          aria-label="AI 用プロンプト全文（編集可）"
        />
      </section>

      {mainTab === "json" && (
        <>
          <section className="panel">
            <div className="panel-row">
              <span className="panel-label">
                レシピ JSON（配列のルート、またはオブジェクト 1 件）
              </span>
              <div className="panel-actions">
                <button
                  type="button"
                  onClick={() => setText(SAMPLE)}
                  className="btn btn-secondary"
                >
                  サンプルを入れる
                </button>
              </div>
            </div>
            <p className="section-hint json-input-hint">
              検証対象は<strong>この直下の入力欄</strong>だけです。上の「AI用プロンプト」はコピー用で、ここには含めません。
            </p>
            <form
              className="recipe-json-parse-form"
              onSubmit={(e) => {
                e.preventDefault();
                runParse();
              }}
            >
              <textarea
                value={text}
                onChange={(e) => setText(e.target.value)}
                spellCheck={false}
                placeholder='[ { "name": "…", "ingredientLines": [], "stepLines": [] } ] または { "recipeId": "…", … }'
                className="textarea-code"
                name="recipe_json"
              />
              <div ref={parseAnchorRef} className="parse-anchor" aria-live="polite">
                <div className="btn-row parse-actions">
                  <button type="submit" className="btn btn-primary">
                    検証する
                  </button>
                </div>
                {error && (
                  <div className="alert-error parse-feedback" role="alert">
                    {error}
                  </div>
                )}
                {recipes !== null && !error && recipes.length === 0 && (
                  <p className="msg-warn parse-feedback">
                    検証は完了しましたが、レシピは{" "}
                    <strong>0 件</strong>です（ルートが空の配列{" "}
                    <code>[]</code> など）。1 件以上のオブジェクトが入った配列か、オブジェクト 1
                    件を貼り付けてください。
                  </p>
                )}
                {recipes !== null && !error && recipes.length > 0 && (
                  <p className="result-ok parse-feedback">
                    検証OK — {recipes.length} 件（下のカードで編集・Pexels 画像）
                  </p>
                )}
              </div>
            </form>
          </section>

          {recipes && recipes.length > 0 && (
            <section className="panel">
              <p className="section-title">レシピ一覧（Firestore 一覧と同じ UI）</p>
              <p className="section-hint">
                各カードの「Firestore に保存」で{" "}
                <code>todo/「uid」/user_recipes</code> の該当ドキュメントへ即書き込みします（無ければ作成）。「このレシピを除外する」は
                <strong>この一覧からだけ</strong>外します（Firestore の既存データは消しません）。
              </p>
              <RecipeEditorCards
                recipes={recipes}
                onRecipesChange={(next) => setRecipes(next)}
                persistRecipe={persistJsonRecipe}
                canExcludeFromList
              />
            </section>
          )}

          {recipes && recipes.length > 0 && (
            <section className="panel">
              <p className="section-title">エクスポート・Firestore へ一括書き込み</p>
              <div className="btn-row">
                <button
                  type="button"
                  className="btn btn-primary"
                  onClick={() =>
                    downloadJson(
                      `user_recipes_bulk_${Date.now()}.json`,
                      exportBundle,
                    )
                  }
                >
                  エクスポート JSON をダウンロード
                </button>
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => {
                    const lines = recipes!.map((r) =>
                      JSON.stringify({
                        docId: r.id,
                        fields: toFirestoreFields(r),
                      }),
                    );
                    downloadText(
                      `user_recipes_bulk_${Date.now()}.jsonl`,
                      `${lines.join("\n")}\n`,
                    );
                  }}
                >
                  NDJSON（1行1レシピ）をダウンロード
                </button>
              </div>
              <div className="upload-divider">
                <p className="section-title">Firestore に一括アップロード</p>
                <p className="section-hint">
                  認証は{" "}
                  <strong>
                    <code>service-account.json</code>
                  </strong>
                  。UID / シークレットはページ上部の「接続」で指定。{" "}
                  <code>npm run dev</code> 再起動で鍵を読み直し。
                </p>
                <form
                  className="form-stack"
                  onSubmit={(e) => {
                    e.preventDefault();
                    void uploadToFirestore();
                  }}
                >
                  <label className="form-checkbox">
                    <input
                      type="checkbox"
                      checked={uploadAsPublic}
                      onChange={(e) => setUploadAsPublic(e.target.checked)}
                    />
                    <span>
                      書き込むレシピをすべて{" "}
                      <code>isPublic: true</code> にする
                    </span>
                  </label>
                  <button
                    type="submit"
                    className="btn btn-primary"
                    disabled={uploading}
                  >
                    {uploading ? "アップロード中…" : "Firestore に書き込む"}
                  </button>
                  {uploadMessage && (
                    <p
                      className={
                        uploadMessageKind === "warn" ? "msg-warn" : "msg-ok"
                      }
                    >
                      {uploadMessage}
                    </p>
                  )}
                </form>
              </div>
              <details className="details-schema">
                <summary>スキーマ（AI向けメモ）</summary>
                <pre className="code-block">
              {`ルートは「配列」または「オブジェクト1件」。
各要素:
- name (string, 必須)
- ingredientLines (string[], 必須・空可)
- stepLines (string[], 必須・空可)
- description (string, 任意)
- thumbUrl (string, 任意)
- isPublic (boolean, 任意・省略時 true) ※ 非公開にしたい場合は JSON に isPublic: false を書く
- searchTags (string[] または改行区切りの1 string, 任意) → 小文字化・重複除去・各40文字・最大24個
- id (string, 任意)
- recipeId / objectID (public_recipes・Algolia 形式でも可) → id が無いとき docId に使う。objectID は ownerUid__recipeId のうち recipeId 側を採用
- ownerUid, path, updatedAt などその他のキーは無視される

Firestore パス: todo/{uid}/user_recipes/{docId}
アプリは createdAt / updatedAt を FieldValue で付与します。このツールの出力には含めません。`}
                </pre>
              </details>
            </section>
          )}
        </>
      )}

      {mainTab === "firestore" && (
        <FirestoreRecipeEditorPanel
          uid={uid}
          importSecret={importSecret}
          onListLoaded={setFirestoreRecipesSnapshot}
        />
      )}

      {mainTab === "money" && (
        <section className="panel">
          <p className="section-title">Money（予算と出費ペース）</p>
          <p className="section-hint">
            1ヶ月の目標予算と「ここまでの実支出」を入れると、経過日数ぶんの許容予算と比較して、使いすぎ/節約ペースを確認できます。
          </p>
          <form className="form-user-context" onSubmit={(e) => e.preventDefault()}>
            <label className="form-label">
              対象月
              <input
                type="month"
                value={targetMonth}
                onChange={(e) => setTargetMonth(e.target.value)}
                className="input-field"
              />
            </label>
            <label className="form-label">
              1ヶ月の目標予算額（RM）
              <input
                type="number"
                min="0"
                step="1"
                inputMode="numeric"
                value={monthlyBudgetText}
                onChange={(e) => setMonthlyBudgetText(e.target.value)}
                placeholder="例: 60000"
                className="input-field"
              />
            </label>
            <label className="form-label">
              経過日数（例: 3日目なら 3）
              <input
                type="number"
                min="0"
                step="1"
                inputMode="numeric"
                value={elapsedDaysText}
                onChange={(e) => setElapsedDaysText(e.target.value)}
                placeholder={`1〜${daysInTargetMonth}`}
                className="input-field"
              />
            </label>
            <label className="form-label">
              ここまでの実支出（RM）
              <input
                type="number"
                min="0"
                step="1"
                inputMode="numeric"
                value={spentAmountText}
                onChange={(e) => setSpentAmountText(e.target.value)}
                placeholder="例: 280"
                className="input-field"
              />
            </label>
          </form>
          <div className="result-box">
            <p>
              対象月の日数: <strong>{daysInTargetMonth}日</strong>
            </p>
            <p>
              1日あたりの目標予算:{" "}
              <strong>
                {dailyBudget === null
                  ? "未入力"
                  : `${Math.floor(dailyBudget).toLocaleString("ja-JP")} RM`}
              </strong>
            </p>
            <p>
              経過日数ぶんの許容予算:{" "}
              <strong>
                {allowedSpendSoFar === null
                  ? "未入力"
                  : `${Math.floor(allowedSpendSoFar).toLocaleString("ja-JP")} RM`}
              </strong>
            </p>
            <p>
              実支出との差分:{" "}
              <strong>
                {spendDelta === null
                  ? "未入力"
                  : spendDelta > 0
                    ? `+${Math.floor(spendDelta).toLocaleString("ja-JP")} RM（予算オーバー）`
                    : `${Math.floor(Math.abs(spendDelta)).toLocaleString("ja-JP")} RM 余裕`}
              </strong>
            </p>
            <p>
              実支出の1日平均ペース:{" "}
              <strong>
                {avgSpendPerDay === null
                  ? "未入力"
                  : `${Math.floor(avgSpendPerDay).toLocaleString("ja-JP")} RM / 日`}
              </strong>
            </p>
            <p>
              月末予測支出（今のペース）:{" "}
              <strong>
                {projectedMonthlySpend === null
                  ? "未入力"
                  : `${Math.floor(projectedMonthlySpend).toLocaleString("ja-JP")} RM`}
              </strong>
            </p>
          </div>
        </section>
      )}
    </main>
  );
}
