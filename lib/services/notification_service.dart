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
      await requestExactAlarmPermission();

      _isInitialized = true;
      print('✓ Notification service initialized successfully');
    } catch (e) {
      print('✗ Failed to initialize notification service: $e');
    }
  }

  Future<void> requestExactAlarmPermission() async {
    print('Requesting exact alarm permission for Android');
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
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

  // schedule notification for testing - FIXED VERSION
  Future<void> scheduleTestNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      print('✗ Notification service not initialized');
      return;
    }

    try {
      // 1. Get current time
      final DateTime now = DateTime.now();

      // 2. Create a future date (10 seconds from now)
      final DateTime futureDate = now.add(const Duration(seconds: 10));

      // 3. FORCE parsing into TZDateTime as per the Stack Overflow solution
      // This ensures the timezone matches exactly what the plugin expects
      final tz.TZDateTime scheduledDate = tz.TZDateTime.parse(
        tz.local,
        futureDate.toString().replaceAll(
          'Z',
          '',
        ), // remove Z if present to ensure local parse
      );

      print('Current time: $now');
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
        // Note: androidScheduleMode replaces androidAllowWhileIdle in newer versions (v10+)
        // If your version is older, swap this line back to: androidAllowWhileIdle: true,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      print('✓ Test notification scheduled successfully');

      // Verify
      final pending = await _notifications.pendingNotificationRequests();
      print('Pending notifications count: ${pending.length}');
    } catch (e) {
      print('✗ Failed to schedule test notification: $e');
      if (e.toString().contains("Must be a date in the future")) {
        print(
          "⚠ Error: The calculated date was in the past. Try increasing the duration.",
        );
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      // Request notification permission
      if (await Permission.notification.isDenied) {
        final status = await Permission.notification.request();
        if (status.isGranted) {
          print('✓ Notification permission granted');
        } else {
          print('✗ Notification permission denied');
        }
      } else {
        print('✓ Notification permission already granted');
      }

      // Request schedule exact alarm permission for Android 12+
      final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
      print('📱 Schedule Exact Alarm status: $exactAlarmStatus');

      if (exactAlarmStatus.isDenied || exactAlarmStatus.isPermanentlyDenied) {
        print('⚠ Requesting exact alarm permission...');
        final status = await Permission.scheduleExactAlarm.request();
        if (status.isGranted) {
          print('✓ Schedule exact alarm permission granted');
        } else {
          print('✗ Schedule exact alarm permission denied');
          print('⚠ User needs to enable this manually in settings');
        }
      } else if (exactAlarmStatus.isGranted) {
        print('✓ Schedule exact alarm permission already granted');
      }
    } catch (e) {
      print('✗ Error requesting permissions: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
  }

  // ============================================================================
  // COURT DATE NOTIFICATIONS
  // ============================================================================

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

    await cancelNotificationsForCase(caseId);

    final now = DateTime.now();

    // Build the full court DateTime including time
    final courtHour = courtTime != null ? courtTime.hour : 23;
    final courtMinute = courtTime != null ? courtTime.minute : 59;

    DateTime fullCourtDateTime = DateTime(
      courtDate.year,
      courtDate.month,
      courtDate.day,
      courtHour,
      courtMinute,
      0,
    );

    print('📅 Scheduling notifications for: $caseName');
    print('   Court date: $courtDate');
    print(
      '   Court time: ${courtTime != null ? _formatTime(courtTime) : "Not specified"}',
    );
    print('   Full court DateTime: $fullCourtDateTime');
    print('   Current time: $now');

    // Check if the FULL court date/time is in the past
    if (fullCourtDateTime.isBefore(now)) {
      print(
        '⚠ Court date/time is in the past, skipping notification scheduling',
      );
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'court_reminders',
          'Court Date Reminders',
          channelDescription: 'Notifications for upcoming court dates',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    int scheduledCount = 0;

    // ============================================================================
    // NOTIFICATION 1: ONE DAY BEFORE AT 7 AM
    // ============================================================================
    try {
      // Create the exact date/time for notification: 1 day before court date at 7:00 AM
      DateTime oneDayBeforeAt7AM = DateTime(
        courtDate.year,
        courtDate.month,
        courtDate.day,
        7, // 7 AM
        0, // 0 minutes
        0, // 0 seconds
      ).subtract(const Duration(days: 1)); // Subtract 1 day

      print('   Calculated 1-day-before time: $oneDayBeforeAt7AM');

      // Only schedule if this time is in the future
      if (oneDayBeforeAt7AM.isAfter(now)) {
        // Parse into TZDateTime using the SAME method that worked in test
        final tz.TZDateTime scheduledDate = tz.TZDateTime.parse(
          tz.local,
          oneDayBeforeAt7AM.toString().replaceAll('Z', ''),
        );

        await _notifications.zonedSchedule(
          _getCourtNotificationId(caseId, 0),
          '⚖️ Court Date Tomorrow',
          '$caseName at ${courtTime != null ? _formatTime(courtTime) : "scheduled time"}',
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'case_$caseId',
        );

        scheduledCount++;
        print('   ✅ 1-day reminder scheduled for: $oneDayBeforeAt7AM');
      } else {
        print('   ⚠ 1-day reminder time has passed, skipping');
      }
    } catch (e) {
      print('   ✗ Failed to schedule 1-day reminder: $e');
    }

    // ============================================================================
    // NOTIFICATION 2: 1 HOUR BEFORE COURT TIME (OR 9 AM IF NO TIME SET)
    // ============================================================================

    try {
      // TEMPORARY: Schedule for 10 seconds from now instead of 1 hour before
      DateTime oneHourBefore = now.add(const Duration(seconds: 10));

      print('   Court time: $fullCourtDateTime');
      print('   Calculated 1-hour-before time (TEST - 10 sec): $oneHourBefore');

      // Only schedule if this time is in the future
      if (oneHourBefore.isAfter(now)) {
        // Parse into TZDateTime
        final tz.TZDateTime scheduledDate = tz.TZDateTime.parse(
          tz.local,
          oneHourBefore.toString().replaceAll('Z', ''),
        );

        await _notifications.zonedSchedule(
          _getCourtNotificationId(caseId, 1),
          '⚖️ Court Date in 1 Hour! (TEST)',
          '$caseName at ${courtTime != null ? _formatTime(courtTime) : "9:00 AM"}',
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'case_$caseId',
        );

        scheduledCount++;
        print('   ✅ 1-hour reminder scheduled for: $oneHourBefore');
      } else {
        print('   ⚠ 1-hour reminder time has passed, skipping');
      }
    } catch (e) {
      print('   ✗ Failed to schedule 1-hour reminder: $e');
    }

    print('✅ Scheduled $scheduledCount of 2 possible reminders for: $caseName');

    // Verify scheduled notifications
    final pending = await _notifications.pendingNotificationRequests();
    print('📋 Total pending notifications: ${pending.length}');
    for (var notification in pending) {
      print('   - ID: ${notification.id}, Title: ${notification.title}');
    }
  }

  Future<void> cancelNotificationsForCase(int caseId) async {
    try {
      await _notifications.cancel(_getCourtNotificationId(caseId, 0));
      await _notifications.cancel(_getCourtNotificationId(caseId, 1));
      await _notifications.cancel(_getCourtNotificationId(caseId, 2));
      print('✓ Court notifications cancelled for case ID: $caseId');
    } catch (e) {
      print('✗ Failed to cancel court notifications: $e');
    }
  }

  int _getCourtNotificationId(int caseId, int type) {
    return (caseId * 3) + type;
  }

  Future<void> cancelAllNotificationsForCase({
    required int caseId,
    required List<int> eventIds,
  }) async {
    try {
      await cancelNotificationsForCase(caseId);

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

    await cancelNotificationsForEvent(eventId);

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
          color: Color(0xFF10B981),
          enableLights: true,
          enableVibration: true,
          playSound: true,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    int scheduledCount = 0;

    // 24 hours before at 7 AM
    final oneDayBefore = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      7,
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

    // 2 hours before (or 9 AM if no time)
    final eventHour = eventTime != null ? eventTime.hour : 9;
    final eventMinute = eventTime != null ? eventTime.minute : 0;

    DateTime reminderTime = DateTime(
      eventDate.year,
      eventDate.month,
      eventDate.day,
      eventHour,
      eventMinute,
    );

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

  Future<void> cancelNotificationsForEvent(int eventId) async {
    try {
      await _notifications.cancel(_getEventNotificationId(eventId, 0));
      await _notifications.cancel(_getEventNotificationId(eventId, 1));
      print('✓ Event notifications cancelled for event ID: $eventId');
    } catch (e) {
      print('✗ Failed to cancel event notifications: $e');
    }
  }

  int _getEventNotificationId(int eventId, int type) {
    return (eventId * 7) + type + 100000;
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      print('✓ All notifications cancelled');
    } catch (e) {
      print('✗ Failed to cancel all notifications: $e');
    }
  }

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

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<void> openNotificationSettings() async {
    await openAppSettings();
  }
}

final notificationService = NotificationService();
