import '../../core/network/api_client.dart';
import '../../models/share_models.dart';

class ShareRepository {
  ShareRepository(this.api);

  final ApiClient api;

  Future<Share> createShare({
    required List<ShareItemRequest> items,
  }) async {
    final res = await api.dio.post(
      '/shares',
      data: {
        'items': items.map((i) => i.toJson()).toList(),
      },
    );
    return Share.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<Share>> listShares() async {
    final res = await api.dio.get('/shares');
    final data = Map<String, dynamic>.from(res.data as Map);
    final rows = (data['shares'] as List? ?? const []);
    return rows
        .map((e) => Share.fromListJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Share> getShare(String id) async {
    final res = await api.dio.get('/shares/$id');
    return Share.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> revokeShare(String id) async {
    await api.dio.delete('/shares/$id');
  }

  Future<int> revokeForFile(String fileId) async {
    final res = await api.dio.post(
      '/shares/revoke-for-file',
      data: {'file_id': int.parse(fileId)},
    );
    return ((res.data as Map?)?['revoked'] as num?)?.toInt() ?? 0;
  }

  Future<int> revokeForFolder(String folderId) async {
    final res = await api.dio.post(
      '/shares/revoke-for-folder',
      data: {'folder_id': int.parse(folderId)},
    );
    return ((res.data as Map?)?['revoked'] as num?)?.toInt() ?? 0;
  }

  Future<({List<ShareAccess> accesses, String? nextCursor})> listAccesses(
    String shareId, {
    bool includeBots = false,
    int limit = 50,
    String? cursor,
  }) async {
    final res = await api.dio.get(
      '/shares/$shareId/accesses',
      queryParameters: {
        'include_bots': includeBots,
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final rows = (data['accesses'] as List? ?? const [])
        .map((e) => ShareAccess.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return (accesses: rows, nextCursor: data['nextCursor'] as String?);
  }

  Future<ShareStats> getStats(String shareId, {int days = 30}) async {
    final res = await api.dio.get(
      '/shares/$shareId/stats',
      queryParameters: {'days': days},
    );
    return ShareStats.fromJson(Map<String, dynamic>.from(res.data as Map));
  }
}
