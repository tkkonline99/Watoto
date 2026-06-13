/// A queued offline operation, mirrored by the API's `POST /v1/sync/batch`
/// contract (docs/15-offline-sync.md §15.3).
class SyncOp {
  const SyncOp({
    required this.clientOpId,
    required this.opType,
    required this.payload,
    required this.clientUpdatedAt,
  });

  final String clientOpId;
  final String opType;
  final Map<String, dynamic> payload;
  final DateTime clientUpdatedAt;

  Map<String, dynamic> toJson() => {
        'clientOpId': clientOpId,
        'opType': opType,
        'payload': payload,
        'clientUpdatedAt': clientUpdatedAt.toIso8601String(),
      };

  factory SyncOp.fromJson(Map<String, dynamic> json) => SyncOp(
        clientOpId: json['clientOpId'] as String,
        opType: json['opType'] as String,
        payload: (json['payload'] as Map).cast<String, dynamic>(),
        clientUpdatedAt: DateTime.parse(json['clientUpdatedAt'] as String),
      );
}
