import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/supabase_client.dart';
import 'core/theme_provider.dart';
import 'core/app_theme.dart';
import 'core/router.dart';
import 'core/globals.dart';
import 'features/notifications/providers/notification_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const ProviderScope(child: CallAppointApp()));
}

class CallAppointApp extends ConsumerWidget {
  const CallAppointApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    // Listen to global notifications
    ref.listen(notificationSocketProvider, (previous, next) {
      debugPrint('CallAppointApp: notificationSocketProvider state changed: $next');
      if (next is AsyncData<Map<String, dynamic>>) {
        final data = next.value;
        debugPrint('CallAppointApp: Emitting event to manager: $data');
        // We get context from the router's configuration
        final context = router.routerDelegate.navigatorKey.currentContext;
        ref.read(notificationManagerProvider.notifier).handleEvent(data, context);
      } else if (next is AsyncError) {
        debugPrint('CallAppointApp: notificationSocketProvider error: ${next.error}');
      }
    });

    return MaterialApp.router(
      title: 'CallAppoint',
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
