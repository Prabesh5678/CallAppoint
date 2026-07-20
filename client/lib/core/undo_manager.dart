import 'dart:async';
import 'package:flutter/material.dart';
import 'globals.dart';

class UndoResult {
  final bool wasUndone;
  UndoResult({required this.wasUndone});
}

class UndoManager {
  static Future<UndoResult> showUndoSnackBar({
    required String message,
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 4),
  }) async {
    final messenger = rootScaffoldMessengerKey.currentState;
    bool wasUndone = false;
    final userActionCompleter = Completer<void>();

    // 1. Independent Fallback Timer (ensures logic continues even if UI fails)
    final timer = Timer(duration + const Duration(milliseconds: 500), () {
      if (!userActionCompleter.isCompleted) {
        userActionCompleter.complete();
      }
    });

    if (messenger != null) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              wasUndone = true;
              onUndo();
              if (!userActionCompleter.isCompleted) userActionCompleter.complete();
            },
          ),
          duration: duration,
        ),
      ).closed.then((reason) {
        if (!userActionCompleter.isCompleted) userActionCompleter.complete();
      });
    } else {
      // No UI available? Just proceed immediately
      if (!userActionCompleter.isCompleted) userActionCompleter.complete();
    }

    await userActionCompleter.future;
    timer.cancel();

    if (!wasUndone) {
      // Ensure visual dismissal before returning control to the caller (backend request)
      messenger?.hideCurrentSnackBar(reason: SnackBarClosedReason.hide);
    }

    return UndoResult(wasUndone: wasUndone);
  }
}
