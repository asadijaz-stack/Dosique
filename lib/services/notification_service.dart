import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';
import 'schedule_engine.dart';

/// Local notification scheduling for Dosique.
///
/// Strategy: cancel everything and re-schedule a rolling 14-day window on
/// every data change / app launch. Channel + sound follow the user's chosen
/// tone. Exact alarms are tried first, with a graceful inexact fallback.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _soundIndex = 0;

  String get _channelId => 'doses_${SoundTones.fileFor(_soundIndex)}';

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fall back to UTC-based local if the platform lookup fails.
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings: initSettings);
    _ready = true;
  }

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    final granted = await android.requestNotificationsPermission();
    // Exact alarms make dose reminders fire on time; denial is not fatal —
    // scheduling falls back to inexact mode.
    try {
      await android.requestExactAlarmsPermission();
    } catch (_) {}
    return granted ?? false;
  }

  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    return await android.areNotificationsEnabled() ?? false;
  }

  NotificationDetails _details({String? channelName}) {
    final tone = SoundTones.fileFor(_soundIndex);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        channelName ?? 'Medication reminders',
        channelDescription: 'Dose reminders with your chosen tone',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound(tone),
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      ),
    );
  }

  tz.TZDateTime _tz(DateTime d) => tz.TZDateTime.from(d, tz.local);

  int _idFor(String key) => key.hashCode & 0x3fffffff;

  Future<void> _schedule(
    int id,
    String title,
    String body,
    DateTime when,
  ) async {
    if (when.isBefore(DateTime.now())) return;
    final details = _details();
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: _tz(when),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: _tz(when),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Dosique: could not schedule notification: $e');
      }
    }
  }

  /// Rebuild the whole rolling window from current data.
  Future<void> rescheduleAll({
    required List<Medication> meds,
    required List<DoseLog> logs,
    required List<Appointment> appointments,
    required int soundIndex,
    required int refillSummaryWeekday,
    required String profileName,
  }) async {
    await init();
    _soundIndex = soundIndex;
    await _plugin.cancelAll();
    final now = DateTime.now();

    // NOTE: dose reminders are NOT scheduled here anymore — they ring as
    // forceful looping alarms via DoseAlarmService. This service now only
    // handles the quieter reminders below (low stock, expiry, appointments,
    // weekly refill summary). [logs] is kept in the signature for callers.
    for (final med in meds) {
      if (med.archived) continue;
      // Low-stock refill reminder: today at 18:00 if low, else when the
      // projected stock-out day approaches (checked again on each rebuild).
      if (isLowStock(med) && med.stockQty > 0) {
        await _schedule(
          _idFor('lowstock_${med.id}_${dayOnly(now)}'),
          'Running low: ${med.name}',
          'About ${med.stockQty % 1 == 0 ? med.stockQty.toInt() : med.stockQty} ${med.form.unit} left. Time to refill.',
          DateTime(now.year, now.month, now.day, 18),
        );
      }
      // Expiry alerts.
      if (med.expiryDate != null) {
        final exp = med.expiryDate!;
        final warn = exp.subtract(const Duration(days: 30));
        if (warn.isAfter(now)) {
          await _schedule(
            _idFor('exp30_${med.id}'),
            '${med.name} expires in 30 days',
            'Expiry date: ${exp.day}/${exp.month}/${exp.year}. Plan a replacement with your pharmacist.',
            DateTime(warn.year, warn.month, warn.day, 9),
          );
        }
        if (exp.isAfter(now)) {
          await _schedule(
            _idFor('exp0_${med.id}'),
            '${med.name} expires today',
            'Check with your pharmacist before using expired medicine.',
            DateTime(exp.year, exp.month, exp.day, 9),
          );
        }
      }
    }

    // Appointment reminders: 1 day before at 09:00 + 1 hour before.
    for (final a in appointments) {
      if (a.dateTime.isBefore(now)) continue;
      final dayBefore = DateTime(
        a.dateTime.year,
        a.dateTime.month,
        a.dateTime.day,
        9,
      ).subtract(const Duration(days: 1));
      final body = [a.title, if (a.place.isNotEmpty) a.place].join(' · ');
      await _schedule(
        _idFor('appt_pre_${a.id}'),
        'Appointment tomorrow',
        body,
        dayBefore,
      );
      await _schedule(
        _idFor('appt_1h_${a.id}'),
        'Appointment in 1 hour',
        body,
        a.dateTime.subtract(const Duration(hours: 1)),
      );
    }

    // Weekly refill summary on the chosen weekday at 09:00.
    final low = meds.where((m) => !m.archived && isLowStock(m)).toList();
    if (low.isNotEmpty) {
      var d = dayOnly(now).add(const Duration(days: 1));
      while (d.weekday != refillSummaryWeekday) {
        d = d.add(const Duration(days: 1));
      }
      await _schedule(
        _idFor('refill_summary_$d'),
        'Weekly refill check',
        '${low.map((m) => m.name).join(', ')} running low.',
        DateTime(d.year, d.month, d.day, 9),
      );
    }
  }

  /// One-off snooze reminder for a single dose.
  Future<void> snooze({
    required Medication med,
    required String profileName,
    required int minutes,
  }) async {
    await init();
    final when = DateTime.now().add(Duration(minutes: minutes));
    final body = [
      if (med.strength.isNotEmpty) med.strength,
      if (med.instruction.isNotEmpty) med.instruction,
      'for $profileName',
      '(snoozed)',
    ].join(' · ');
    await _schedule(
      _idFor('snooze_${med.id}_${when.millisecondsSinceEpoch}'),
      'Time for ${med.name}',
      body,
      when,
    );
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
