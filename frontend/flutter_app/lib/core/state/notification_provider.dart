import "package:flutter_riverpod/flutter_riverpod.dart";

enum NutriNotificationType { info, success, warning, error }

class NutriNotification {
  final String id;
  final String title;
  final String message;
  final NutriNotificationType type;
  final DateTime timestamp;
  bool read;

  NutriNotification({
    required this.id,
    required this.title,
    required this.message,
    this.type = NutriNotificationType.info,
    required this.timestamp,
    this.read = false,
  });
}

class NotificationNotifier extends StateNotifier<List<NutriNotification>> {
  NotificationNotifier() : super([]);

  void add(String title, String message,
      {NutriNotificationType type = NutriNotificationType.info}) {
    final newNotif = NutriNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
    );
    state = [newNotif, ...state];
  }

  void markAsRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id)
          NutriNotification(
              id: n.id,
              title: n.title,
              message: n.message,
              type: n.type,
              timestamp: n.timestamp,
              read: true)
        else
          n,
    ];
  }

  void markAllAsRead() {
    state = [
      for (final n in state)
        NutriNotification(
            id: n.id,
            title: n.title,
            message: n.message,
            type: n.type,
            timestamp: n.timestamp,
            read: true),
    ];
  }

  void clearAll() => state = [];

  int get unreadCount => state.where((n) => !n.read).length;
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<NutriNotification>>((ref) {
  return NotificationNotifier();
});
