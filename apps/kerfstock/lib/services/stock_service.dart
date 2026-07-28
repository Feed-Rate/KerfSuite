import 'package:supabase_flutter/supabase_flutter.dart';

class StockService {
  static final _client = Supabase.instance.client;

  /// Subscribe to asset changes for one workspace.
  static RealtimeChannel subscribeToAssets(
    String workspaceId,
    void Function() onUpdate,
    void Function(RealtimeSubscribeStatus status, Object? error)? onStatus,
  ) {
    final channel = _client.channel('assets_changes:$workspaceId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'assets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'workspace_id',
            value: workspaceId,
          ),
          callback: (payload) {
            onUpdate();
          },
        )
        .subscribe(onStatus);
    return channel;
  }
}
