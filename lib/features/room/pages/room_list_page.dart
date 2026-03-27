import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/room.dart';
import '../../../core/network/room_api.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/room_provider.dart';

class RoomListPage extends ConsumerStatefulWidget {
  const RoomListPage({super.key});

  @override
  ConsumerState<RoomListPage> createState() => _RoomListPageState();
}

class _RoomListPageState extends ConsumerState<RoomListPage> {
  ProviderSubscription<RoomState>? _roomStateSubscription;
  bool _isClearingDevData = false;

  @override
  void initState() {
    super.initState();
    _roomStateSubscription = ref.listenManual(roomProvider, (previous, next) {
      final previousRoomId = previous?.currentRoom?.id;
      final currentRoomId = next.currentRoom?.id;

      if (currentRoomId != null && currentRoomId != previousRoomId && mounted) {
        context.push('/room/$currentRoomId');
        return;
      }

      if (next.error != null && next.error != previous?.error && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
        ref.read(roomProvider.notifier).clearError();
      }
    });

    // 页面加载时获取房间列表
    Future.microtask(() {
      ref.read(roomProvider.notifier).fetchRoomList();
    });
  }

  @override
  void dispose() {
    _roomStateSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('房间列表'),
        actions: [
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: roomState.isLoading
                ? null
                : () => ref.read(roomProvider.notifier).fetchRoomList(),
          ),
          IconButton(
            icon: _isClearingDevData
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cleaning_services_outlined),
            tooltip: '开发清理',
            onPressed: _isClearingDevData
                ? null
                : () => _confirmClearDevData(context),
          ),
          // 用户菜单
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
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
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(roomState, theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _requireLoginForCreate(authState.isLoggedIn),
        icon: const Icon(Icons.add),
        label: const Text('创建房间'),
      ),
    );
  }

  Widget _buildBody(RoomState roomState, ThemeData theme) {
    if (roomState.isLoading && roomState.roomList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (roomState.error != null && roomState.roomList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              roomState.error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(roomProvider.notifier).fetchRoomList(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (roomState.roomList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.meeting_room,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无房间',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  _requireLoginForCreate(ref.read(authProvider).isLoggedIn),
              child: const Text('创建第一个房间'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(roomProvider.notifier).fetchRoomList(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: roomState.roomList.length,
        itemBuilder: (context, index) {
          final room = roomState.roomList[index];
          return _RoomCard(room: room, onTap: () => _onRoomTap(context, room));
        },
      ),
    );
  }

  void _onRoomTap(BuildContext context, RoomSummary room) {
    if (room.needPwd) {
      _showPasswordDialog(context, room);
    } else {
      _enterRoom(room.id);
    }
  }

  void _enterRoom(String houseId, {String? password}) {
    ref
        .read(roomProvider.notifier)
        .enterRoom(houseId: houseId, password: password);
  }

  void _showCreateRoomDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final passwordController = TextEditingController();
    bool needPassword = false;
    bool keepRoom = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('创建房间'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '房间名称',
                      hintText: '请输入房间名称',
                      prefixIcon: Icon(Icons.meeting_room),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入房间名称';
                      }
                      if (value.trim().length < 2) {
                        return '房间名称至少2位';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: '房间描述（可选）',
                      hintText: '请输入房间描述',
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('需要密码'),
                    value: needPassword,
                    onChanged: (value) {
                      setState(() => needPassword = value ?? false);
                    },
                  ),
                  if (needPassword)
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: '房间密码',
                        hintText: '请输入房间密码',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (needPassword && (value == null || value.isEmpty)) {
                          return '请输入房间密码';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('保留房间'),
                    subtitle: const Text('所有人离开后不自动销毁房间'),
                    value: keepRoom,
                    onChanged: (value) {
                      setState(() => keepRoom = value ?? false);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  _createRoom(
                    name: nameController.text.trim(),
                    desc: descController.text.trim().isEmpty
                        ? null
                        : descController.text.trim(),
                    password: needPassword ? passwordController.text : null,
                    keepRoom: keepRoom,
                  );
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  void _requireLoginForCreate(bool isLoggedIn) {
    if (isLoggedIn) {
      _showCreateRoomDialog(context);
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('创建房间前请先登录')));
    context.push('/login');
  }

  void _createRoom({
    required String name,
    String? desc,
    String? password,
    bool keepRoom = false,
  }) {
    ref
        .read(roomProvider.notifier)
        .createRoom(
          name: name,
          desc: desc,
          password: password,
          keepRoom: keepRoom,
        );
  }

  void _showPasswordDialog(BuildContext context, RoomSummary room) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('进入 ${room.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('该房间需要密码'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: '房间密码',
                hintText: '请输入密码',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final password = passwordController.text;
              Navigator.pop(context);
              _enterRoom(room.id, password: password);
            },
            child: const Text('进入'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearDevData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开发清理'),
        content: const Text('这会清空所有房间、在线状态和 IP 创建限制。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清理'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClearingDevData = true);
    final message = await RoomApi.clearDevRoomData();
    if (!mounted) return;

    setState(() => _isClearingDevData = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message ?? '清理完成')));
    await ref.read(roomProvider.notifier).fetchRoomList();
  }
}

/// 房间卡片
class _RoomCard extends StatelessWidget {
  final RoomSummary room;
  final VoidCallback onTap;

  const _RoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 房间图标
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.meeting_room,
                  size: 32,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              // 房间信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            room.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (room.needPwd)
                          Icon(
                            Icons.lock,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                    if (room.desc != null && room.desc!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        room.desc!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${room.population} 人在线',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 进入箭头
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
