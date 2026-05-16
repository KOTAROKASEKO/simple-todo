import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Recipe bulk JSON (SimpleTodo)",
  description: "Validate AI-generated recipes and export for Firestore user_recipes",
  icons: {
    icon: "/favicon.ico",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
