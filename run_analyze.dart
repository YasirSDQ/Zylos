import 'dart:io';

void main() async {
  final result = await Process.run('dart', ['analyze', '--format=machine', 'lib/features/downloader/presentation/screens/home_screen.dart', 'lib/features/downloader/presentation/screens/platform_downloader_screen.dart']);
  stdout.writeln(result.stdout);
  stdout.writeln(result.stderr);
}
