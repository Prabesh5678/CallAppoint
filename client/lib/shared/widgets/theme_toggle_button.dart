import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme_provider.dart';

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark;
    return IconButton(
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}
