import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'core/theme_mode.dart';

class WorshipApp extends ConsumerWidget {
  const WorshipApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Worship Hub',
      debugShowCheckedModeBanner: false,
      theme: Sanctuary.buildTheme(Brightness.light),
      darkTheme: Sanctuary.buildTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) =>
          AuroraBackground(child: child ?? const SizedBox.shrink()),
    );
  }
}
