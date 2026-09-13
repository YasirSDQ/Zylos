import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'app/app.dart';
import 'core/services/plugin_service.dart';
import 'core/services/download_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/queue_manager.dart';
import 'core/services/ffmpeg_service.dart';
import 'core/services/local_server.dart';
import 'features/downloader/data/datasources/youtube_datasource.dart';
import 'features/downloader/data/repositories/download_repository_impl.dart';
import 'features/downloader/domain/entities/download_task.dart';
import 'features/downloader/presentation/providers/download_provider.dart';
import 'features/downloader/presentation/providers/playlist_provider.dart';
import 'features/downloader/presentation/providers/settings_provider.dart';
import 'features/downloader/presentation/providers/navigation_provider.dart';
import 'features/downloader/presentation/providers/converter_provider.dart';
import 'features/downloader/presentation/providers/plugin_provider.dart';

import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final String rawArg = args.isNotEmpty ? args[0] : '';
  // zylos://background → start hidden in tray
  // zylos://open       → start or bring window to front
  bool isBackground = rawArg.contains('background');
  bool shouldFocus  = rawArg.contains('open') && !rawArg.contains('background');

  if (Platform.isWindows) {
    await WindowsSingleInstance.ensureSingleInstance(args, "zylos_app_instance", onSecondWindow: (args) async {
      // This runs in the FIRST instance when a SECOND instance is launched
      final String rawArg = args.isNotEmpty ? args[0] : '';
      bool bringToFront = !rawArg.contains('background'); 
      if (bringToFront) {
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setSkipTaskbar(false);
      }
    });

    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1100, 700),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (isBackground) {
        // Started by extension when app wasn't running — stay hidden in tray
        await windowManager.hide();
        await windowManager.setSkipTaskbar(true);
      } else if (shouldFocus) {
        // Extension clicked 'Open App' and app was already running
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setSkipTaskbar(false);
      } else {
        // Normal user launch
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setSkipTaskbar(false);
      }
    });

    // Init tray
    await trayManager.setIcon(Platform.isWindows ? 'assets/images/logo.ico' : 'assets/images/logo.png');
    Menu menu = Menu(
      items: [
        MenuItem(key: 'show_app', label: 'Show Zylos'),
        MenuItem.separator(),
        MenuItem(key: 'exit_app', label: 'Exit'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  try {
    // Initialize Data Persistence
    final appDir = await getApplicationSupportDirectory();
    String dbPath = appDir.path;
    await Hive.initFlutter(dbPath);
    Hive.registerAdapter(DownloadStatusAdapter());
    Hive.registerAdapter(DownloadTaskAdapter());
    final historyBox = await Hive.openBox<DownloadTask>('history');
    final queueBox = await Hive.openBox<DownloadTask>('download_queue');
    final settingsBox = await Hive.openBox('settings');

    // Initialize Services
    final notificationService = NotificationService();
    await notificationService.init();

    final pluginService = PluginService();
    final ffmpegService = FFmpegService(pluginService);
    final downloadService = DownloadService(notificationService, ffmpegService, pluginService);
    final datasource = YoutubeDatasource(pluginService);
    final repository = DownloadRepositoryImpl(datasource: datasource, downloadService: downloadService);
    final queueManager = QueueManager(repository, downloadService, queueBox);

    final downloadProvider = DownloadProvider(queueManager, historyBox);
    final navigationProvider = NavigationProvider();
    final settingsProvider = SettingsProvider(settingsBox, queueManager);

    // Initialize Local HTTP Server for Chrome Extension
    try {
      final port = settingsBox.get('serverPort', defaultValue: 7734) as int;
      await LocalServer.start(downloadProvider, navigationProvider, navigatorKey, pluginService, settingsProvider, serverPort: port);
    } catch (e) {
      debugPrint('[Zylos] LocalServer error: $e');
    }

    // Register zylos:// protocol for Windows
    if (Platform.isWindows) {
      _registerProtocol();
    }

    runApp(
      MultiProvider(
        providers: [
          Provider<DownloadRepositoryImpl>.value(value: repository),
          ChangeNotifierProvider(create: (_) => PluginProvider(pluginService)),
          ChangeNotifierProvider.value(value: downloadProvider),
          ChangeNotifierProvider(create: (_) => PlaylistProvider()),
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider(create: (_) => NavigationProvider()),
          ChangeNotifierProvider(create: (_) => ConverterProvider(ffmpegService)),
        ],
        child: YTDownloaderApp(isBackground: isBackground),
      ),
    );
  } catch (e, stack) {
    debugPrint('[Zylos] Fatal startup error: $e\n$stack');
    // Fallback UI if everything fails
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SelectableText('Fatal Startup Error:\n$e'),
        ),
      ),
    ));
  }
}

/// Registers the zylos:// protocol in the Windows registry
void _registerProtocol() async {
  if (!Platform.isWindows) return;

  final String exePath = Platform.resolvedExecutable;
  final String protocolName = "zylos";

  try {
    // Add main protocol key
    await Process.run('reg', ['add', 'HKCU\\Software\\Classes\\$protocolName', '/v', '', '/t', 'REG_SZ', '/d', 'URL:Zylos Protocol', '/f'], runInShell: true);
    await Process.run('reg', ['add', 'HKCU\\Software\\Classes\\$protocolName', '/v', 'URL Protocol', '/t', 'REG_SZ', '/d', '', '/f'], runInShell: true);
    
    // Add DefaultIcon
    await Process.run('reg', ['add', 'HKCU\\Software\\Classes\\$protocolName\\DefaultIcon', '/v', '', '/t', 'REG_SZ', '/d', '"$exePath",0', '/f'], runInShell: true);
    
    // Add shell command
    await Process.run('reg', ['add', 'HKCU\\Software\\Classes\\$protocolName\\shell', '/f'], runInShell: true);
    await Process.run('reg', ['add', 'HKCU\\Software\\Classes\\$protocolName\\shell\\open', '/f'], runInShell: true);
    await Process.run('reg', ['add', 'HKCU\\Software\\Classes\\$protocolName\\shell\\open\\command', '/v', '', '/t', 'REG_SZ', '/d', '"$exePath" "%1"', '/f'], runInShell: true);
    
    debugPrint('Zylos protocol registered: $exePath');
  } catch (e) {
    debugPrint('Error registering protocol: $e');
  }
}
