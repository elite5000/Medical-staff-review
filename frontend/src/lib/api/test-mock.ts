import type { Mock } from 'vitest';

/**
 * Loosely-typed shape for `vi.mock('.../client', ...)` test doubles. openapi-fetch's real
 * client methods are deeply overloaded per-path generics; preserving that through
 * `vi.mocked()` makes `.mockResolvedValue(...)` resolve against an arbitrary (usually
 * wrong) overload instead of the endpoint actually under test. Tests intentionally trade
 * that precision away here — `toHaveBeenCalledWith` assertions still catch mistakes.
 */
export interface MockApi {
  GET: Mock;
  POST: Mock;
  PATCH: Mock;
  DELETE: Mock;
}

export function mockResponse(data: unknown, error?: unknown) {
  return { data, error, response: new Response() };
}
