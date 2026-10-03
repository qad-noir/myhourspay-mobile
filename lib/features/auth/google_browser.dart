import 'dart:convert';
import 'dart:js_interop';

@JS('mhpGoogleAuthenticate')
external JSPromise<JSString> _authenticate(JSString clientId, JSString nonce);

Future<Map<String, dynamic>> authenticateGoogleWeb(
  String clientId,
  String nonce,
) async {
  final result = await _authenticate(clientId.toJS, nonce.toJS).toDart;
  return jsonDecode(result.toDart) as Map<String, dynamic>;
}
