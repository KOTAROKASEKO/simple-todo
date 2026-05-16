"use client";

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <main className="app-main">
      <h1 className="app-title">エラー</h1>
      <div className="alert-error">{error.message}</div>
      <button type="button" className="btn btn-primary" onClick={() => reset()}>
        再読み込み
      </button>
    </main>
  );
}
