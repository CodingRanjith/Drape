class AppNotice {
  AppNotice({
    required this.id,
    required this.title,
    this.body = '',
    DateTime? at,
    this.kind = 'update',
    this.read = false,
  }) : at = at ?? DateTime.now();

  final String id;
  final String title;
  final String body;
  final DateTime at;
  final String kind;
  bool read;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'at': at.toIso8601String(),
        'kind': kind,
        'read': read,
      };

  factory AppNotice.fromJson(Map<String, dynamic> json) => AppNotice(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Update',
        body: json['body'] as String? ?? '',
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        kind: json['kind'] as String? ?? 'update',
        read: json['read'] as bool? ?? false,
      );
}
