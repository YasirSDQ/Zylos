class FormatUtils {
  static String formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    int i = 0;
    double b = bytes.toDouble();
    while (b > 1024 && i < suffixes.length - 1) {
      b /= 1024;
      i++;
    }
    return "${b.toStringAsFixed(decimals)} ${suffixes[i]}";
  }

  static String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return "0 B/s";
    return "${formatBytes(bytesPerSecond.toInt(), decimals: 1)}/s";
  }

  static String formatEta(Duration? eta) {
    if (eta == null) return "--:--";
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (eta.inHours > 0) {
      return "~${eta.inHours}:${twoDigits(eta.inMinutes.remainder(60))}:${twoDigits(eta.inSeconds.remainder(60))} remaining";
    }
    if (eta.inMinutes > 0) {
      return "~${eta.inMinutes}:${twoDigits(eta.inSeconds.remainder(60))} remaining";
    }
    return "~${eta.inSeconds}s remaining";
  }

  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
