import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/message.dart';
import '../providers/room_provider.dart';

const _kSupportedSources = ['wy', 'qq', 'kg'];

String _sourceLabel(String source) => switch (source) {
      'wy' => '网易云音乐',
      'qq' => 'QQ 音乐',
      'kg' => '酷狗音乐',
      _ => source,
    };

/// 房间设置对话框 - 各音乐源独立授权管理
class RoomSettingsDialog extends ConsumerStatefulWidget {
  const RoomSettingsDialog({super.key});

  @override
  ConsumerState<RoomSettingsDialog> createState() => _RoomSettingsDialogState();
}

class _RoomSettingsDialogState extends ConsumerState<RoomSettingsDialog> {
  /// source -> 是否正在操作中
  final Map<String, bool> _loadingMap = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(roomProvider.notifier).fetchTokenStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);
    final room = roomState.currentRoom;

    if (room == null) return const SizedBox.shrink();

    final isOwner = room.isOwner;
    final isAdmin = room.isAdmin;
    final tokenStatus = roomState.tokenStatus;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D2B35), Color(0xFF3C3946), Color(0xFF25232C)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 32,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const Divider(height: 1, color: Color(0x18FFFFFF)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: tokenStatus == null
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Column(
                        children: [
                          for (final source in _kSupportedSources) ...[
                            _SourceSection(
                              source: source,
                              status: tokenStatus.sources[source],
                              isOwner: isOwner,
                              isAdmin: isAdmin,
                              isLoading: _loadingMap[source] ?? false,
                              onLink: () => _setMyAccount(source),
                              onUnlink: () => _unlinkToken(source),
                            ),
                            if (source != _kSupportedSources.last)
                              const Divider(
                                height: 20,
                                color: Color(0x14FFFFFF),
                              ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, size: 22),
          const SizedBox(width: 10),
          Text(
            '音乐授权管理',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Future<void> _setMyAccount(String source) async {
    setState(() => _loadingMap[source] = true);
    ref.read(roomProvider.notifier).setRoomMusicSource(
      source: source,
      useMyAccount: true,
    );
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _loadingMap[source] = false);
  }

  Future<void> _unlinkToken(String source) async {
    setState(() => _loadingMap[source] = true);
    ref.read(roomProvider.notifier).unlinkToken(source: source);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _loadingMap[source] = false);
  }
}

class _SourceSection extends StatelessWidget {
  final String source;
  final SourceAuthStatus? status;
  final bool isOwner;
  final bool isAdmin;
  final bool isLoading;
  final VoidCallback onLink;
  final VoidCallback onUnlink;

  const _SourceSection({
    required this.source,
    required this.status,
    required this.isOwner,
    required this.isAdmin,
    required this.isLoading,
    required this.onLink,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final authorized = status?.creatorHasAuthorized ?? false;
    final hasHolder = status?.tokenHolderUserId != null;
    final adminCanAuthorize = status?.adminCanAuthorize ?? false;
    final holderName = status?.tokenHolderDisplayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 源名称 + 状态指示
        Row(
          children: [
            Text(
              _sourceLabel(source),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white87,
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(
              authorized: authorized,
              hasAdminHolder: !authorized && hasHolder,
            ),
          ],
        ),
        const SizedBox(height: 6),

        // 当前持有人
        if (hasHolder)
          _InfoRow(
            icon: Icons.person_rounded,
            text: authorized
                ? '房主授权（$holderName）'
                : '管理员授权（$holderName）',
            color: authorized
                ? const Color(0xFF6EE7A0)
                : const Color(0xFF89C4FF),
          )
        else
          const _InfoRow(
            icon: Icons.link_off_rounded,
            text: '未授权 - 使用系统默认',
            color: Colors.white38,
          ),

        const SizedBox(height: 10),

        // 操作按钮
        if (isOwner) ...[
          if (authorized)
            _SmallButton(
              label: '取消授权',
              icon: Icons.link_off_rounded,
              color: const Color(0xFFFF7676),
              loading: isLoading,
              onPressed: onUnlink,
            )
          else
            _SmallButton(
              label: '使用我的账号',
              icon: Icons.link_rounded,
              color: const Color(0xFF6EE7A0),
              loading: isLoading,
              onPressed: onLink,
            ),
        ] else if (isAdmin) ...[
          if (adminCanAuthorize)
            _SmallButton(
              label: '使用我的账号',
              icon: Icons.link_rounded,
              color: const Color(0xFF89C4FF),
              loading: isLoading,
              onPressed: onLink,
            )
          else
            const _InfoRow(
              icon: Icons.lock_outline_rounded,
              text: '房主已授权，暂不可设置',
              color: Colors.white30,
            ),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool authorized;
  final bool hasAdminHolder;

  const _StatusBadge({required this.authorized, required this.hasAdminHolder});

  @override
  Widget build(BuildContext context) {
    final (label, color) = authorized
        ? ('房主已授权', const Color(0xFF6EE7A0))
        : hasAdminHolder
            ? ('管理员授权', const Color(0xFF89C4FF))
            : ('未授权', Colors.white24);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12, color: color)),
        ),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onPressed;

  const _SmallButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: color.withValues(alpha: 0.28)),
          ),
        ),
        icon: loading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
              )
            : Icon(icon, size: 15),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
