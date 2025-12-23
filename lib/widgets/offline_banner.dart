// File: lib/widgets/offline_banner.dart

import 'package:flutter/material.dart';
import 'package:lawdesk/services/connectivity_service.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Return an empty widget - we're using OfflineDataIndicator instead
    // This widget is kept for backwards compatibility but renders nothing
    return const SizedBox.shrink();
  }
}
