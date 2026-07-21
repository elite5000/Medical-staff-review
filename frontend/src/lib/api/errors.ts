/**
 * FastAPI error bodies are either `{ detail: string }` (HTTPException, e.g. 404/409) or
 * `{ detail: [{ msg: string, ... }] }` (Pydantic validation errors, e.g. 422). This
 * normalizes both into a single display string for ErrorBanner.
 */
export function extractErrorMessage(error: unknown, fallback: string): string {
  if (error && typeof error === 'object' && 'detail' in error) {
    const detail = (error as { detail: unknown }).detail;
    if (typeof detail === 'string') {
      return detail;
    }
    if (Array.isArray(detail)) {
      return detail
        .map((item) =>
          item && typeof item === 'object' && 'msg' in item
            ? String(item.msg)
            : String(item),
        )
        .join('; ');
    }
  }
  return fallback;
}
