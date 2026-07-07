import 'dart:convert';

enum PayloadType {
  image('image'),
  text('text');

  const PayloadType(this.wireName);

  final String wireName;

  static PayloadType parse(String value) {
    return PayloadType.values.firstWhere(
      (type) => type.wireName == value,
      orElse: () => throw FormatException('Unsupported payload type: $value'),
    );
  }
}

class PayloadMetadata {
  const PayloadMetadata({
    required this.type,
    required this.mime,
    required this.origin,
    required this.ts,
  });

  final PayloadType type;
  final String mime;
  final String origin;
  final int ts;
}

class PayloadFrame {
  const PayloadFrame({
    required this.type,
    required this.mime,
    required this.origin,
    required this.ts,
    required this.nonce,
    required this.payload,
    this.v = 1,
  });

  final int v;
  final PayloadType type;
  final String mime;
  final String origin;
  final int ts;
  final String nonce;
  final String payload;

  @override
  bool operator ==(Object other) {
    return other is PayloadFrame &&
        other.v == v &&
        other.type == type &&
        other.mime == mime &&
        other.origin == origin &&
        other.ts == ts &&
        other.nonce == nonce &&
        other.payload == payload;
  }

  @override
  int get hashCode => Object.hash(v, type, mime, origin, ts, nonce, payload);

  Map<String, Object?> toJson() => {
    'v': v,
    'type': type.wireName,
    'mime': mime,
    'origin': origin,
    'ts': ts,
    'nonce': nonce,
    'payload': payload,
  };

  Map<String, Object?> associatedDataJson() => {
    'v': v,
    'type': type.wireName,
    'mime': mime,
    'origin': origin,
    'ts': ts,
    'nonce': nonce,
  };

  String associatedData() => jsonEncode(associatedDataJson());

  PayloadFrame copyWith({
    int? v,
    PayloadType? type,
    String? mime,
    String? origin,
    int? ts,
    String? nonce,
    String? payload,
  }) {
    return PayloadFrame(
      v: v ?? this.v,
      type: type ?? this.type,
      mime: mime ?? this.mime,
      origin: origin ?? this.origin,
      ts: ts ?? this.ts,
      nonce: nonce ?? this.nonce,
      payload: payload ?? this.payload,
    );
  }

  static PayloadFrame fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Payload frame must be an object.');
    }
    return PayloadFrame(
      v: _intField(value, 'v'),
      type: PayloadType.parse(_stringField(value, 'type')),
      mime: _stringField(value, 'mime'),
      origin: _stringField(value, 'origin'),
      ts: _intField(value, 'ts'),
      nonce: _stringField(value, 'nonce'),
      payload: _stringField(value, 'payload'),
    );
  }
}

int _intField(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! int) throw FormatException('$field must be an integer.');
  return value;
}

String _stringField(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.isEmpty) {
    throw FormatException('$field must be a string.');
  }
  return value;
}
