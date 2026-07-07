import 'dart:convert';

import 'package:cryptography/cryptography.dart';

Future<String> createPairingProof({
  required String pairingSecret,
  required String challenge,
  required String deviceId,
}) async {
  final hmac = Hmac.sha256();
  final mac = await hmac.calculateMac(
    utf8.encode('$challenge:$deviceId'),
    secretKey: SecretKey(utf8.encode(pairingSecret)),
  );
  return base64Encode(mac.bytes);
}
