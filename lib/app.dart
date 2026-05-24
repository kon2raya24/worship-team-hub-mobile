import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';

class WorshipApp extends ConsumerWidget {
  const WorshipApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Worship Hub',
      debugShowCheckedModeBanner: false,
      theme: Sanctuary.buildTheme(),
      routerConfig: router,
      builder: (context, child) =>
          AuroraBackground(child: child ?? const SizedBox.shrink()),
    );
  }
}
