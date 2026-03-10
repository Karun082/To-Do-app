import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();

  final themeProvider = ThemeProvider();
  await themeProvider.load();

  final authProvider = AuthProvider();
  await authProvider.restoreSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProxyProvider<AuthProvider, TaskProvider>(
          create: (_) => TaskProvider(),
          update: (_, auth, taskProvider) {
            final provider = taskProvider ?? TaskProvider();
            provider.updateUser(auth.currentUser?.id);
            return provider;
          },
        ),
      ],
      child: const DailyChipApp(),
    ),
  );
}

class DailyChipApp extends StatelessWidget {
  const DailyChipApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().mode;
    final auth = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'DailyChip Todo',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: auth.isAuthenticated ? const HomeScreen() : const LoginScreen(),
    );
  }
}
