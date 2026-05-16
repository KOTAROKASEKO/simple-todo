import { NextResponse } from "next/server";

export const runtime = "nodejs";

/** Pexels API key from env（.env.local 推奨） */
function pexelsApiKey(): string | null {
  const candidates = [
    process.env.PEXELS_API_KEY,
    process.env.PXEL_API_KEY,
    process.env.PIXEL_API_KEY,
  ];
  for (const raw of candidates) {
    let v = raw?.trim();
    if (!v) continue;
    if (
      (v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))
    ) {
      v = v.slice(1, -1).trim();
    }
    if (v) return v;
  }
  return null;
}

export async function GET(request: Request) {
  const key = pexelsApiKey();
  if (!key) {
    return NextResponse.json(
      {
        error:
          "Pexels の API キーが環境変数にありません。recipe-bulk-tool/.env.local に設定し、開発サーバを再起動してください。",
        hint:
          "recipe-bulk-tool/.env.local に PEXELS_API_KEY（または PXEL_API_KEY）を書き、dev を再起動。https://www.pexels.com/api/",
      },
      { status: 503 },
    );
  }

  const { searchParams } = new URL(request.url);
  const query = (searchParams.get("q") ?? searchParams.get("query") ?? "")
    .trim()
    .slice(0, 200);
  if (!query) {
    return NextResponse.json(
      { error: "クエリ q または query が必要です（例: ?q=ramen）。" },
      { status: 400 },
    );
  }

  const url = new URL("https://api.pexels.com/v1/search");
  url.searchParams.set("query", query);
  url.searchParams.set("per_page", "1");

  try {
    const res = await fetch(url.toString(), {
      headers: { Authorization: key },
      next: { revalidate: 0 },
    });
    const raw = await res.text();
    let data: unknown;
    try {
      data = raw ? JSON.parse(raw) : {};
    } catch {
      return NextResponse.json(
        { error: "Pexels の応答が JSON ではありません。" },
        { status: 502 },
      );
    }
    if (!res.ok) {
      const msg =
        typeof data === "object" &&
        data !== null &&
        "error" in data &&
        typeof (data as { error?: string }).error === "string"
          ? (data as { error: string }).error
          : `Pexels HTTP ${res.status}`;
      return NextResponse.json({ error: msg }, { status: 502 });
    }
    const photos =
      typeof data === "object" &&
      data !== null &&
      "photos" in data &&
      Array.isArray((data as { photos: unknown }).photos)
        ? (data as { photos: { src?: { medium?: string; large?: string } }[] })
            .photos
        : [];
    const first = photos[0];
    const imageUrl =
      first?.src?.large?.trim() ||
      first?.src?.medium?.trim() ||
      null;
    if (!imageUrl) {
      return NextResponse.json(
        { error: "該当する写真が見つかりませんでした。別のキーワードを試してください。" },
        { status: 404 },
      );
    }
    return NextResponse.json({ imageUrl, query });
  } catch (e) {
    return NextResponse.json(
      {
        error:
          e instanceof Error ? e.message : "Pexels へのリクエストに失敗しました。",
      },
      { status: 502 },
    );
  }
}
