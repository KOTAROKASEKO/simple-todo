import type { NextConfig } from "next";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const nextConfig: NextConfig = {
  reactStrictMode: true,
  // ホーム直下など別の package-lock があると Next が誤ったルートを推論するため、このアプリを固定する。
  outputFileTracingRoot: path.join(__dirname),
  // firebase-admin はネイティブ/動的 require が多く、バンドルすると
  // 「a[d] is not a function」などのランタイムエラーになることがある。
  serverExternalPackages: ["firebase-admin"],
};

export default nextConfig;
