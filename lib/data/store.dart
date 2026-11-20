import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/dose_alarm_service.dart';
import '../services/notification_service.dart';
import '../services/schedule_engine.dart';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().hashCode & 0xffff}';

/// Single source of truth. All data lives in one JSON blob in
/// SharedPreferences; photos live as files in the app documents dir.
/// No account, no server, nothing leaves the device except what the
/// user explicitly shares.
class AppStore extends ChangeNotifier {
  static const _prefsKey = 'dosique_state_v1';

  List<Profile> profiles = [];
  List<Medication> meds = [];
  List<DoseLog> logs = [];
  List<Appointment> appointments = [];
  final AppSettings settings = AppSettings();
  bool loaded = false;

  // ---------- derived ----------

  Profile get currentProfile {
    final p = profiles.where((e) => e.id == settings.currentProfileId);
    if (p.isNotEmpty) return p.first;
    return profiles.isNotEmpty ? profiles.first : Profile(id: 'me', name: 'Me');
  }

  List<Medication> medsFor(String profileId) =>
      meds.where((m) => m.profileId == profileId).toList();

  List<Medication> get currentMeds => medsFor(currentProfile.id);

  List<DoseLog> logsFor(String profileId) =>
      logs.where((l) => l.profileId == profileId).toList();

  List<DoseLog> get currentLogs => logsFor(currentProfile.id);

  List<Appointment> get currentAppointments {
    final list =
        appointments.where((a) => a.profileId == currentProfile.id).toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return list;
  }

  List<DoseInstance> todayInstances() =>
      instancesForDay(currentMeds, currentLogs, DateTime.now());

  Medication? medById(String id) {
    for (final m in meds) {
      if (m.id == id) return m;
    }
    return null;
  }

  // ---------- persistence ----------

  Map<String, dynamic> toJson() => {
    'version': 1,
    'profiles': profiles.map((p) => p.toJson()).toList(),
    'meds': meds.map((m) => m.toJson()).toList(),
    'logs': logs.map((l) => l.toJson()).toList(),
    'appointments': appointments.map((a) => a.toJson()).toList(),
    'settings': settings.toJson(),
  };

