import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/services/connectivity_service.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/chat_datasource.dart';
import 'data/datasources/library_datasource.dart';
import 'data/parsers/parser_registry.dart';
import 'data/repositories/library_repository.dart';
import 'features/app_shell.dart';
import 'state/chat_provider.dart';
import 'state/home_provider.dart';
import 'state/library_provider.dart';
import 'state/search_provider.dart';
import 'state/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop/database init (Linux/Windows use sqlite3 via FFI; Android/iOS use
  // the sqflite platform implementation — both end up in the same schema).
  if (!PlatformOverrides.isMobile) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        Provider<LibraryDatasource>(create: (_) => LibraryDatasource()),
        Provider<ChatDatasource>(create: (_) => ChatDatasource()),
        Provider<ConnectivityService>(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(prefs),
        ),
        ChangeNotifierProvider(
          create: (ctx) => LibraryProvider(
            repository: LibraryRepository(
              ctx.read<LibraryDatasource>(),
              ParserRegistry.create(),
            ),
            datasource: ctx.read<LibraryDatasource>(),
            settings: ctx.read<SettingsProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => SearchProvider(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ChatProvider(
            chatDatasource: ctx.read<ChatDatasource>(),
            libraryDatasource: ctx.read<LibraryDatasource>(),
            settings: ctx.read<SettingsProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => HomeProvider(
            library: ctx.read<LibraryDatasource>(),
            chat: ctx.read<ChatDatasource>(),
          ),
        ),
      ],
      child: const DocuMindApp(),
    ),
  );
}

class DocuMindApp extends StatelessWidget {
  const DocuMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'DocuMind',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeModeOf(settings.themeMode),
      home: const AppShellWithConnectivity(),
    );
  }
}

/// Listens to connectivity and toggles the offline banner.
class AppShellWithConnectivity extends StatefulWidget {
  const AppShellWithConnectivity({super.key});

  @override
  State<AppShellWithConnectivity> createState() =>
      _AppShellWithConnectivityState();
}

class _AppShellWithConnectivityState extends State<AppShellWithConnectivity> {
  @override
  void initState() {
    super.initState();
    final connectivity = context.read<ConnectivityService>();
    connectivity.onChange.listen((online) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final offline = !context.read<ConnectivityService>().isOnline;
    return TickerMode(
      child: AppShell(offline: offline),
      enabled: true,
    );
  }
}

/// Platform flags that can't be imported via dart:io in tests.
class PlatformOverrides {
  static bool get isMobile {
    if (kIsWeb) return true;
    try {
      return defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
    } catch (_) {
      return false;
    }
  }
}
