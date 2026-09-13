import 'package:flutter/material.dart';

class AppNotifications {
  static void showSnackBar(
    BuildContext context, {
    required String message,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 5),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: GestureDetector(
          onTap: () => messenger.hideCurrentSnackBar(),
          child: Text(message),
        ),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        action: action,
      ),
    );

    Future.delayed(duration, () {
      try {
        controller.close();
      } catch (_) {}
    });
  }

  static void showSnackBarWithKey(
    GlobalKey<ScaffoldMessengerState> key, {
    required String message,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 5),
  }) {
    final state = key.currentState;
    if (state == null) return;
    
    state.hideCurrentSnackBar();
    final controller = state.showSnackBar(
      SnackBar(
        content: GestureDetector(
          onTap: () => state.hideCurrentSnackBar(),
          child: Text(message),
        ),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        action: action,
      ),
    );

    Future.delayed(duration, () {
      try {
        controller.close();
      } catch (_) {}
    });
  }
}
