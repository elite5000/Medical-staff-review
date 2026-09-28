import 'package:app/api/api_client.dart';
import 'package:test/test.dart';

/// Regression: saving a form more than 5s after the page loaded failed with "Could not
/// reach the server" — the client reused a keep-alive socket uvicorn had already closed
/// (uvicorn's timeout_keep_alive is 5s; Dart's default idleTimeout is 15s). Reproduced
/// against the real packaged backend: a second request 7s after the first failed with the
/// default client and succeeded with a 3s idleTimeout.
void main() {
  test('backend HttpClient drops idle sockets before uvicorn closes them', () {
    const uvicornKeepAlive = Duration(seconds: 5);

    expect(newBackendHttpClient().idleTimeout, lessThan(uvicornKeepAlive));
  });
}
