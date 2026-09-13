import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateService {
  static const String repoOwner = 'Yasir'; // Replace with actual GitHub owner
  static const String repoName = 'Zylos'; // Replace with actual GitHub repo
  static const String apiUrl = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  Future<String?> checkForUpdates() async {
    try {
      final dio = Dio();
      final response = await dio.get(apiUrl, options: Options(receiveTimeout: const Duration(seconds: 5)));

      if (response.statusCode == 200 && response.data != null) {
        final latestVersion = response.data['tag_name']?.toString().replaceFirst('v', '');
        
        if (latestVersion != null) {
          final packageInfo = await PackageInfo.fromPlatform();
          final currentVersion = packageInfo.version;

          if (_isNewerVersion(latestVersion, currentVersion)) {
            return latestVersion;
          }
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking for updates: $e');
    }
    return null;
  }

  bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
    } catch (e) {
      return false;
    }
    return false;
  }
}
