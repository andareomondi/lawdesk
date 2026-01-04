import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();

      // Set local location to Kenya timezone
      final String timeZoneName = 'Africa/Nairobi';
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permission for Android 13+
      await _requestNotificationPermission();

      _isInitialized = true;
      print('✓ Notification service initialized successfully');
    } catch (e) {
      print('✗ Failed to initialize notification service: $e');
    }
  }

  // Show instant notification for testing
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_channel',
          'Instant Notifications',
          channelDescription: 'Channel for instant notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  // schedule notification for testing
  Future<void> scheduleTestNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = now.add(Duration(seconds: 3));
    print('Scheduling test notification for: $scheduledDate');
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Channel for test notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    print('Test notificatin scheduled successfully');
  }

  Future<void> _requestNotificationPermission() async {
    try {
      if (await Permission.notification.isDenied) {
        final status = await Permission.notification.request();
        if (status.isGranted) {
          print('✓ Notification permission granted');
        } else {
          print('✗ Notification permission denied');
        }
      }
    } catch (e) {
      print('✗ Error requesting notification permission: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - you can add navigation logic here
    print('Notification tapped: ${response.payload}');

    // Example: Parse payload and navigate to specific case/event
    // if (response.payload != null) {
    //   if (response.payload!.startsWith('case_')) {
    //     final caseId = response.payload!.replaceFirst('case_', '');
    //     // Navigate to case details
    //   } else if (response.payload!.startsWith('event_')) {
    //     final eventId = response.payload!.replaceFirst('event_', '');
    //     // Navigate to event details
    //   }
    // }
  }

  // ============================================================================
  // COURT DATE NOTIFICATIONS
  // ============================================================================

  /// Schedule notifications for a court date
  /// Schedules 3 notifications:
  /// 1. 7 days before at 9 AM
  /// 2. 1 day before at 9 AM
  /// 3. Day of, 2 hours before court time (or 9 AM if no time set)
  Future<void> scheduleCourtDateNotifications({
    required int caseId,
    required DateTime courtDate,
    required String caseName,
    TimeOfDay? courtTime,
  }) async {
    if (!_isInitialized) {
      print('✗ Notification service not initialized');
      return;
    }

    // Cancel existing notifications for this case first
    await cancelNotificationsForCase(caseId);

    // Don't schedule if date is in the past
    if (courtDate.isBefore(DateTime.now())) {
      print('⚠ Court date is in the past, skipping notification scheduling');
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'court_reminders',
          'Court Date Reminders',
          channelDescription: 'Notifications for upcoming court dates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF1E3A8A), // Your app's primary color
          enableLights: true,
          enableVibration: true,
          playSound: true,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    int scheduledCount = 0;

    // ========== 1. Schedule 7 days before (at 7 AM) ==========
    final sevenDaysBefore = DateTime(
      courtDate.year,
      courtDate.month,
      courtDate.day,
      7, // 7 AM
      0,
    ).subtract(const Duration(days: 7));

    if (sevenDaysBefore.isAfter(DateTime.now())) {
      try {
        await _notifications.zonedSchedule(
          _getCourtNotificationId(caseId, 0), // Unique ID
          '⚖️ Court Date in 7 Days',
          '$caseName on ${_formatDate(courtDate)}',
          tz.TZDateTime.from(sevenDaysBefore, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'case_$caseId',
        );
        scheduledCount++;
        print('  → 7-day reminder: ${sevenDaysBefore.toString()}');
      } catch (e) {
        print('  ✗ Failed to schedule 7-day reminder: $e');
      }
    }

    // ========== 2. Schedule 24 hours before (at 7 AM) ==========
    final oneDayBefore = DateTime(
      courtDate.year,
      courtDate.month,
      courtDate.day,
      7, // 9 AM
      0,
    ).subtract(const Duration(days: 1));

    if (oneDayBefore.isAfter(DateTime.now())) {
      try {
        await _notifications.zonedSchedule(
          _getCourtNotificationId(caseId, 1),
          '⚖️ Court Date Tomorrow',
          '$caseName at ${courtTime != null ? _formatTime(courtTime) : "scheduled time"}',
          tz.TZDateTime.from(oneDayBefore, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'case_$caseId',
        );
        scheduledCount++;
        print('  → 1-day reminder: ${oneDayBefore.toString()}');
      } catch (e) {
        print('  ✗ Failed to schedule 1-day reminder: $e');
      }
    }

    // ========== 3. Schedule day of (2 hours before court time or 9 AM) ==========
    final dayOfHour = courtTime != null ? courtTime.hour : 9;
    final dayOfMinute = courtTime != null ? courtTime.minute : 0;

    DateTime dayOf = DateTime(
      courtDate.year,
      courtDate.month,
      courtDate.day,
      dayOfHour,
      dayOfMinute,
    );

    // If court time is set, schedule 2 hours before
    if (courtTime != null) {
      dayOf = dayOf.subtract(const Duration(hours: 2));
    }

    if (dayOf.isAfter(DateTime.now())) {
      try {
        await _notifications.zonedSchedule(
          _getCourtNotificationId(caseId, 2),
          '⚖️ Court Date Today!',
          courtTime != null
              ? '$caseName at ${_formatTime(courtTime)}'
              : '$caseName today',
          tz.TZDateTime.from(dayOf, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'case_$caseId',
        );
        scheduledCount++;
        print('  → Day-of reminder: ${dayOf.toString()}');
      } catch (e) {
        print('  ✗ Failed to schedule day-of reminder: $e');
      }
    }

    print(
      '✓ Court notifications scheduled: $caseName ($scheduledCount reminders)',
    );
  }

  /// Cancel all notifications for a specific case
  Future<void> cancelNotificationsForCase(int caseId) async {
    try {
      await _notifications.cancel(_getCourtNotificationId(caseId, 0)); // 7 days
      await _notifications.cancel(
        _getCourtNotificationId(caseId, 1),
      ); // 24 hours
      await _notifications.cancel(_getCourtNotificationId(caseId, 2)); // Day of
      print('✓ Court notifications cancelled for case ID: $caseId');
    } catch (e) {
      print('✗ Failed to cancel court notifications: $e');
    }
  }

  /// Generate unique notification ID for court dates
  /// Using prime numbers to avoid collision with event IDs
  int _getCourtNotificationId(int caseId, int type) {
    return (caseId * 3) + type;
  }

  Future<void> cancelAllNotificationsForCase({
    required int caseId,
    required List<int> eventIds,
  }) async {
    try {
      // Cancel court date notifications
      await cancelNotificationsForCase(caseId);

      // Cancel all event notifications for this case
      for (final eventId in eventIds) {
        await cancelNotificationsForEvent(eventId);
      }

      print(
        '✓ All notifications cancelled for case ID: $caseId and ${eventIds.length} events',
      );
    } catch (e) {
      print('✗ Failed to cancel all case notifications: $e');
    }
  }

  // ============================================================================
  // EVENT NOTIFICATIONS
  // ============================================================================

  /// Schedule notifications for an event
  /// Schedules 2 notifications:
  /// 1. 24 hours before at 9 AM
  /// 2. 2 hours before event time (or 9 AM if no time set)
  Future<void> scheduleEventNotifications({
    required int eventId,
    required DateTime eventDate,
    required String eventAgenda,
    required String caseName,
    TimeOfDay? eventTime,
  }) async {
    if (!_isInitialized) {
      print('✗ Notification service not initialized');
      return;
    }

    // Cancel existing notifications for this event first
    await cancelNotificationsForEvent(eventId);

    // Don't schedule if date is in the past
    if (eventDate.isBefore(DateTime.now())) {
      print('⚠ Event date is in the past, skipping notification scheduling');
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'event_reminders',
          'Event Reminders',
          channelDescription: 'Notifications for upcoming case events',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF10B981), // Green for events
          enableLights: true,
          enableVibration: true,
          playSound: true,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    int scheduledCount = 0;

    // ========== 1. Schedule 24 hours before (at 7 AM) ==========
    final oneDayBefore = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      7, // 7 AM
      0,
    ).subtract(const Duration(days: 1));

    if (oneDayBefore.isAfter(DateTime.now())) {
      try {
        await _notifications.zonedSchedule(
          _getEventNotificationId(eventId, 0),
          '📅 Event Tomorrow',
          '$eventAgenda - $caseName',
          tz.TZDateTime.from(oneDayBefore, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'event_$eventId',
        );
        scheduledCount++;
        print('  → 1-day reminder: ${oneDayBefore.toString()}');
      } catch (e) {
        print('  ✗ Failed to schedule 1-day event reminder: $e');
      }
    }

    // ========== 2. Schedule 2 hours before (or day of at 9 AM if no time) ==========
    final eventHour = eventTime != null ? eventTime.hour : 9;
    final eventMinute = eventTime != null ? eventTime.minute : 0;

    DateTime reminderTime = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      eventHour,
      eventMinute,
    );

    // If event time is set, notify 2 hours before
    if (eventTime != null) {
      reminderTime = reminderTime.subtract(const Duration(hours: 2));
    }

    if (reminderTime.isAfter(DateTime.now())) {
      try {
        await _notifications.zonedSchedule(
          _getEventNotificationId(eventId, 1),
          '📅 Event Soon: $eventAgenda',
          eventTime != null
              ? '$caseName at ${_formatTime(eventTime)}'
              : '$caseName today',
          tz.TZDateTime.from(reminderTime, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'event_$eventId',
        );
        scheduledCount++;
        print('  → Event reminder: ${reminderTime.toString()}');
      } catch (e) {
        print('  ✗ Failed to schedule event reminder: $e');
      }
    }

    print(
      '✓ Event notifications scheduled: $eventAgenda ($scheduledCount reminders)',
    );
  }

  /// Cancel all notifications for a specific event
  Future<void> cancelNotificationsForEvent(int eventId) async {
    try {
      await _notifications.cancel(
        _getEventNotificationId(eventId, 0),
      ); // 24 hours
      await _notifications.cancel(
        _getEventNotificationId(eventId, 1),
      ); // 2 hours before
      print('✓ Event notifications cancelled for event ID: $eventId');
    } catch (e) {
      print('✗ Failed to cancel event notifications: $e');
    }
  }

  /// Generate unique notification ID for events
  /// Using different multiplier (prime number) to avoid collision with court dates
  int _getEventNotificationId(int eventId, int type) {
    return (eventId * 7) + type + 100000; // Offset by 100000 to avoid collision
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Cancel all notifications (court dates and events)
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      print('✓ All notifications cancelled');
    } catch (e) {
      print('✗ Failed to cancel all notifications: $e');
    }
  }

  /// Get list of pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      print('📋 Pending notifications: ${pending.length}');
      for (var notification in pending) {
        print('  - ID: ${notification.id}, Title: ${notification.title}');
      }
      return pending;
    } catch (e) {
      print('✗ Failed to get pending notifications: $e');
      return [];
    }
  }

  /// Format date for display in notifications
  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final day = date.day;
    final month = months[date.month - 1];
    final year = date.year;

    return '$day $month $year';
  }

  /// Format time for display in notifications
  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Check if notification permissions are granted
  Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Open app settings for notification permissions
  Future<void> openNotificationSettings() async {
    await openAppSettings();
  }
}

// Global instance
final notificationService = NotificationService();