  void loadFromJson(Map<String, dynamic> j) {
    profiles = (j['profiles'] as List? ?? [])
        .map((e) => Profile.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    meds = (j['meds'] as List? ?? [])
        .map((e) => Medication.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    logs = (j['logs'] as List? ?? [])
        .map((e) => DoseLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    appointments = (j['appointments'] as List? ?? [])
        .map((e) => Appointment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (j['settings'] is Map) {
      settings.loadJson(Map<String, dynamic>.from(j['settings'] as Map));
    }
    if (profiles.isEmpty) {
      final me = Profile(id: newId(), name: 'Me');
      profiles = [me];
      settings.currentProfileId = me.id;
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        loadFromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (e) {
        debugPrint('Dosique: state load failed: $e');
        profiles = [Profile(id: newId(), name: 'Me')];
        settings.currentProfileId = profiles.first.id;
      }
    } else {
      final me = Profile(id: newId(), name: 'Me');
      profiles = [me];
      settings.currentProfileId = me.id;
    }
    loaded = true;
    notifyListeners();
    await rescheduleNotifications();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(toJson()));
  }

  Future<void> _commit() async {
    await _save();
    notifyListeners();
    await rescheduleNotifications();
  }

  Future<void> rescheduleNotifications() async {
    try {
      await NotificationService.instance.rescheduleAll(
        meds: currentMeds,
        logs: currentLogs,
        appointments: currentAppointments,
        soundIndex: settings.soundIndex,
        refillSummaryWeekday: settings.refillSummaryWeekday,
        profileName: currentProfile.name,
      );
    } catch (e) {
      debugPrint('Dosique: reschedule failed: $e');
    }
    // Dose reminders ring as forceful alarms (separate engine).
    try {
      await DoseAlarmService.instance.syncDoseAlarms(
        meds: currentMeds,
        logs: currentLogs,
        soundIndex: settings.soundIndex,
        profileName: currentProfile.name,
      );
    } catch (e) {
      debugPrint('Dosique: dose alarm sync failed: $e');
    }
  }

  void haptic() {
    if (settings.haptics) HapticFeedback.lightImpact();
  }

  // ---------- profiles ----------

  Future<void> switchProfile(String id) async {
    settings.currentProfileId = id;
    await _commit();
  }

  Future<Profile> addProfile(String name, ProfileKind kind, int color) async {
    final p = Profile(id: newId(), name: name, kind: kind, colorValue: color);
    profiles.add(p);
    await _commit();
    return p;
  }

  Future<void> updateProfile(Profile p) async => _commit();

  Future<void> deleteProfile(String id) async {
    if (profiles.length <= 1) return;
    profiles.removeWhere((p) => p.id == id);
    meds.removeWhere((m) => m.profileId == id);
    logs.removeWhere((l) => l.profileId == id);
    appointments.removeWhere((a) => a.profileId == id);
    if (settings.currentProfileId == id) {
      settings.currentProfileId = profiles.first.id;
    }
    await _commit();
  }

  // ---------- medications ----------

  Future<void> saveMedication(Medication med) async {
    final i = meds.indexWhere((m) => m.id == med.id);
    if (i >= 0) {
      meds[i] = med;
    } else {
      meds.add(med);
    }
    await _commit();
  }

  Future<void> deleteMedication(String id) async {
    meds.removeWhere((m) => m.id == id);
    logs.removeWhere((l) => l.medId == id);
    await _commit();
  }

  Future<void> setArchived(Medication med, bool archived) async {
    med.archived = archived;
    await _commit();
  }

  Future<void> refill(Medication med, double addQty) async {
    med.stockQty += addQty;
    await _commit();
  }

  Future<String?> saveMedPhoto(String medId, File picked) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dest = File('${dir.path}/med_$medId.jpg');
      await picked.copy(dest.path);
      return dest.path;
    } catch (_) {
      return null;
    }
  }

  // ---------- dose logging ----------

  DoseLog? logFor(DoseInstance inst) {
    for (final l in logs) {
      if (l.key == inst.key && !l.isPrn) return l;
    }
    return null;
  }

  /// Set a scheduled dose's status, keeping stock in sync.
  /// Pass [status] null to clear the log (undo back to unmarked).
  Future<void> setDoseStatus(
    DoseInstance inst,
    DoseStatus? status, {
    String skipReason = '',
    DateTime? takenAt,
  }) async {
    final med = inst.med;
    final existing = logFor(inst);
    final wasTaken = existing?.status == DoseStatus.taken;

    if (existing != null) logs.remove(existing);

    if (status == DoseStatus.taken && !wasTaken) {
      med.stockQty = (med.stockQty - med.doseAmount).clamp(0, double.infinity);
    } else if (status != DoseStatus.taken && wasTaken) {
      med.stockQty += med.doseAmount;
    }

    if (status != null) {
      logs.add(
        DoseLog(
          id: existing?.id ?? newId(),
          profileId: med.profileId,
          medId: med.id,
          scheduledFor: inst.scheduledFor,
          status: status,
          takenAt: status == DoseStatus.taken
              ? (takenAt ?? DateTime.now())
              : null,
          skipReason: status == DoseStatus.skipped ? skipReason : '',
          doseAmount: med.doseAmount,
        ),
      );
    }
    haptic();
    await _commit();
  }

  /// Quick-log an as-needed (PRN) dose in two taps.
  Future<void> logPrn(Medication med) async {
    logs.add(
      DoseLog(
        id: newId(),
        profileId: med.profileId,
        medId: med.id,
        scheduledFor: DateTime.now(),
        status: DoseStatus.taken,
        takenAt: DateTime.now(),
        isPrn: true,
        doseAmount: med.doseAmount,
      ),
    );
    med.stockQty = (med.stockQty - med.doseAmount).clamp(0, double.infinity);
    haptic();
    await _commit();
  }

  Future<void> deleteLog(DoseLog log) async {
    logs.removeWhere((l) => l.id == log.id);
    if (log.status == DoseStatus.taken) {
      final med = medById(log.medId);
      if (med != null) med.stockQty += log.doseAmount;
    }
    await _commit();
  }

  // ---------- appointments ----------

  Future<void> saveAppointment(Appointment a) async {
    final i = appointments.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      appointments[i] = a;
    } else {
      appointments.add(a);
    }
    await _commit();
  }

  Future<void> deleteAppointment(String id) async {
    appointments.removeWhere((a) => a.id == id);
    await _commit();
  }

  // ---------- settings ----------

  Future<void> updateSettings() async => _commit();

  Future<void> finishOnboarding() async {
    settings.onboardingDone = true;
    settings.disclaimerAck = true;
    await _commit();
  }

  // ---------- backup ----------

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  Future<bool> importJson(String raw) async {
    try {
      final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (j['version'] == null) return false;
      loadFromJson(j);
      await _commit();
      return true;
    } catch (_) {
      return false;
    }
  }
}
