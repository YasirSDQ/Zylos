import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:hive/hive.dart';

class PlatformUtils {
  static Future<bool> requestStoragePermission() async {
    return true; // Not needed on Windows
  }

  static String getDefaultDownloadPath() {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download/Zylos';
    } else if (Platform.isWindows) {
      return '${Platform.environment['USERPROFILE']}\\Downloads\\Zylos';
    } else if (Platform.isMacOS) {
      return '${Platform.environment['HOME']}/Downloads/Zylos';
    } else if (Platform.isLinux) {
      return '${Platform.environment['HOME']}/Downloads/Zylos';
    } else if (Platform.isIOS) {
      // iOS doesn't have a direct public "Downloads" accessible by absolute path easily without PathProvider
      // So this is a fallback. Real path should be grabbed from path_provider.
      return 'Documents/Zylos';
    }
    return 'Downloads/Zylos';
  }

  static String getActiveDownloadPath() {
    try {
      if (Hive.isBoxOpen('settings')) {
        final saved = Hive.box('settings').get('downloadPath') as String?;
        if (saved != null && saved.isNotEmpty) return saved;
      }
    } catch (_) {}
    return getDefaultDownloadPath();
  }

  static Future<void> openFileInExplorer(String path) async {
    if (!await File(path).exists()) return;
    
    if (Platform.isWindows) {
      final winPath = path.replaceAll('/', '\\');
      await Process.run('explorer.exe', ['/select,', winPath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', path]);
    } else if (Platform.isLinux) {
      final dir = File(path).parent.path;
      await Process.run('xdg-open', [dir]);
    } else {
      // Android/iOS
      await OpenFile.open(path);
    }
  }

  static Future<void> openVideoFile(String path) async {
    if (await File(path).exists()) {
      await OpenFile.open(path);
    }
  }

  static Future<void> openFolder(String path) async {
    if (!await Directory(path).exists()) return;
    
    if (Platform.isWindows) {
      final winPath = path.replaceAll('/', '\\');
      await Process.run('explorer.exe', [winPath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    } else {
      // Android/iOS
      await OpenFile.open(path);
    }
  }
}
