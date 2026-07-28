/// Mirrors frontend/src/lib/api/errors.ts: FastAPI error bodies are either
/// `{ detail: string }` (HTTPException, e.g. 404/409) or `{ detail: [{ msg: string, ... }] }`
/// (Pydantic validation errors, e.g. 422). This normalizes both into a single display string.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  factory ApiException.fromResponseBody(int statusCode, Object? decodedBody) {
    if (decodedBody is Map && decodedBody['detail'] != null) {
      final detail = decodedBody['detail'];
      if (detail is String) {
        return ApiException(statusCode, detail);
      }
      if (detail is List) {
        final message = detail
            .map((item) => item is Map && item['msg'] != null ? item['msg'].toString() : item.toString())
            .join('; ');
        return ApiException(statusCode, message);
      }
    }
    return ApiException(statusCode, 'Request failed with status $statusCode');
  }

  @override
  String toString() => message;
}
