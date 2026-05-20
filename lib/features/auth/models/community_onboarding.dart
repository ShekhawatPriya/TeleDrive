class CommunityTarget {
  const CommunityTarget({
    required this.label,
    required this.name,
    required this.kind,
  });

  final String label;
  final String name;
  final String kind;

  factory CommunityTarget.fromJson(Map<String, dynamic> json) {
    return CommunityTarget(
      label: '${json['label'] ?? 'Community'}',
      name: '${json['name'] ?? ''}',
      kind: '${json['kind'] ?? 'community'}',
    );
  }
}

class CommunityJoinResult {
  const CommunityJoinResult({
    required this.status,
    this.error,
    this.targets = const [],
  });

  final String status;
  final String? error;
  final List<CommunityTarget> targets;

  factory CommunityJoinResult.fromJson(Map<String, dynamic> json) {
    final rawTargets = json['targets'];
    return CommunityJoinResult(
      status: '${json['status'] ?? 'failed'}',
      error: json['error'] == null ? null : '${json['error']}',
      targets: rawTargets is List
          ? rawTargets
                .whereType<Map>()
                .map(
                  (item) =>
                      CommunityTarget.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }
}
