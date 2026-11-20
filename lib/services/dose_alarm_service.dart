import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'schedule_engine.dart';

/// Forceful alarm-clock style ringing for DOSE reminders.
///
/// Plain notifications can be silently swallowed by aggressive OEM battery
/// managers (TECNO/HiOS etc.). Dose reminders therefore use the `alarm`
/// package instead: at dose time a foreground service rings the chosen tone
/// in a loop at full alarm volume, vibrates, and turns the screen on with a
/// full-screen alert — like an alarm clock — until the user acts on it.
///
/// Other reminders (appointments, low stock, expiry, refill summary) stay as
/// normal notifications in [NotificationService].
class DoseAlarmService {
  DoseAlarmService._();
  static final DoseAlarmService instance = DoseAlarmService._();

  static const _mapKey = 'dosique_alarm_map_v1';
  static const _windowDays = 14;

  bool _ready = false;

  /// alarm id -> dose info, persisted so a ring that relaunches the app can
  /// still find which dose it belongs to.
  final Map<String, Map<String, String>> _map = {};

  int _idFor(String key) => key.hashCode & 0x3fffffff;

  Future<void> init() async {
    if (_ready) return;
    try {
      await Alarm.init(showDebugLogs: false);
      _ready = true;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_mapKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _map
          ..clear()
          ..addAll(
            decoded.map(
              (k, v) => MapEntry(k, Map<String, String>.from(v as Map)),
            ),
          );
      }
    } catch (e) {
      debugPrint('Dosique: alarm init failed: $e');
    }
  }

  Future<void> _persistMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_mapKey, jsonEncode(_map));
    } catch (_) {}
  }

  Map<String, String>? lookup(int alarmId) => _map['$alarmId'];

  Future<void> stop(int alarmId) async {
    try {
      await Alarm.stop(alarmId);
    } catch (_) {}
  }

  Future<bool> _setAlarm({
    required int id,
    required DateTime when,
    required String medId,
    required String medName,
    required DateTime scheduledFor,
    required String body,
    required int soundIndex,
  }) async {
    _map['$id'] = {
      'medId': medId,
      'medName': medName,
      'scheduledFor': scheduledFor.toIso8601String(),
      'body': body,
    };
    try {
      return await Alarm.set(
        alarmSettings: AlarmSettings(
          id: id,
          dateTime: when,
          assetAudioPath: 'assets/sounds/${SoundTones.fileFor(soundIndex)}.wav',
          loopAudio: true,
          vibrate: true,
          // Ring at full volume on the alarm stream, and keep it there
          // even if the user presses volume-down while it rings.
          volume: 1.0,
          volumeEnforced: true,
          fadeDuration: 0.0,
          warningNotificationOnKill: false,
          androidFullScreenIntent: true,
          notificationSettings: NotificationSettings(
            title: 'Time for $medName',
            body: body,
            stopButton: 'Stop',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Dosique: could not set dose alarm: $e');
      return false;
    }
  }

  /// Rebuild every dose alarm for the next 14 days from current data.
  /// Mirrors the window NotificationService used to schedule, minus doses
  /// already logged.
  Future<void> syncDoseAlarms({
    required List<Medication> meds,
    required List<DoseLog> logs,
    required int soundIndex,
    required String profileName,
  }) async {
    await init();
    if (!_ready) return;
    try {
      await Alarm.stopAll();
    } catch (_) {}
    _map.clear();

    final now = DateTime.now();
    final end = now.add(const Duration(days: _windowDays));
    final logKeys = {for (final l in logs) l.key};

    for (final med in meds) {
      if (med.archived) continue;
      final body = [
        if (med.strength.isNotEmpty) med.strength,
        if (med.instruction.isNotEmpty) med.instruction,
        'for $profileName',
      ].join(' · ');
      for (final s in med.schedules) {
        for (final t in occurrencesBetween(s, now, end)) {
          if (t.isBefore(now)) continue;
          if (logKeys.contains('${med.id}_${t.toIso8601String()}')) continue;
          await _setAlarm(
            id: _idFor('dose_${med.id}_${t.toIso8601String()}'),
            when: t,
            medId: med.id,
            medName: med.name,
            scheduledFor: t,
            body: body,
            soundIndex: soundIndex,
          );
        }
      }
    }
    await _persistMap();
  }

  /// One-off forceful re-ring for a snoozed dose.
  Future<void> snooze({
    required Medication med,
    required DateTime scheduledFor,
    required String profileName,
    required int soundIndex,
    required int minutes,
  }) async {
    await init();
    if (!_ready) return;
    final when = DateTime.now().add(Duration(minutes: minutes));
    final body = [
      if (med.strength.isNotEmpty) med.strength,
      if (med.instruction.isNotEmpty) med.instruction,
      'for $profileName',
      '(snoozed)',
    ].join(' · ');
    await _setAlarm(
      id: _idFor('snooze_${med.id}_${when.millisecondsSinceEpoch}'),
      when: when,
      medId: med.id,
      medName: med.name,
      scheduledFor: scheduledFor,
      body: body,
      soundIndex: soundIndex,
    );
    await _persistMap();
  }
}
