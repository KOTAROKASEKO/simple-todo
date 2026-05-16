"use client";

import dynamic from "next/dynamic";

const RecipeBulkHome = dynamic(() => import("./recipe-bulk-home-client"), {
  ssr: false,
  loading: () => (
    <main className="app-main">
      <p className="app-lead">読み込み中…</p>
    </main>
  ),
});

export default function Page() {
  return <RecipeBulkHome />;
}
