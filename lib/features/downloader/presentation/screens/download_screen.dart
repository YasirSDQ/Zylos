import 'package:flutter/material.dart';
import '../widgets/download_queue_panel.dart';

class DownloadScreen extends StatelessWidget {
  const DownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DownloadQueuePanel(),
    );
  }
}
