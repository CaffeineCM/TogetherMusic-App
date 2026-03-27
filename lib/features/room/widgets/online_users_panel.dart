import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/message.dart';
import '../providers/room_provider.dart';
import 'glass_panel.dart';

class OnlineUsersPanel extends ConsumerWidget {
  const OnlineUsersPanel({super.key});

  Future<bool> _confirmAction({
    required BuildContext context,
    required String title,
    required String content,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(roomProvider);
    final theme = Theme.of(context);
    final users = roomState.onlineUsers;
    final room = roomState.currentRoom;
    final currentSessionId = room?.currentSessionId ?? '';
    final viewerIsOwner = room?.isOwner ?? false;
    final viewerIsManager = room?.isManager ?? false;
    final roomNotifier = ref.read(roomProvider.notifier);

    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                if (viewerIsManager) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '黑名单管理',
                    icon: const Icon(Icons.gpp_bad_outlined, size: 18),
                    onPressed: () {
                      roomNotifier.showBlackUsers();
                      showDialog<void>(
                        context: context,
                        builder: (_) => const _BlacklistDialog(),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
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
                      return _UserListItem(
                        user: user,
                        isSelf: user.sessionId == currentSessionId,
                        viewerIsOwner: viewerIsOwner,
                        viewerIsManager:
                            viewerIsManager &&
                            user.sessionId != currentSessionId,
                        confirmAction:
                            ({
                              required title,
                              required content,
                              required confirmText,
                            }) => _confirmAction(
                              context: context,
                              title: title,
                              content: content,
                              confirmText: confirmText,
                            ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BlacklistDialog extends ConsumerWidget {
  const _BlacklistDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blacklistedUsers = ref.watch(
      roomProvider.select((state) => state.blacklistedUsers),
    );
    final roomNotifier = ref.read(roomProvider.notifier);

    return AlertDialog(
      title: const Text('用户黑名单'),
      content: SizedBox(
        width: 420,
        child: blacklistedUsers.isEmpty
            ? const Text('暂无黑名单用户')
            : ListView.separated(
                shrinkWrap: true,
                itemCount: blacklistedUsers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final targetId = blacklistedUsers[index];
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          targetId,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => roomNotifier.unblackUser(targetId),
                        child: const Text('解除拉黑'),
                      ),
                    ],
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            roomNotifier.showBlackUsers();
          },
          child: const Text('刷新'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _UserListItem extends ConsumerWidget {
  final OnlineUser user;
  final bool isSelf;
  final bool viewerIsOwner;
  final bool viewerIsManager;
  final Future<bool> Function({
    required String title,
    required String content,
    required String confirmText,
  })
  confirmAction;

  const _UserListItem({
    required this.user,
    required this.isSelf,
    required this.viewerIsOwner,
    required this.viewerIsManager,
    required this.confirmAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final roomNotifier = ref.read(roomProvider.notifier);

    final canGrantAdmin = viewerIsOwner && !user.isOwner && !user.isAdmin;
    final canRevokeAdmin = viewerIsOwner && user.isAdmin;
    final canKickOrBlack =
        viewerIsManager && !user.isOwner && !(user.isAdmin && !viewerIsOwner);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: _avatarColor(theme),
        child: Text(
          user.displayName.isNotEmpty
              ? user.displayName.substring(0, 1).toUpperCase()
              : '?',
          style: TextStyle(fontSize: 12, color: _avatarTextColor(theme)),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              user.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: user.isManager ? FontWeight.bold : null,
              ),
            ),
          ),
          if (isSelf)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                '我',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      subtitle: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _RoleChip(label: user.roleLabel, color: _roleChipColor(theme)),
          _RoleChip(
            label: user.accountLabel,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
      trailing: (canGrantAdmin || canRevokeAdmin || canKickOrBlack)
          ? PopupMenuButton<String>(
              tooltip: '用户操作',
              onSelected: (value) async {
                if (value == 'grant-admin') {
                  final confirmed = await confirmAction(
                    title: '设置管理员',
                    content: '确认将「${user.displayName}」设置为管理员吗？',
                    confirmText: '确认设置',
                  );
                  if (!confirmed) return;
                  roomNotifier.grantAdmin(user.sessionId);
                }
                if (value == 'revoke-admin') {
                  final confirmed = await confirmAction(
                    title: '取消管理员',
                    content: '确认取消「${user.displayName}」的管理员权限吗？',
                    confirmText: '确认取消',
                  );
                  if (!confirmed) return;
                  roomNotifier.revokeAdmin(user.sessionId);
                }
                if (value == 'kick') {
                  final confirmed = await confirmAction(
                    title: '踢出用户',
                    content: '确认将「${user.displayName}」踢出房间吗？',
                    confirmText: '确认踢出',
                  );
                  if (!confirmed) return;
                  roomNotifier.kickUser(user.sessionId);
                }
                if (value == 'black') {
                  final confirmed = await confirmAction(
                    title: '拉黑用户',
                    content: '确认拉黑「${user.displayName}」并踢出房间吗？',
                    confirmText: '确认拉黑',
                  );
                  if (!confirmed) return;
                  roomNotifier.blackUser(user.sessionId);
                }
              },
              itemBuilder: (context) => [
                if (canGrantAdmin)
                  const PopupMenuItem<String>(
                    value: 'grant-admin',
                    child: Text('设为管理员'),
                  ),
                if (canRevokeAdmin)
                  const PopupMenuItem<String>(
                    value: 'revoke-admin',
                    child: Text('取消管理员'),
                  ),
                if (canKickOrBlack)
                  const PopupMenuItem<String>(
                    value: 'kick',
                    child: Text('踢出房间'),
                  ),
                if (canKickOrBlack)
                  const PopupMenuItem<String>(
                    value: 'black',
                    child: Text('拉黑并踢出'),
                  ),
              ],
            )
          : null,
    );
  }

  Color _avatarColor(ThemeData theme) {
    if (user.isOwner) return theme.colorScheme.secondary;
    if (user.isAdmin) return theme.colorScheme.primary;
    return theme.colorScheme.primaryContainer;
  }

  Color _avatarTextColor(ThemeData theme) {
    if (user.isOwner) return theme.colorScheme.onSecondary;
    if (user.isAdmin) return theme.colorScheme.onPrimary;
    return theme.colorScheme.onPrimaryContainer;
  }

  Color _roleChipColor(ThemeData theme) {
    if (user.isOwner) return theme.colorScheme.secondaryContainer;
    if (user.isAdmin) return theme.colorScheme.primaryContainer;
    return theme.colorScheme.surfaceContainerHighest;
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final Color color;

  const _RoleChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}
