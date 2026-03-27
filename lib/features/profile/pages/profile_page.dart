import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/user.dart';
import '../../../core/network/music_account_api.dart';
import '../../auth/providers/auth_provider.dart';

/// 个人中心页面
/// 展示/编辑个人资料、上传列表
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nicknameController = TextEditingController();
  bool _isEditing = false;
  NeteaseAccountStatus? _neteaseStatus;
  bool _isLoadingNeteaseStatus = false;
  bool _isRefreshingNetease = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nicknameController.text = user?.nickname ?? user?.username ?? '';
    Future.microtask(_loadNeteaseStatus);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) return;

    await ref.read(authProvider.notifier).updateUserInfo(nickname: nickname);

    setState(() => _isEditing = false);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存成功')));
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _loadNeteaseStatus() async {
    setState(() => _isLoadingNeteaseStatus = true);
    try {
      final status = await MusicAccountApi.getNeteaseStatus();
      if (!mounted) return;
      setState(() => _neteaseStatus = status);
    } finally {
      if (mounted) {
        setState(() => _isLoadingNeteaseStatus = false);
      }
    }
  }

  Future<void> _refreshNeteaseStatus() async {
    setState(() => _isRefreshingNetease = true);
    try {
      final status = await MusicAccountApi.refreshNeteaseStatus();
      if (!mounted) return;
      setState(() => _neteaseStatus = status);
      if (status != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(status.message ?? '刷新完成')));
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingNetease = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final user = authState.user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('个人中心')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('请先登录'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push('/login'),
                child: const Text('去登录'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头像和基本信息
            _buildProfileHeader(user, theme),
            const SizedBox(height: 24),

            // 资料编辑
            _buildProfileEdit(theme),
            const SizedBox(height: 24),

            // 功能菜单
            _buildMenuList(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User user, ThemeData theme) {
    return Center(
      child: Column(
        children: [
          // 头像
          CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? Text(
                    user.username.substring(0, 1).toUpperCase(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          // 用户名
          Text(
            user.nickname ?? user.username,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // 邮箱
          Text(
            user.email,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          // 注册时间
          Text(
            '注册于 ${_formatDate(user.createdAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileEdit(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '个人资料',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    if (_isEditing) {
                      _saveProfile();
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
                  icon: Icon(_isEditing ? Icons.save : Icons.edit),
                  label: Text(_isEditing ? '保存' : '编辑'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 昵称
            TextField(
              controller: _nicknameController,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: '昵称',
                hintText: '请输入昵称',
                prefixIcon: const Icon(Icons.person_outline),
                border: _isEditing
                    ? const OutlineInputBorder()
                    : InputBorder.none,
                filled: !_isEditing,
                fillColor: !_isEditing
                    ? theme.colorScheme.surfaceContainerHighest
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuList(ThemeData theme) {
    return Card(
      child: Column(
        children: [
          // 我的上传
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('我的上传'),
            subtitle: const Text('管理上传的音频文件'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/uploads'),
          ),
          const Divider(height: 1),

          // 音乐账号绑定
          ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('音乐账号绑定'),
            subtitle: const Text('绑定网易云、QQ音乐等账号'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showMusicAccountsDialog,
          ),
          const Divider(height: 1),

          // 修改密码
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('修改密码'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 实现修改密码
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('功能开发中')));
            },
          ),
        ],
      ),
    );
  }

  void _showMusicAccountsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final status = _neteaseStatus;
        final isBound = status?.valid ?? false;

        return AlertDialog(
          title: const Text('音乐账号绑定'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMusicAccountItem(
                  name: '网易云音乐',
                  subtitle: _isLoadingNeteaseStatus
                      ? '正在读取授权状态...'
                      : isBound
                      ? '已授权${status?.nickname != null ? ' · ${status!.nickname}' : ''}'
                      : (status?.message ?? '未授权'),
                  isBound: isBound,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _isRefreshingNetease
                            ? null
                            : _refreshNeteaseStatus,
                        child: Text(_isRefreshingNetease ? '刷新中' : '刷新状态'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _showNeteaseAuthMethodDialog();
                        },
                        child: Text(isBound ? '重新授权' : '去授权'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildMusicAccountItem(
                  name: 'QQ音乐',
                  subtitle: '暂未接入',
                  isBound: false,
                  trailing: const Text('待开发'),
                ),
                const SizedBox(height: 8),
                _buildMusicAccountItem(
                  name: '酷狗音乐',
                  subtitle: '暂未接入',
                  isBound: false,
                  trailing: const Text('待开发'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showNeteaseAuthMethodDialog() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: const Text('扫码授权'),
              subtitle: const Text('适合当前账号允许扫码时使用'),
              onTap: () => Navigator.of(context).pop('qr'),
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: const Text('手机验证码登录'),
              subtitle: const Text('通过手机号和验证码完成网易云授权'),
              onTap: () => Navigator.of(context).pop('phone'),
            ),
            ListTile(
              leading: const Icon(Icons.cookie_outlined),
              title: const Text('导入 Cookie'),
              subtitle: const Text('从网易云网页登录态中复制 Cookie 后导入'),
              onTap: () => Navigator.of(context).pop('cookie'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'qr') {
      await _showNeteaseQrDialog();
      return;
    }
    if (action == 'cookie') {
      await _showNeteaseCookieDialog();
      return;
    }
    await _showNeteasePhoneDialog();
  }

  Future<void> _showNeteaseQrDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    final startResult = await MusicAccountApi.startNeteaseQrLogin();
    if (!mounted) return;

    if (startResult == null || startResult.key.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('获取网易云二维码失败')));
      return;
    }

    Timer? pollTimer;
    var lastMessage = '请使用网易云音乐 App 扫码授权';
    final qrBytes = _decodeQrImage(startResult.qrImage);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            pollTimer ??= Timer.periodic(const Duration(seconds: 2), (_) async {
              final result = await MusicAccountApi.checkNeteaseQrLogin(
                startResult.key,
              );
              if (!mounted || !context.mounted || result == null) return;

              if (result.message?.isNotEmpty == true) {
                setState(() => lastMessage = result.message!);
              }

              if (result.authorized) {
                pollTimer?.cancel();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                await _loadNeteaseStatus();
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      result.nickname?.isNotEmpty == true
                          ? '网易云授权成功：${result.nickname}'
                          : '网易云授权成功',
                    ),
                  ),
                );
                return;
              }

              if (result.code == 800) {
                pollTimer?.cancel();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('二维码已过期，请重新获取')),
                );
              }
            });

            return AlertDialog(
              title: const Text('网易云扫码授权'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (qrBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.memory(
                          qrBytes,
                          width: 220,
                          height: 220,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      SelectableText(startResult.qrUrl ?? ''),
                    const SizedBox(height: 16),
                    Text(
                      lastMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    pollTimer?.cancel();
                    Navigator.of(context).pop();
                  },
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );

    pollTimer?.cancel();
  }

  Future<void> _showNeteasePhoneDialog() async {
    final phoneController = TextEditingController();
    final captchaController = TextEditingController();
    final ctcodeController = TextEditingController(text: '86');
    final messenger = ScaffoldMessenger.of(context);
    var isSending = false;
    var isSubmitting = false;
    var cooldownSeconds = 0;
    String? errorText;
    Timer? cooldownTimer;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            var dialogClosed = false;

            Future<void> sendCaptcha() async {
              final phone = phoneController.text.trim();
              final ctcode = ctcodeController.text.trim().isEmpty
                  ? '86'
                  : ctcodeController.text.trim();
              if (phone.isEmpty) {
                setState(() => errorText = '请输入手机号');
                return;
              }

              setState(() {
                isSending = true;
                errorText = null;
              });
              try {
                final result = await MusicAccountApi.sendNeteaseCaptcha(
                  phone: phone,
                  ctcode: ctcode,
                );
                if (!context.mounted) return;
                if (result.success) {
                  cooldownTimer?.cancel();
                  cooldownSeconds = 60;
                  cooldownTimer = Timer.periodic(const Duration(seconds: 1), (
                    timer,
                  ) {
                    if (!context.mounted) {
                      timer.cancel();
                      return;
                    }
                    if (cooldownSeconds <= 1) {
                      timer.cancel();
                      setState(() => cooldownSeconds = 0);
                    } else {
                      setState(() => cooldownSeconds -= 1);
                    }
                  });
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      result.success
                          ? '验证码已发送'
                          : (result.message ?? '验证码发送失败'),
                    ),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                setState(() => errorText = _displayError(e, '验证码发送失败'));
                messenger.showSnackBar(
                  SnackBar(content: Text(_displayError(e, '验证码发送失败'))),
                );
              } finally {
                if (context.mounted) {
                  setState(() => isSending = false);
                }
              }
            }

            Future<void> submitLogin() async {
              final phone = phoneController.text.trim();
              final captcha = captchaController.text.trim();
              final ctcode = ctcodeController.text.trim().isEmpty
                  ? '86'
                  : ctcodeController.text.trim();
              if (phone.isEmpty || captcha.isEmpty) {
                setState(() => errorText = '请输入手机号和验证码');
                return;
              }

              setState(() {
                isSubmitting = true;
                errorText = null;
              });
              try {
                final status = await MusicAccountApi.loginNeteaseByCaptcha(
                  phone: phone,
                  captcha: captcha,
                  ctcode: ctcode,
                );
                if (!context.mounted) return;
                if (status?.valid == true) {
                  cooldownTimer?.cancel();
                  if (mounted) {
                    this.setState(() => _neteaseStatus = status);
                  }
                  dialogClosed = true;
                  Navigator.of(context).pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        status?.nickname?.isNotEmpty == true
                            ? '网易云授权成功：${status!.nickname}'
                            : '网易云授权成功',
                      ),
                    ),
                  );
                  return;
                }

                messenger.showSnackBar(
                  SnackBar(content: Text(status?.message ?? '网易云授权失败')),
                );
                setState(() => errorText = status?.message ?? '网易云授权失败');
              } catch (e) {
                if (!context.mounted) return;
                setState(() => errorText = _displayError(e, '网易云授权失败'));
                messenger.showSnackBar(
                  SnackBar(content: Text(_displayError(e, '网易云授权失败'))),
                );
              } finally {
                if (context.mounted && !dialogClosed) {
                  setState(() => isSubmitting = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('网易云手机验证码登录'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 96,
                          child: TextField(
                            controller: ctcodeController,
                            decoration: const InputDecoration(
                              labelText: '区号',
                              hintText: '86',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                              labelText: '手机号',
                              hintText: '请输入网易云绑定手机号',
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: captchaController,
                            decoration: const InputDecoration(
                              labelText: '验证码',
                              hintText: '请输入短信验证码',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: isSending || cooldownSeconds > 0
                              ? null
                              : sendCaptcha,
                          child: Text(
                            isSending
                                ? '发送中'
                                : cooldownSeconds > 0
                                ? '${cooldownSeconds}s'
                                : '发送验证码',
                          ),
                        ),
                      ],
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submitLogin,
                  child: Text(isSubmitting ? '登录中' : '确认登录'),
                ),
              ],
            );
          },
        );
      },
    );

    cooldownTimer?.cancel();
    phoneController.dispose();
    captchaController.dispose();
    ctcodeController.dispose();
  }

  Future<void> _showNeteaseCookieDialog() async {
    final cookieController = TextEditingController();
    final uidController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    var isSubmitting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            var dialogClosed = false;

            Future<void> submitCookie() async {
              final cookie = cookieController.text.trim();
              final uid = uidController.text.trim();
              if (cookie.isEmpty) {
                setState(() => errorText = '请输入完整 Cookie');
                return;
              }

              setState(() {
                isSubmitting = true;
                errorText = null;
              });
              try {
                final status = await MusicAccountApi.importNeteaseCookie(
                  cookie,
                  uid: uid.isEmpty ? null : uid,
                );
                if (!context.mounted) return;
                if (status?.valid == true) {
                  if (mounted) {
                    this.setState(() => _neteaseStatus = status);
                  }
                  dialogClosed = true;
                  Navigator.of(context).pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        status?.nickname?.isNotEmpty == true
                            ? 'Cookie 导入成功：${status!.nickname}'
                            : 'Cookie 导入成功',
                      ),
                    ),
                  );
                  return;
                }
                setState(() => errorText = status?.message ?? 'Cookie 校验失败');
              } catch (e) {
                if (!context.mounted) return;
                setState(() => errorText = _displayError(e, 'Cookie 导入失败'));
              } finally {
                if (context.mounted && !dialogClosed) {
                  setState(() => isSubmitting = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('导入网易云 Cookie'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '请粘贴从网易云网页登录态中复制的完整 Cookie 字符串。',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: uidController,
                      decoration: const InputDecoration(
                        labelText: 'uid（可选）',
                        hintText: '推荐填写网易云用户 uid，便于后续兼容排查',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cookieController,
                      minLines: 5,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: '例如：MUSIC_U=...; __csrf=...; NMTID=...;',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submitCookie,
                  child: Text(isSubmitting ? '导入中' : '确认导入'),
                ),
              ],
            );
          },
        );
      },
    );

    cookieController.dispose();
    uidController.dispose();
  }

  String _displayError(Object error, String fallback) {
    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    return text.isEmpty ? fallback : text;
  }

  Widget _buildMusicAccountItem({
    required String name,
    required String subtitle,
    required bool isBound,
    required Widget trailing,
  }) {
    return ListTile(
      leading: Icon(
        isBound ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isBound ? Colors.green : null,
      ),
      title: Text(name),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }

  Uint8List? _decodeQrImage(String? qrImage) {
    if (qrImage == null || qrImage.isEmpty) return null;
    final commaIndex = qrImage.indexOf(',');
    final raw = commaIndex >= 0 ? qrImage.substring(commaIndex + 1) : qrImage;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
