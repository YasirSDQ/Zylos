import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  final manifest = await yt.videos.streamsClient.getManifest('o1T9ObaqoJw');
  
  final Map<int, dynamic> qualityMap = {};
  
  for (var stream in manifest.muxed) {
    if (stream.qualityLabel.isNotEmpty) {
      final h = stream.videoResolution.height.toInt();
      qualityMap[h] = stream.qualityLabel;
    }
  }
  
  for (var stream in manifest.videoOnly) {
    final h = stream.videoResolution.height.toInt();
    qualityMap[h] = stream.qualityLabel;
  }
  
  print('Qualities: ' + qualityMap.toString());
  yt.close();
}
