import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/room/pages/room_list_page.dart';
import '../../features/room/pages/room_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/auth/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/rooms',
    redirect: (context, state) {
      final isLoggedIn = authState.isLoggedIn;
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register');

      // 未登录时访问需要鉴权的页面，重定向到登录
      // 注意：房间列表和房间页面允许 Guest 访问
      if (!isLoggedIn && state.matchedLocation.startsWith('/profile')) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/rooms', builder: (_, __) => const RoomListPage()),
      GoRoute(
        path: '/room/:houseId',
        builder: (_, state) =>
            RoomPage(houseId: state.pathParameters['houseId']!),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('页面不存在: ${state.error}')),
    ),
  );
});
