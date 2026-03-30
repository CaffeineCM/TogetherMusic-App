import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/music.dart';
import '../../../core/network/image_headers.dart';
import '../providers/room_provider.dart';
import 'glass_panel.dart';

class QueuePanel extends ConsumerWidget {
  final VoidCallback onOpenPick;

  const QueuePanel({super.key, required this.onOpenPick});

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
    final theme = Theme.of(context);
    final roomState = ref.watch(roomProvider);
    final pickList = roomState.pickList;
    final canManageQueue = roomState.currentRoom?.isManager ?? false;
    final roomNotifier = ref.read(roomProvider.notifier);

    return GlassPanel(
      margin: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.queue_music_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  '播放列表',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${pickList.length} 首', style: theme.textTheme.bodySmall),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: onOpenPick,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('点歌'),
                ),
                const SizedBox(width: 6),
                if (canManageQueue)
                  PopupMenuButton<String>(
                    tooltip: '更多操作',
                    onSelected: (value) async {
                      if (value == 'clear') {
                        final confirmed = await _confirmAction(
                          context: context,
                          title: '清空播放列表',
                          content: '该操作不可恢复，确认继续？',
                          confirmText: '确认清空',
                        );
                        if (!confirmed) return;
                        roomNotifier.clearPickList();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'clear',
                        child: Text('清空列表'),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.more_horiz_rounded),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          Expanded(
            child: pickList.isEmpty
                ? _QueueEmpty(onOpenPick: onOpenPick)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: pickList.length,
                    itemBuilder: (context, index) {
                      final music = pickList[index];
                      final isCurrent = index == 0;
                      return _QueueTile(
                        music: music,
                        isCurrent: isCurrent,
                        onLike: () => roomNotifier.likeMusic(music.id),
                        onDelete: () => roomNotifier.deleteMusic(music.id),
                        onTop: !canManageQueue || isCurrent
                            ? null
                            : () => roomNotifier.topMusic(music.id),
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

class _QueueEmpty extends StatelessWidget {
  final VoidCallback onOpenPick;

  const _QueueEmpty({required this.onOpenPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 34,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.48),
            ),
            const SizedBox(height: 8),
            Text(
              '当前还没有歌曲，去点歌台添加吧',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onOpenPick,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('打开点歌台'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final Music music;
  final bool isCurrent;
  final VoidCallback onLike;
  final VoidCallback onDelete;
  final VoidCallback? onTop;
  final Future<bool> Function({
    required String title,
    required String content,
    required String confirmText,
  })
  confirmAction;

  const _QueueTile({
    required this.music,
    required this.isCurrent,
    required this.onLike,
    required this.onDelete,
    this.onTop,
    required this.confirmAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey('queue-${music.id}-${music.pickTime ?? 0}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (direction) async {
        final confirmed = await confirmAction(
          title: '移出歌曲',
          content: '确认将「${music.name}」移出播放列表吗？',
          confirmText: '确认移出',
        );
        if (!confirmed) return false;
        onDelete();
        return false;
      },
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        selected: isCurrent,
        selectedTileColor: theme.colorScheme.primaryContainer.withValues(
          alpha: 0.24,
        ),
        leading: Stack(
          children: [
            _buildCover(),
            if (isCurrent)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    size: 12,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          music.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: isCurrent
              ? const TextStyle(fontWeight: FontWeight.w700)
              : null,
        ),
        subtitle: Text(
          music.artist ?? '未知艺术家',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (music.likedUserIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${music.likedUserIds.length}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.thumb_up_outlined),
              iconSize: 20,
              onPressed: onLike,
            ),
            PopupMenuButton<String>(
              tooltip: '歌曲操作',
              onSelected: (value) async {
                if (value == 'top' && onTop != null) {
                  final confirmed = await confirmAction(
                    title: '置顶歌曲',
                    content: '确认将「${music.name}」置顶到下一首播放吗？',
                    confirmText: '确认置顶',
                  );
                  if (!confirmed) return;
                  onTop!();
                } else if (value == 'delete') {
                  final confirmed = await confirmAction(
                    title: '移出歌曲',
                    content: '确认将「${music.name}」移出播放列表吗？',
                    confirmText: '确认移出',
                  );
                  if (!confirmed) return;
                  onDelete();
                }
              },
              itemBuilder: (context) => [
                if (onTop != null)
                  const PopupMenuItem<String>(
                    value: 'top',
                    child: Text('置顶到下一首'),
                  ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('移出列表'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover() {
    if (music.pictureUrl == null) {
      return const Icon(Icons.music_note, size: 38);
    }

    return Image.network(
      music.pictureUrl!,
      headers: musicImageHeaders,
      width: 38,
      height: 38,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.music_note, size: 38),
    );
  }
}
