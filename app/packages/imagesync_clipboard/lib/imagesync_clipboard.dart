import 'package:flutter/services.dart';

/// Dart face of the `imagesync/clipboard` MethodChannel.
///
/// The native side registers from application context via a [FlutterPlugin],
/// so these calls work in every isolate — the UI isolate and the headless
/// foreground-service isolate alike.
class ImagesyncClipboard {
  const ImagesyncClipboard();

  static const MethodChannel channel = MethodChannel('imagesync/clipboard');

  /// [PlatformException.code] when the OS rejected the write with a
  /// SecurityException — MIUI's privacy layer blocking background clipboard
  /// access, not a wiring bug.
  static const blockedErrorCode = 'clipboard-blocked';

  Future<void> writeText(String text) {
    return channel.invokeMethod<void>('writeText', {'text': text});
  }

  Future<void> writeImage({required String path, required String mime}) {
    return channel.invokeMethod<void>('writeImage', {
      'path': path,
      'mime': mime,
    });
  }

  /// Opens the MIUI permission editor for this app, falling back to the
  /// standard app-details settings screen where that intent doesn't resolve.
  Future<void> openClipboardPermissionSettings() {
    return channel.invokeMethod<void>('openClipboardPermissionSettings');
  }
}
