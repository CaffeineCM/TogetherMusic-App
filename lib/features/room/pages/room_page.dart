import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../providers/room_provider.dart';
import '../widgets/chat_panel.dart';
import '../widgets/online_users_panel.dart';
import '../widgets/pick_panel.dart';
import '../widgets/player_widget.dart';
import '../widgets/queue_panel.dart';

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
                  label: '列表',
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
        // 左侧：播放器 + 播放列表
        Expanded(
          flex: 2,
          child: Column(
            children: [
              const Expanded(flex: 3, child: PlayerWidget()),
              Expanded(
                flex: 2,
                child: QueuePanel(onOpenPick: () => _openPickDialog(context)),
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
        // 左侧：播放器 + 播放列表
        Expanded(
          child: Column(
            children: [
              const Expanded(flex: 3, child: PlayerWidget()),
              Expanded(
                flex: 2,
                child: QueuePanel(onOpenPick: () => _openPickDialog(context)),
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
        return const PlayerWidget();
      case 1:
        return QueuePanel(onOpenPick: () => _openPickDialog(context));
      case 2:
        return const ChatPanel();
      case 3:
        return const OnlineUsersPanel();
      default:
        return const PlayerWidget();
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
