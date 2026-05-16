import { readFileSync, existsSync } from "fs";
import { join } from "path";
import { cert, getApps, initializeApp, type App } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

let app: App | null = null;
let cachedProjectId: string | null = null;

/** service account JSON または環境変数から project id を取る */
function projectIdFromCredential(cred: Record<string, unknown>): string | null {
  const snake = cred.project_id;
  const camel = cred.projectId;
  if (typeof snake === "string" && snake.trim()) return snake.trim();
  if (typeof camel === "string" && camel.trim()) return camel.trim();
  const env =
    process.env.GCLOUD_PROJECT?.trim() ||
    process.env.GOOGLE_CLOUD_PROJECT?.trim();
  return env && env.length > 0 ? env : null;
}

function resolvePath(p: string): string {
  if (p.startsWith("~/")) {
    const home = process.env.HOME ?? "";
    return join(home, p.slice(2));
  }
  if (p.startsWith("/")) return p;
  return join(process.cwd(), p);
}

function loadServiceAccountJson(): Record<string, unknown> {
  const b64 = process.env.FIREBASE_SERVICE_ACCOUNT_JSON_BASE64?.trim();
  if (b64) {
    try {
      return JSON.parse(
        Buffer.from(b64, "base64").toString("utf8"),
      ) as Record<string, unknown>;
    } catch {
      throw new Error(
        "FIREBASE_SERVICE_ACCOUNT_JSON_BASE64 is set but is not valid base64 JSON.",
      );
    }
  }

  const pathEnv = process.env.FIREBASE_SERVICE_ACCOUNT_PATH?.trim();
  if (pathEnv) {
    const p = resolvePath(pathEnv);
    if (!existsSync(p)) {
      throw new Error(
        `FIREBASE_SERVICE_ACCOUNT_PATH: file not found: ${p} (cwd: ${process.cwd()})`,
      );
    }
    try {
      return JSON.parse(readFileSync(p, "utf8")) as Record<string, unknown>;
    } catch (e) {
      throw new Error(
        `FIREBASE_SERVICE_ACCOUNT_PATH: invalid JSON: ${e instanceof Error ? e.message : e}`,
      );
    }
  }

  const gac = process.env.GOOGLE_APPLICATION_CREDENTIALS?.trim();
  if (gac) {
    const p = resolvePath(gac);
    if (!existsSync(p)) {
      throw new Error(
        `GOOGLE_APPLICATION_CREDENTIALS: file not found: ${p} (cwd: ${process.cwd()})`,
      );
    }
    try {
      return JSON.parse(readFileSync(p, "utf8")) as Record<string, unknown>;
    } catch (e) {
      throw new Error(
        `GOOGLE_APPLICATION_CREDENTIALS: invalid JSON: ${e instanceof Error ? e.message : e}`,
      );
    }
  }

  let raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (typeof raw === "string") {
    raw = raw.trim();
    if (
      (raw.startsWith("'") && raw.endsWith("'")) ||
      (raw.startsWith('"') && raw.endsWith('"'))
    ) {
      raw = raw.slice(1, -1);
    }
  }
  if (raw && raw.length > 0) {
    try {
      return JSON.parse(raw) as Record<string, unknown>;
    } catch (e) {
      throw new Error(
        `FIREBASE_SERVICE_ACCOUNT_JSON: JSON のパースに失敗しました。.env に長い JSON を直書きすると private_key 内の「=」や引用符で壊れやすいです。**service-account.json を置く**か **BASE64 一行**を使ってください。 (${e instanceof Error ? e.message : e})`,
      );
    }
  }

  // No env: look for a key file next to package.json or one level up (monorepo root).
  const defaultPaths = [
    join(process.cwd(), "service-account.json"),
    join(process.cwd(), ".firebase", "service-account.json"),
    join(process.cwd(), "..", "service-account.json"),
    join(process.cwd(), "..", ".firebase", "service-account.json"),
  ];
  for (const p of defaultPaths) {
    if (existsSync(p)) {
      try {
        return JSON.parse(readFileSync(p, "utf8")) as Record<string, unknown>;
      } catch (e) {
        throw new Error(
          `Default credential file invalid JSON: ${p} — ${e instanceof Error ? e.message : e}`,
        );
      }
    }
  }

  throw new Error(
    "Firebase Admin の認証情報が読み込めません。**.env に JSON 全文を1行で貼らないでください**（「type」以降だけ値になったり、= で切れたりします）。次のどれかを使い、**npm run dev を再起動**してください。\n\n" +
      "【おすすめ】`service-account.json` を置く（.env 不要）。探索順: ① `npm run dev` したフォルダ（recipe-bulk-tool/）② その親（リポジトリルート）③ 各 `.firebase/` 配下。\n" +
      "または `FIREBASE_SERVICE_ACCOUNT_PATH=../service-account.json` のようにパス指定。\n" +
      "または `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64=` に `cat key.json | base64 | tr -d '\\\\n'` の1行\n" +
      "または `GOOGLE_APPLICATION_CREDENTIALS=./service-account.json`\n\n" +
      `現在の cwd: ${process.cwd()}`,
  );
}

export function getFirebaseAdminApp(): App {
  if (getApps().length) {
    // Fast Refresh 等でこのモジュールだけが再評価されると cachedProjectId が null に戻るが、
    // getApps() のアプリはプロセスに残る。早期 return 前に project id を復元する。
    if (!cachedProjectId) {
      const existing = getApps()[0]!;
      const opt = existing.options?.projectId;
      if (typeof opt === "string" && opt.trim()) {
        cachedProjectId = opt.trim();
      } else {
        try {
          const cred = loadServiceAccountJson();
          cachedProjectId = projectIdFromCredential(cred);
        } catch {
          /* 認証は既に初期化済みのため、ここでは握りつぶす */
        }
      }
    }
    return getApps()[0]!;
  }
  const cred = loadServiceAccountJson();
  cachedProjectId = projectIdFromCredential(cred);
  app = initializeApp({
    credential: cert(cred as Parameters<typeof cert>[0]),
    ...(cachedProjectId ? { projectId: cachedProjectId } : {}),
  });
  return app;
}

export function getFirebaseProjectId(): string {
  getFirebaseAdminApp();
  if (!cachedProjectId) {
    throw new Error(
      "service account JSON に project_id（または projectId）がありません。Firebase Console から落とした鍵 JSON を使うか、.env に GCLOUD_PROJECT を設定してください。",
    );
  }
  return cachedProjectId;
}

export function getAdminFirestore() {
  getFirebaseAdminApp();
  return getFirestore();
}
