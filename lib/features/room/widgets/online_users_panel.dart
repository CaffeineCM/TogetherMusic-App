import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/message.dart';
import '../providers/room_provider.dart';
import 'glass_panel.dart';

/// 在线用户列表面板
class OnlineUsersPanel extends ConsumerWidget {
  const OnlineUsersPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(roomProvider);
    final theme = Theme.of(context);

    final users = roomState.onlineUsers;

    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '在线用户',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${users.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),

          // 用户列表
          Expanded(
            child: users.isEmpty
                ? Center(
                    child: Text(
                      '暂无在线用户',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return _UserListItem(user: user);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 用户列表项
class _UserListItem extends StatelessWidget {
  final OnlineUser user;

  const _UserListItem({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: user.isAdmin
            ? theme.colorScheme.primary
            : theme.colorScheme.primaryContainer,
        child: Text(
          user.displayName.isNotEmpty
              ? user.displayName.substring(0, 1).toUpperCase()
              : '?',
          style: TextStyle(
            fontSize: 12,
            color: user.isAdmin
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(
        user.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: user.isAdmin ? FontWeight.bold : null,
          color: user.isAdmin ? theme.colorScheme.primary : null,
        ),
      ),
      subtitle: user.isGuest && user.remoteAddress != null
          ? Text(
              user.remoteAddress!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.52),
              ),
            )
          : null,
      trailing: user.isAdmin
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '管理员',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 10,
                ),
              ),
            )
          : null,
    );
  }
}
