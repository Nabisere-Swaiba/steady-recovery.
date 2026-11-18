import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class RiskyWindow {
  final int weekday;
  final int bucket;
  final int samples;
  final double averageCraving;
  final double differenceFromAverage;

  const RiskyWindow({
    required this.weekday,
    required this.bucket,
    required this.samples,
    required this.averageCraving,
    required this.differenceFromAverage,
  });

  int get startHour => const [5, 12, 17, 21][bucket];

  String get label =>
      const ['morning', 'afternoon', 'evening', 'night'][bucket];

  String get weekdayLabel => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][weekday - 1];

  int get notificationId => 4200 + (weekday - 1) * 4 + bucket;
}

class ReminderService {
  ReminderService._();

  static const _dailyNotificationId = 4100;
  static const _firstRiskNotificationId = 4200;
  static const _lastRiskNotificationId = 4227;
  static const _dailyTitle = 'Time for your check-in';
  static const _dailyBody = 'A moment for yourself.';
  static const _riskTitle = 'A moment for yourself';
  static const _riskBody = 'Take a pause if it helps.';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final ValueNotifier<List<RiskyWindow>> riskyWindows =
      ValueNotifier<List<RiskyWindow>>(<RiskyWindow>[]);

  static bool _initialized = false;
  static String? _pendingRoute;
  static void Function(String route)? _onNotificationTap;

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static void setNotificationTapHandler(void Function(String route) handler) {
    _onNotificationTap = handler;
  }

