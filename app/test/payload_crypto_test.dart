import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imagesync/src/shared/payload_crypto.dart';
import 'package:imagesync/src/shared/wire.dart';

void main() {
  test('round-trips encrypted text payloads', () async {
    final crypto = PayloadCrypto();
    final plaintext = utf8.encode('clipboard text');

    final frame = await crypto.encrypt(
      metadata: const PayloadMetadata(
        type: PayloadType.text,
        mime: 'text/plain',
        origin: 'phone',
        ts: 1800000100000,
      ),
      plaintext: plaintext,
      pairingSecret: 'pairing-secret',
    );

    final decrypted = await crypto.decrypt(
      frame: frame,
      pairingSecret: 'pairing-secret',
    );

    expect(decrypted, plaintext);
  });

  test('rejects the wrong pairing secret', () async {
    final crypto = PayloadCrypto();
    final frame = await crypto.encrypt(
      metadata: const PayloadMetadata(
        type: PayloadType.text,
        mime: 'text/plain',
        origin: 'phone',
        ts: 1800000100001,
      ),
      plaintext: utf8.encode('private text'),
      pairingSecret: 'correct-secret',
    );

    expect(
      () => crypto.decrypt(frame: frame, pairingSecret: 'wrong-secret'),
      throwsA(isA<Object>()),
    );
  });

  test('rejects tampered metadata', () async {
    final crypto = PayloadCrypto();
    final frame = await crypto.encrypt(
      metadata: const PayloadMetadata(
        type: PayloadType.image,
        mime: 'image/png',
        origin: 'phone',
        ts: 1800000100002,
      ),
      plaintext: [137, 80, 78, 71],
      pairingSecret: 'pairing-secret',
    );

    expect(
      () => crypto.decrypt(
        frame: frame.copyWith(mime: 'image/jpeg'),
        pairingSecret: 'pairing-secret',
      ),
      throwsA(isA<Object>()),
    );
  });
}
