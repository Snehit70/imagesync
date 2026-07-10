import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../debug/debug_log.dart';
import '../share/share_payload.dart';
import '../share/share_publisher.dart';

abstract interface class ClipboardReader {
  Future<String?> readText();
}

abstract interface class ClipboardSharePublisher {
  Future<SharePublishResult> publish(SharePayload payload);
}

class FlutterClipboardReader implements ClipboardReader {
  const FlutterClipboardReader();

  @override
  Future<String?> readText() async {
    return (await Clipboard.getData('text/plain'))?.text;
  }
}

class SharePublisherAdapter implements ClipboardSharePublisher {
  const SharePublisherAdapter(this._publisher);

  final SharePublisher _publisher;

  @override
  Future<SharePublishResult> publish(SharePayload payload) {
    return _publisher.publish(payload);
  }
}

class SendClipboardScreen extends StatefulWidget {
  const SendClipboardScreen({
    super.key,
    required this.clipboardReader,
    required this.publisher,
    this.debugLog,
  });

  final ClipboardReader clipboardReader;
  final ClipboardSharePublisher publisher;
  final DebugLog? debugLog;

  @override
  State<SendClipboardScreen> createState() => _SendClipboardScreenState();
}

class _SendClipboardScreenState extends State<SendClipboardScreen> {
  String _message = 'Reading clipboard...';
  bool _working = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendClipboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send clipboard')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_working) const CircularProgressIndicator(),
              if (_working) const SizedBox(height: 18),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendClipboard() async {
    final text = await widget.clipboardReader.readText();
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      setState(() {
        _working = false;
        _message = 'Clipboard is empty.';
      });
      return;
    }

    final result = await widget.publisher.publish(SharePayload.text(text));
    widget.debugLog?.add(
      'send',
      result.published
          ? 'Clipboard text (${text.length} chars) sent to laptop.'
          : result.message,
      isError: !result.published,
    );
    if (!mounted) return;
    setState(() {
      _working = false;
      _message = result.published
          ? 'Clipboard sent to laptop.'
          : result.message;
    });
  }
}