  static String? takePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  static Future<void> initialize() async {
    if (!isSupported || _initialized) return;

    tz_data.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    } catch (e) {
      debugPrint(
          'Could not read the device timezone; using Africa/Kampala: $e');
      tz.setLocalLocation(tz.getLocation('Africa/Kampala'));
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _setPendingRoute(launchDetails?.notificationResponse?.payload);
    }
    _initialized = true;
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    final route = response.payload;
    if (route == null || route.isEmpty) return;
    _pendingRoute = route;
    _onNotificationTap?.call(route);
  }

  static void _setPendingRoute(String? route) {
    if (route != null && route.isNotEmpty) _pendingRoute = route;
  }

  static String _key(String userId, String name) => 'reminder.$userId.$name';

  static Future<bool> dailyEnabled(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(userId, 'daily_enabled')) ?? false;
  }

  static Future<bool> riskyEnabled(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(userId, 'risky_enabled')) ?? false;
  }

  static Future<int> dailyMinuteOfDay(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(userId, 'daily_minute')) ?? 20 * 60;
  }

  static Future<bool> requestNotificationPermission() async {
    if (!isSupported) return false;
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;

    if (await android.areNotificationsEnabled() == true) return true;
    final requested = await android.requestNotificationsPermission();
    if (requested == true) return true;
    return await android.areNotificationsEnabled() ?? false;
  }

  static Future<bool> notificationsEnabled() async {
    if (!isSupported) return false;
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? false;
  }

  static Future<void> saveSettings({
    required String userId,
    required bool dailyReminderEnabled,
    required bool riskyReminderEnabled,
    required int dailyReminderMinute,
  }) async {
    await initialize();
    if ((dailyReminderEnabled || riskyReminderEnabled) &&
        !await requestNotificationPermission()) {
      throw StateError(
        'Notifications are off. Allow notifications in Android settings to turn on reminders.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(userId, 'daily_enabled'), dailyReminderEnabled);
    await prefs.setBool(_key(userId, 'risky_enabled'), riskyReminderEnabled);
    await prefs.setInt(_key(userId, 'daily_minute'), dailyReminderMinute);
    await refreshForUser(userId);
  }

  static Future<void> refreshForUser(String userId) async {
    await initialize();
    final windows = await _findRiskyWindows(userId);
    riskyWindows.value = windows;
    if (!isSupported) return;

    final prefs = await SharedPreferences.getInstance();
    var enableDaily = prefs.getBool(_key(userId, 'daily_enabled')) ?? false;
    var enableRisky = prefs.getBool(_key(userId, 'risky_enabled')) ?? false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final allowed = await android?.areNotificationsEnabled() ?? false;

    await _cancelScheduledNotifications();
    if (!allowed) return;

    if (enableDaily) {
      await _scheduleDaily(await dailyMinuteOfDay(userId));
    }
    if (enableRisky) {
      for (final window in windows) {
        await _scheduleRiskyWindow(window);
      }
    }
  }

  static Future<void> refreshOnAppOpen(String userId) async {
    try {
      await refreshForUser(userId);
    } catch (e) {
      debugPrint('Could not refresh reminders: $e');
    }
  }

  static Future<List<RiskyWindow>> findRiskyWindowsForBanner(
      String userId) async {
    final windows = await _findRiskyWindows(userId);
    riskyWindows.value = windows;
    return windows;
  }

  static Future<List<RiskyWindow>> _findRiskyWindows(String userId) async {
    final since = DateTime.now()
        .subtract(const Duration(days: 60))
        .toUtc()
        .toIso8601String();
    final rows = await Supabase.instance.client
        .from('checkins')
        .select('created_at,craving')
        .eq('user_id', userId)
        .gte('created_at', since);

    var totalCraving = 0.0;
    var totalSamples = 0;
    final samples = <String, List<num>>{};

    for (final row in rows) {
      final date = DateTime.tryParse('${row['created_at'] ?? ''}')?.toLocal();
      final craving = row['craving'];
      if (date == null || craving is! num) continue;

      totalCraving += craving;
      totalSamples++;

      var weekday = date.weekday;
      final hour = date.hour;
      late final int bucket;
      if (hour < 5) {
        bucket = 3;
        weekday = weekday == 1 ? 7 : weekday - 1;
      } else if (hour < 12) {
        bucket = 0;
      } else if (hour < 17) {
        bucket = 1;
      } else if (hour < 21) {
        bucket = 2;
      } else {
        bucket = 3;
      }
      samples.putIfAbsent('$weekday:$bucket', () => <num>[]).add(craving);
    }

    if (totalSamples == 0) return <RiskyWindow>[];
    final overallAverage = totalCraving / totalSamples;
    final windows = <RiskyWindow>[];
    for (final entry in samples.entries) {
      final values = entry.value;
      if (values.length < 3) continue;
      final average =
          values.fold<num>(0, (sum, value) => sum + value) / values.length;
      final difference = average - overallAverage;
      if (difference < 1.5) continue;
      final key = entry.key.split(':');
      windows.add(RiskyWindow(
        weekday: int.parse(key[0]),
        bucket: int.parse(key[1]),
        samples: values.length,
        averageCraving: average.toDouble(),
        differenceFromAverage: difference,
      ));
    }
    windows.sort((a, b) {
      final byDifference =
          b.differenceFromAverage.compareTo(a.differenceFromAverage);
      return byDifference != 0 ? byDifference : b.samples.compareTo(a.samples);
    });
    return windows.take(3).toList();
  }

  static Future<void> _scheduleDaily(int minuteOfDay) async {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minuteOfDay ~/ 60,
      minuteOfDay % 60,
    );
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id: _dailyNotificationId,
      title: _dailyTitle,
      body: _dailyBody,
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'steady_recovery_reminders',
          'Reminders',
          channelDescription: 'Private check-in and supportive reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '/check-in',
    );
  }

  static Future<void> _scheduleRiskyWindow(RiskyWindow window) async {
    final now = tz.TZDateTime.now(tz.local);
    var notifyAt = _nextWeekdayTime(
      now,
      window.weekday,
      window.startHour,
      0,
    ).subtract(const Duration(minutes: 45));
    if (!notifyAt.isAfter(now)) {
      notifyAt = notifyAt.add(const Duration(days: 7));
    }

    await _plugin.zonedSchedule(
      id: window.notificationId,
      title: _riskTitle,
      body: _riskBody,
      scheduledDate: notifyAt,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'steady_recovery_reminders',
          'Reminders',
          channelDescription: 'Private check-in and supportive reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: '/sos',
    );
  }

  static tz.TZDateTime _nextWeekdayTime(
    tz.TZDateTime now,
    int weekday,
    int hour,
    int minute,
  ) {
    var daysUntil = (weekday - now.weekday) % 7;
    var candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).add(Duration(days: daysUntil));
    if (!candidate.isAfter(now)) {
      daysUntil += 7;
      candidate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      ).add(Duration(days: daysUntil));
    }
    return candidate;
  }

  static Future<void> _cancelScheduledNotifications() async {
    await _plugin.cancel(id: _dailyNotificationId);
    for (var id = _firstRiskNotificationId;
        id <= _lastRiskNotificationId;
        id++) {
      await _plugin.cancel(id: id);
    }
  }

  static Future<void> cancelForSignOut() async {
    if (!isSupported || !_initialized) return;
    try {
      await _cancelScheduledNotifications();
      riskyWindows.value = <RiskyWindow>[];
    } catch (e) {
      debugPrint('Could not cancel reminders during sign out: $e');
    }
  }
}
