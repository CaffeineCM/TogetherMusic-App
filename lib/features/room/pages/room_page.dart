import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/playback_snapshot.dart';
import '../providers/player_provider.dart';
import '../providers/room_provider.dart';
import '../widgets/chat_panel.dart';
import '../widgets/online_users_panel.dart';
import '../widgets/pick_panel.dart';
import '../widgets/player_widget.dart';

/// 房间主页面
/// 包含播放器、点歌面板、聊天面板、在线用户列表
class RoomPage extends ConsumerStatefulWidget {
  final String houseId;

  const RoomPage({super.key, required this.houseId});

  @override
  ConsumerState<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends ConsumerState<RoomPage> {
  int _selectedIndex = 0;
  RoomNotifier? _roomNotifier;

  @override
  void initState() {
    super.initState();
    _roomNotifier = ref.read(roomProvider.notifier);
    // 确保已加入房间
    Future.microtask(() {
      final roomState = ref.read(roomProvider);
      if (roomState.currentHouseId != widget.houseId) {
        _roomNotifier?.enterRoom(houseId: widget.houseId);
      }
    });
  }

  @override
  void dispose() {
    final roomNotifier = _roomNotifier;
    if (roomNotifier != null) {
      roomNotifier.leaveRoom();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);
    final authState = ref.watch(authProvider);

    // 监听错误
    ref.listen(roomProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
        ref.read(roomProvider.notifier).clearError();
      }

      final latestPlayback = next.playbackSnapshot;
      final previousPlayback = previous?.playbackSnapshot;
      final changedPlayback =
          latestPlayback?.music?.id != previousPlayback?.music?.id ||
          latestPlayback?.updatedAt != previousPlayback?.updatedAt ||
          latestPlayback?.positionMs != previousPlayback?.positionMs ||
          latestPlayback?.status != previousPlayback?.status;

      if (latestPlayback != null && changedPlayback) {
        ref.read(playerProvider.notifier).syncPlayback(latestPlayback);
      } else {
        final latestPlaying = next.currentPlaying;
        final previousPlaying = previous?.currentPlaying;
        final changedTrack =
            latestPlaying?.id != previousPlaying?.id ||
            latestPlaying?.pushTime != previousPlaying?.pushTime;
        if (latestPlaying != null && changedTrack) {
          ref.read(playerProvider.notifier).syncSnapshot(latestPlaying);
        }
      }
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(roomState.currentRoom?.name ?? '房间 ${widget.houseId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            ref.read(roomProvider.notifier).leaveRoom();
            context.pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: '点歌',
            onPressed: () => _openPickDialog(context),
          ),
          // 投票切歌按钮
          IconButton(
            icon: const Icon(Icons.skip_next_rounded),
            tooltip: '投票切歌',
            onPressed: () => ref.read(roomProvider.notifier).voteSkip(),
          ),
          // 用户菜单
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  if (authState.isLoggedIn) {
                    context.push('/profile');
                  } else {
                    context.push('/login');
                  }
                  break;
                case 'logout':
                  ref.read(authProvider.notifier).logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person),
                    const SizedBox(width: 8),
                    Text(authState.isLoggedIn ? '个人中心' : '登录'),
                  ],
                ),
              ),
              if (authState.isLoggedIn)
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('退出登录'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0911), Color(0xFF16121F), Color(0xFF0A0D15)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -140,
              left: -100,
              child: _GlowOrb(size: 320, color: Color(0xFFA489FF)),
            ),
            const Positioned(
              right: -120,
              top: 120,
              child: _GlowOrb(size: 300, color: Color(0xFF6DB7FF)),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      return _buildWideLayout();
                    } else if (constraints.maxWidth > 600) {
                      return _buildMediumLayout();
                    } else {
                      return _buildNarrowLayout();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width <= 600
          ? NavigationBar(
              backgroundColor: const Color(0xFF15121D),
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.play_circle_outline),
                  label: '播放',
                ),
                NavigationDestination(
                  icon: Icon(Icons.queue_music),
                  label: '点歌',
                ),
                NavigationDestination(icon: Icon(Icons.chat), label: '聊天'),
                NavigationDestination(icon: Icon(Icons.people), label: '用户'),
              ],
            )
          : null,
    );
  }

  /// 宽屏布局（桌面端）
  Widget _buildWideLayout() {
    return Row(
      children: [
        // 左侧：播放器 + 点歌入口
        Expanded(
          flex: 2,
          child: Column(
            children: [
              const Expanded(flex: 3, child: PlayerWidget()),
              Expanded(
                child: _PickLauncherCard(
                  onOpen: () => _openPickDialog(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // 右侧：聊天 + 在线用户
        Expanded(
          flex: 1,
          child: Column(
            children: const [
              Expanded(flex: 2, child: ChatPanel()),
              Expanded(flex: 1, child: OnlineUsersPanel()),
            ],
          ),
        ),
      ],
    );
  }

  /// 中屏布局（平板）
  Widget _buildMediumLayout() {
    return Row(
      children: [
        // 左侧：播放器 + 点歌入口
        Expanded(
          child: Column(
            children: [
              const Expanded(flex: 2, child: PlayerWidget()),
              Expanded(
                child: _PickLauncherCard(
                  onOpen: () => _openPickDialog(context),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // 右侧：聊天
        const Expanded(child: ChatPanel()),
      ],
    );
  }

  /// 窄屏布局（手机）
  Widget _buildNarrowLayout() {
    switch (_selectedIndex) {
      case 0:
        return Column(
          children: [
            const Expanded(child: PlayerWidget()),
            _PickLauncherCard(onOpen: () => _openPickDialog(context)),
          ],
        );
      case 1:
        return _PickLauncherCard(onOpen: () => _openPickDialog(context));
      case 2:
        return const ChatPanel();
      case 3:
        return const OnlineUsersPanel();
      default:
        return Column(
          children: [
            const Expanded(child: PlayerWidget()),
            _PickLauncherCard(onOpen: () => _openPickDialog(context)),
          ],
        );
    }
  }

  Future<void> _openPickDialog(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;
    final dialogWidth = width > 1100 ? 980.0 : width - 32;
    final dialogHeight = height > 900 ? 760.0 : height - 48;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2D2B35),
                  Color(0xFF3C3946),
                  Color(0xFF25232C),
                ],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.queue_music_rounded),
                      const SizedBox(width: 10),
                      Text(
                        '点歌台',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: PickPanel(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.26),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickLauncherCard extends StatelessWidget {
  final VoidCallback onOpen;

  const _PickLauncherCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D2B35), Color(0xFF3A3744)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF8FB6FF).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.queue_music_rounded),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '打开点歌台',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '搜索、歌单、排行榜统一放到弹窗里操作',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('点歌'),
            ),
          ],
        ),
      ),
    );
  }
}
