import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:together_music/core/router/app_router.dart';

void main() {
  runApp(const ProviderScope(child: TogetherMusicApp()));
}

class TogetherMusicApp extends ConsumerWidget {
  const TogetherMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '伴听',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF9CC2FF),
          onPrimary: Color(0xFF10203E),
          secondary: Color(0xFFCDB9FF),
          onSecondary: Color(0xFF21163E),
          surface: Color(0xFF111017),
          surfaceContainerHighest: Color(0xFF2A2734),
          surfaceContainerHigh: Color(0xFF211F29),
          surfaceContainer: Color(0xFF1A1821),
          primaryContainer: Color(0xFF25324D),
          onPrimaryContainer: Color(0xFFDCE7FF),
          error: Color(0xFFFF8A80),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B0911),
        cardColor: Colors.transparent,
        dividerColor: Colors.white.withValues(alpha: 0.08),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1B1822).withValues(alpha: 0.92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFFF2EEFF),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.04),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF9CC2FF)),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}
