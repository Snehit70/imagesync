enum SharePayloadType { text, image }

class SharePayload {
  const SharePayload.text(this.text, {this.mime = 'text/plain'})
    : type = SharePayloadType.text,
      path = null;

  const SharePayload.image({required this.path, required this.mime})
    : type = SharePayloadType.image,
      text = null;

  final SharePayloadType type;
  final String mime;
  final String? text;
  final String? path;
}
