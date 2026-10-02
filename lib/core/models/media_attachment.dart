import 'dart:typed_data';

class MediaAttachment {
  final String id;
  final String? localPath;
  final Uint8List? bytes;
  final String? storagePath;
  final String? url;
  final String? caption;
  final int sortOrder;

  const MediaAttachment({
    required this.id,
    this.localPath,
    this.bytes,
    this.storagePath,
    this.url,
    this.caption,
    this.sortOrder = 0,
  });

  MediaAttachment copyWith({
    String? id,
    String? localPath,
    Uint8List? bytes,
    String? storagePath,
    String? url,
    String? caption,
    int? sortOrder,
  }) {
    return MediaAttachment(
      id: id ?? this.id,
      localPath: localPath ?? this.localPath,
      bytes: bytes ?? this.bytes,
      storagePath: storagePath ?? this.storagePath,
      url: url ?? this.url,
      caption: caption ?? this.caption,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  factory MediaAttachment.fromJson(Map<String, dynamic> json) {
    return MediaAttachment(
      id: json['id'] as String,
      storagePath: json['storage_path'] as String?,
      url: json['url'] as String?,
      caption: json['caption'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storage_path': storagePath,
      'url': url,
      'caption': caption,
      'sort_order': sortOrder,
    };
  }
}
