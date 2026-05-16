/** Same rules as bulk import: optional RECIPE_IMPORT_SECRET + x-import-secret header. */
export function checkImportSecret(request: Request): boolean {
  const secret = process.env.RECIPE_IMPORT_SECRET;
  if (!secret || !secret.trim()) return true;
  return request.headers.get("x-import-secret") === secret;
}
