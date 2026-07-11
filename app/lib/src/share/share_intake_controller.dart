import 'dart:async';

import 'share_payload.dart';
import 'share_publisher.dart';
import 'share_source.dart';

typedef ShareStatusListener = void Function(
  SharePayload payload,
  SharePublishResult result,
);

class ShareIntakeController {
  ShareIntakeController({
    required this.source,
    required this.publisher,
    this.onResult,
  });

  final ShareSource source;
  final SharePublisher publisher;
  final ShareStatusListener? onResult;
  StreamSubscription<List<SharePayload>>? _subscription;

  Future<void> start() async {
    await _publishAll(await source.initialPayloads());
    await source.reset();
    _subscription = source.payloadStream().listen((payloads) {
      unawaited(_publishAll(payloads));
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }

  Future<void> _publishAll(List<SharePayload> payloads) async {
    for (final payload in payloads) {
      onResult?.call(payload, await publisher.publish(payload));
    }
  }
}
