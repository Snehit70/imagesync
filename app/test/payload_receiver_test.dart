import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imagesync/src/receive/payload_receiver.dart';
import 'package:imagesync/src/receive/received_text_repository.dart';
import 'package:imagesync/src/shared/payload_crypto.dart';
import 'package:imagesync/src/shared/wire.dart';

void main() {
  test(
    'decrypts incoming text, stores it, and writes the Android clipboard',
    () async {
      final clipboard = FakeAndroidClipboard();
      final notifier = FakePayloadNotifier();
      final storage = MemoryReceivedTextStorage();
      final receiver = PayloadReceiver(
        crypto: PayloadCrypto(),
        clipboard: clipboard,
        notifier: notifier,
        receivedTextRepository: ReceivedTextRepository(storage),
      );
      final frame = await PayloadCrypto().encrypt(
        metadata: const PayloadMetadata(
          type: PayloadType.text,
          mime: 'text/plain',
          origin: 'laptop',
          ts: 1800000400000,
        ),
        plaintext: 'hello phone'.codeUnits,
        pairingSecret: 'pairing-secret',
      );

      final result = await receiver.receive(
        frame: frame,
        pairingSecret: 'pairing-secret',
      );

      expect(result.received, isTrue);
      expect(result.message, 'Text copied from laptop.');
      expect(clipboard.text, 'hello phone');
      expect(
        await ReceivedTextRepository(storage).loadLatest(),
        'hello phone',
      );
      expect(notifier.textPreviews.single, 'hello phone');
    },
  );

  test(
    'still receives when the background clipboard write is rejected',
    () async {
      final notifier = FakePayloadNotifier();
      final storage = MemoryReceivedTextStorage();
      final receiver = PayloadReceiver(
        crypto: PayloadCrypto(),
        clipboard: ThrowingAndroidClipboard(),
        notifier: notifier,
        receivedTextRepository: ReceivedTextRepository(storage),
      );
      final frame = await PayloadCrypto().encrypt(
        metadata: const PayloadMetadata(
          type: PayloadType.text,
          mime: 'text/plain',
          origin: 'laptop',
          ts: 1800000400004,
        ),
        plaintext: 'blocked write'.codeUnits,
        pairingSecret: 'pairing-secret',
      );

      final result = await receiver.receive(
        frame: frame,
        pairingSecret: 'pairing-secret',
      );

      expect(result.received, isTrue);
      expect(result.message, 'Text received. Tap the notification to copy.');
      expect(
        await ReceivedTextRepository(storage).loadLatest(),
        'blocked write',
      );
      expect(notifier.textPreviews.single, 'blocked write');
    },
  );

  test(
    'notifies for incoming image payloads without claiming clipboard support',
    () async {
      final clipboard = FakeAndroidClipboard();
      final notifier = FakePayloadNotifier();
      final receiver = PayloadReceiver(
        crypto: PayloadCrypto(),
        clipboard: clipboard,
        notifier: notifier,
        receivedTextRepository: ReceivedTextRepository(
          MemoryReceivedTextStorage(),
        ),
      );
      final frame = await PayloadCrypto().encrypt(
        metadata: const PayloadMetadata(
          type: PayloadType.image,
          mime: 'image/png',
          origin: 'laptop',
          ts: 1800000400001,
        ),
        plaintext: [1, 2, 3, 4],
        pairingSecret: 'pairing-secret',
      );

      final result = await receiver.receive(
        frame: frame,
        pairingSecret: 'pairing-secret',
      );

      expect(result.received, isTrue);
      expect(result.message, 'Image received from laptop.');
      expect(clipboard.text, isNull);
      expect(notifier.imageMimes.single, 'image/png');
    },
  );

  test('reports a clear receive failure for a wrong pairing secret', () async {
    final receiver = PayloadReceiver(
      crypto: PayloadCrypto(),
      clipboard: FakeAndroidClipboard(),
      notifier: FakePayloadNotifier(),
      receivedTextRepository: ReceivedTextRepository(
        MemoryReceivedTextStorage(),
      ),
    );
    final frame = await PayloadCrypto().encrypt(
      metadata: const PayloadMetadata(
        type: PayloadType.text,
        mime: 'text/plain',
        origin: 'laptop',
        ts: 1800000400002,
      ),
      plaintext: 'secret text'.codeUnits,
      pairingSecret: 'pairing-secret',
    );

    final result = await receiver.receive(
      frame: frame,
      pairingSecret: 'wrong-secret',
    );

    expect(result.received, isFalse);
    expect(result.message, startsWith('Receive failed:'));
  });

  test('receive controller handles frames from the relay stream', () async {
    final frames = StreamController<PayloadFrame>();
    final results = <PayloadReceiveResult>[];
    final resultCompleter = Completer<void>();
    final clipboard = FakeAndroidClipboard();
    final controller = PayloadReceiveController(
      frames: frames.stream,
      pairingSecret: 'pairing-secret',
      receiver: PayloadReceiver(
        crypto: PayloadCrypto(),
        clipboard: clipboard,
        notifier: FakePayloadNotifier(),
        receivedTextRepository: ReceivedTextRepository(
          MemoryReceivedTextStorage(),
        ),
      ),
      onResult: (result) {
        results.add(result);
        resultCompleter.complete();
      },
    );
    final frame = await PayloadCrypto().encrypt(
      metadata: const PayloadMetadata(
        type: PayloadType.text,
        mime: 'text/plain',
        origin: 'laptop',
        ts: 1800000400003,
      ),
      plaintext: 'from stream'.codeUnits,
      pairingSecret: 'pairing-secret',
    );

    controller.start();
    frames.add(frame);
    await resultCompleter.future;

    expect(clipboard.text, 'from stream');
    expect(results.single.received, isTrue);
    await controller.dispose();
    await frames.close();
  });
}

class FakeAndroidClipboard implements AndroidClipboard {
  String? text;

  @override
  Future<void> writeText(String text) async {
    this.text = text;
  }
}

class ThrowingAndroidClipboard implements AndroidClipboard {
  @override
  Future<void> writeText(String text) async {
    throw StateError('Background clipboard access denied.');
  }
}

class FakePayloadNotifier implements PayloadNotifier {
  final textPreviews = <String>[];
  final imageMimes = <String>[];

  @override
  Future<void> showTextReady(String preview) async {
    textPreviews.add(preview);
  }

  @override
  Future<void> showImageReady(String mime) async {
    imageMimes.add(mime);
  }
}
