import 'package:flutter_test/flutter_test.dart';
import 'package:vidyut/src/shared/pairing_auth.dart';

void main() {
  test('creates a stable HMAC proof for the relay challenge', () async {
    final proof = await createPairingProof(
      pairingSecret: 'pairing-secret',
      challenge: 'relay-challenge',
      deviceId: 'phone',
    );

    expect(proof, 'gFce+C2P9TQ91OoLN1X06McZlUr+nxscxhSwDrBkBh4=');
  });
}
