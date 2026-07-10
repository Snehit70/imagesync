import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imagesync/src/receive/payload_receiver.dart';
import 'package:imagesync/src/receive/received_image_repository.dart';
import 'package:imagesync/src/receive/received_text_repository.dart';
import 'package:imagesync/src/shared/payload_crypto.dart';
import 'package:imagesync/src/shared/wire.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('imagesync_receive_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  ReceivedImageRepository imageRepository(ReceivedPayloadStorage storage) {
    return ReceivedImageRepository(
      storage,
      directoryProvider: () async => tempDir,
    );
  }

  test(
    'decrypts incoming text, stores it, and writes the Android clipboard',
    () async {
      final clipboard = FakeAndroidClipboard();
      final notifier = FakePayloadNotifier();
      final storage = MemoryReceivedPayloadStorage();
      final receiver = PayloadReceiver(
        crypto: PayloadCrypto(),
        clipboard: clipboard,
        imageClipboard: FakeAndroidImageClipboard(),
        notifier: notifier,
        receivedTextRepository: ReceivedTextRepository(storage),
        receivedImageRepository: imageRepository(storage),
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
      final storage = MemoryReceivedPayloadStorage();
      final receiver = PayloadReceiver(
        crypto: PayloadCrypto(),
        clipboard: ThrowingAndroidClipboard(),
        imageClipboard: FakeAndroidImageClipboard(),
        notifier: notifier,
        receivedTextRepository: ReceivedTextRepository(storage),
        receivedImageRepository: imageRepository(storage),
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
    'stores an incoming image and writes it to the clipboard when allowed',
    () async {
      final imageClipboard = FakeAndroidImageClipboard();
      final notifier = FakePayloadNotifier();
      final storage = MemoryReceivedPayloadStorage();
      final receiver = PayloadReceiver(
        crypto: PayloadCrypto(),
        clipboard: FakeAndroidClipboard(),
        imageClipboard: imageClipboard,
        notifier: notifier,
        receivedTextRepository: ReceivedTextRepository(storage),
        receivedImageRepository: imageRepository(storage),
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
      expect(result.message, 'Image copied from laptop.');
      expect(notifier.imageMimes.single, 'image/png');
      final written = imageClipboard.images.single;
      expect(written.mime, 'image/png');
      expect(await File(written.path).readAsBytes(), [1, 2, 3, 4]);
      final stored = await imageRepository(storage).loadLatest();
      expect(stored?.path, written.path);
    },
  );

  test(
    'still receives an image when the background clipboard write is rejected',
    () async {
      final notifier = FakePayloadNotifier();
      final storage = MemoryReceivedPayloadStorage();
      final receiver = PayloadReceiver(
        crypto: PayloadCrypto(),
        clipboard: FakeAndroidClipboard(),
        imageClipboard: ThrowingAndroidImageClipboard(),
        notifier: notifier,
        receivedTextRepository: ReceivedTextRepository(storage),
        receivedImageRepository: imageRepository(storage),
      );
      final frame = await PayloadCrypto().encrypt(
        metadata: const PayloadMetadata(
          type: PayloadType.image,
          mime: 'image/jpeg',
          origin: 'laptop',
          ts: 1800000400005,
        ),
        plaintext: [9, 8, 7],
        pairingSecret: 'pairing-secret',
      );

      final result = await receiver.receive(
        frame: frame,
        pairingSecret: 'pairing-secret',
      );

      expect(result.received, isTrue);
      expect(result.message, 'Image received. Tap the notification to copy.');
      expect(notifier.imageMimes.single, 'image/jpeg');
      final stored = await imageRepository(storage).loadLatest();
      expect(stored?.mime, 'image/jpeg');
      expect(await File(stored!.path).readAsBytes(), [9, 8, 7]);
    },
  );

  test('reports a clear receive failure for a wrong pairing secret', () async {
    final storage = MemoryReceivedPayloadStorage();
    final receiver = PayloadReceiver(
      crypto: PayloadCrypto(),
      clipboard: FakeAndroidClipboard(),
      imageClipboard: FakeAndroidImageClipboard(),
      notifier: FakePayloadNotifier(),
      receivedTextRepository: ReceivedTextRepository(storage),
      receivedImageRepository: imageRepository(storage),
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
    final storage = MemoryReceivedPayloadStorage();
    final controller = PayloadReceiveController(
      frames: frames.stream,
      pairingSecret: 'pairing-secret',
      receiver: PayloadReceiver(
        crypto: PayloadCrypto(),
        clipboard: clipboard,
        imageClipboard: FakeAndroidImageClipboard(),
        notifier: FakePayloadNotifier(),
        receivedTextRepository: ReceivedTextRepository(storage),
        receivedImageRepository: imageRepository(storage),
      ),
      onResult: (frame, result) {
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

class FakeAndroidImageClipboard implements AndroidImageClipboard {
  final images = <ReceivedImage>[];

  @override
  Future<void> writeImage(ReceivedImage image) async {
    images.add(image);
  }
}

class ThrowingAndroidImageClipboard implements AndroidImageClipboard {
  @override
  Future<void> writeImage(ReceivedImage image) async {
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
