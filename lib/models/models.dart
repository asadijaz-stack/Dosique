import 'package:flutter/material.dart';

/// Dosique data model. Everything is local-only JSON — no account, no server.

enum ProfileKind { self, family, pet }

extension ProfileKindX on ProfileKind {
  String get label => {
    ProfileKind.self: 'Me',
    ProfileKind.family: 'Family',
    ProfileKind.pet: 'Pet',
  }[this]!;
  IconData get icon => {
    ProfileKind.self: Icons.person_rounded,
    ProfileKind.family: Icons.family_restroom_rounded,
    ProfileKind.pet: Icons.pets_rounded,
  }[this]!;
}

class Profile {
  String id;
  String name;
  ProfileKind kind;
  int colorValue;
  Profile({
    required this.id,
    required this.name,
    this.kind = ProfileKind.self,
    this.colorValue = 0xFF0E9F8A,
  });
  Color get color => Color(colorValue);
  String get initial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'colorValue': colorValue,
  };
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as String,
    name: j['name'] as String? ?? 'Me',
    kind: ProfileKind.values.firstWhere(
      (e) => e.name == j['kind'],
      orElse: () => ProfileKind.self,
    ),
    colorValue: j['colorValue'] as int? ?? 0xFF0E9F8A,
  );
}

enum MedForm {
  tablet,
  capsule,
  liquid,
  drops,
  injection,
  inhaler,
  patch,
  cream,
  suppository,
  other,
}

extension MedFormX on MedForm {
  String get label => {
    MedForm.tablet: 'Tablet',
    MedForm.capsule: 'Capsule',
    MedForm.liquid: 'Liquid',
    MedForm.drops: 'Drops',
    MedForm.injection: 'Injection',
    MedForm.inhaler: 'Inhaler',
    MedForm.patch: 'Patch',
    MedForm.cream: 'Cream / ointment',
    MedForm.suppository: 'Suppository',
    MedForm.other: 'Other',
  }[this]!;
  IconData get icon => {
    MedForm.tablet: Icons.medication_rounded,
    MedForm.capsule: Icons.medication_liquid_rounded,
    MedForm.liquid: Icons.science_rounded,
    MedForm.drops: Icons.water_drop_rounded,
    MedForm.injection: Icons.vaccines_rounded,
    MedForm.inhaler: Icons.air_rounded,
    MedForm.patch: Icons.healing_rounded,
    MedForm.cream: Icons.sanitizer_rounded,
    MedForm.suppository: Icons.medication_rounded,
    MedForm.other: Icons.medical_services_rounded,
  }[this]!;

  /// Unit a single dose amount is measured in.
  String get unit => {
    MedForm.tablet: 'tablet',
    MedForm.capsule: 'capsule',
    MedForm.liquid: 'ml',
    MedForm.drops: 'drops',
    MedForm.injection: 'injection',
    MedForm.inhaler: 'puffs',
    MedForm.patch: 'patch',
    MedForm.cream: 'application',
    MedForm.suppository: 'suppository',
    MedForm.other: 'dose',
  }[this]!;
}

enum ScheduleType { daily, weekdays, everyXDays, intervalHours, prn, course }

extension ScheduleTypeX on ScheduleType {
  String get label => {
    ScheduleType.daily: 'Every day',
    ScheduleType.weekdays: 'Specific weekdays',
    ScheduleType.everyXDays: 'Every X days',
    ScheduleType.intervalHours: 'Every X hours',
    ScheduleType.prn: 'As needed (PRN)',
    ScheduleType.course: 'Course (fixed days)',
  }[this]!;
}

/// One reminder schedule for a medication. A med can carry several.
class Schedule {
  String id;
  ScheduleType type;
  List<String> times; // "HH:mm" for daily / weekdays / course
  List<int> weekdays; // 1 = Mon .. 7 = Sun
  int everyXDays;
  int intervalHours;
  String startTime; // interval window start "HH:mm"
  String endTime; // interval window end "HH:mm"
  DateTime? startDate; // anchor for everyXDays, start of course
  int courseDays;
  int? prnMaxPerDay; // optional note for PRN

  Schedule({
    required this.id,
    this.type = ScheduleType.daily,
    List<String>? times,
    List<int>? weekdays,
    this.everyXDays = 2,
    this.intervalHours = 8,
    this.startTime = '08:00',
    this.endTime = '22:00',
    this.startDate,
    this.courseDays = 7,
    this.prnMaxPerDay,
  }) : times = times ?? ['08:00'],
       weekdays = weekdays ?? [1, 2, 3, 4, 5, 6, 7];

  bool get isPrn => type == ScheduleType.prn;

  String describe() {
    switch (type) {
      case ScheduleType.daily:
        return 'Daily at ${times.join(', ')}';
      case ScheduleType.weekdays:
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final days = weekdays.map((d) => names[d - 1]).join(', ');
        return '$days at ${times.join(', ')}';
      case ScheduleType.everyXDays:
        return 'Every $everyXDays days at ${times.join(', ')}';
      case ScheduleType.intervalHours:
        return 'Every $intervalHours h, $startTime–$endTime';
      case ScheduleType.prn:
        return prnMaxPerDay != null
            ? 'As needed · max $prnMaxPerDay in 24 h (your note)'
            : 'As needed (no reminder)';
      case ScheduleType.course:
        return '$courseDays-day course at ${times.join(', ')}';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'times': times,
    'weekdays': weekdays,
    'everyXDays': everyXDays,
    'intervalHours': intervalHours,
    'startTime': startTime,
    'endTime': endTime,
    'startDate': startDate?.toIso8601String(),
    'courseDays': courseDays,
    'prnMaxPerDay': prnMaxPerDay,
  };
  factory Schedule.fromJson(Map<String, dynamic> j) => Schedule(
    id: j['id'] as String,
    type: ScheduleType.values.firstWhere(
      (e) => e.name == j['type'],
      orElse: () => ScheduleType.daily,
    ),
    times:
        (j['times'] as List?)?.map((e) => e.toString()).toList() ?? ['08:00'],
    weekdays:
        (j['weekdays'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        [1, 2, 3, 4, 5, 6, 7],
    everyXDays: j['everyXDays'] as int? ?? 2,
    intervalHours: j['intervalHours'] as int? ?? 8,
    startTime: j['startTime'] as String? ?? '08:00',
    endTime: j['endTime'] as String? ?? '22:00',
    startDate: j['startDate'] == null
        ? null
        : DateTime.parse(j['startDate'] as String),
    courseDays: j['courseDays'] as int? ?? 7,
    prnMaxPerDay: j['prnMaxPerDay'] as int?,
  );
}

class Medication {
  String id;
  String profileId;
  String name;
  String strength;
  MedForm form;
  int colorValue;
  String instruction; // With food / Before food / Empty stomach / '' etc.
  String notes;
  String prescriber;
  String pharmacy;
  String? photoPath;
  bool archived;
  List<Schedule> schedules;
  double stockQty; // remaining quantity in form units
  double doseAmount; // amount taken per dose, in form units
  int lowStockDays; // warn when fewer than this many days of doses remain
  DateTime? expiryDate;
  DateTime createdAt;

  Medication({
    required this.id,
    required this.profileId,
    required this.name,
    this.strength = '',
    this.form = MedForm.tablet,
    this.colorValue = 0xFF0E9F8A,
    this.instruction = '',
    this.notes = '',
    this.prescriber = '',
    this.pharmacy = '',
    this.photoPath,
    this.archived = false,
    List<Schedule>? schedules,
    this.stockQty = 0,
    this.doseAmount = 1,
    this.lowStockDays = 7,
    this.expiryDate,
    DateTime? createdAt,
  }) : schedules = schedules ?? [],
       createdAt = createdAt ?? DateTime.now();

  Color get color => Color(colorValue);
  bool get hasPrnOnly =>
      schedules.isNotEmpty && schedules.every((s) => s.isPrn);
  String get title => strength.trim().isEmpty ? name : '$name $strength';

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'name': name,
    'strength': strength,
    'form': form.name,
    'colorValue': colorValue,
    'instruction': instruction,
    'notes': notes,
    'prescriber': prescriber,
    'pharmacy': pharmacy,
    'photoPath': photoPath,
    'archived': archived,
    'schedules': schedules.map((s) => s.toJson()).toList(),
    'stockQty': stockQty,
    'doseAmount': doseAmount,
    'lowStockDays': lowStockDays,
    'expiryDate': expiryDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
    id: j['id'] as String,
    profileId: j['profileId'] as String,
    name: j['name'] as String? ?? '',
    strength: j['strength'] as String? ?? '',
    form: MedForm.values.firstWhere(
      (e) => e.name == j['form'],
      orElse: () => MedForm.tablet,
    ),
    colorValue: j['colorValue'] as int? ?? 0xFF0E9F8A,
    instruction: j['instruction'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
    prescriber: j['prescriber'] as String? ?? '',
    pharmacy: j['pharmacy'] as String? ?? '',
    photoPath: j['photoPath'] as String?,
    archived: j['archived'] as bool? ?? false,
    schedules: (j['schedules'] as List? ?? [])
        .map((e) => Schedule.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    stockQty: (j['stockQty'] as num?)?.toDouble() ?? 0,
    doseAmount: (j['doseAmount'] as num?)?.toDouble() ?? 1,
    lowStockDays: j['lowStockDays'] as int? ?? 7,
    expiryDate: j['expiryDate'] == null
        ? null
        : DateTime.parse(j['expiryDate'] as String),
    createdAt: j['createdAt'] == null
        ? DateTime.now()
        : DateTime.parse(j['createdAt'] as String),
  );
}

enum DoseStatus { taken, skipped }

class DoseLog {
  String id;
  String profileId;
  String medId;
  DateTime scheduledFor;
  DoseStatus status;
  DateTime? takenAt;
  String skipReason;
  bool isPrn;
  double doseAmount;
  DoseLog({
    required this.id,
    required this.profileId,
    required this.medId,
    required this.scheduledFor,
    required this.status,
    this.takenAt,
    this.skipReason = '',
    this.isPrn = false,
    this.doseAmount = 1,
  });
  String get key => '${medId}_${scheduledFor.toIso8601String()}';
  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'medId': medId,
    'scheduledFor': scheduledFor.toIso8601String(),
    'status': status.name,
    'takenAt': takenAt?.toIso8601String(),
    'skipReason': skipReason,
    'isPrn': isPrn,
    'doseAmount': doseAmount,
  };
  factory DoseLog.fromJson(Map<String, dynamic> j) => DoseLog(
    id: j['id'] as String,
    profileId: j['profileId'] as String,
    medId: j['medId'] as String,
    scheduledFor: DateTime.parse(j['scheduledFor'] as String),
    status: DoseStatus.values.firstWhere(
      (e) => e.name == j['status'],
      orElse: () => DoseStatus.taken,
    ),
    takenAt: j['takenAt'] == null
        ? null
        : DateTime.parse(j['takenAt'] as String),
    skipReason: j['skipReason'] as String? ?? '',
    isPrn: j['isPrn'] as bool? ?? false,
    doseAmount: (j['doseAmount'] as num?)?.toDouble() ?? 1,
  );
}

class Appointment {
  String id;
  String profileId;
  String title;
  String place; // doctor / clinic / pharmacy name
  DateTime dateTime;
  String note;
  Appointment({
    required this.id,
    required this.profileId,
    required this.title,
    this.place = '',
    required this.dateTime,
    this.note = '',
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'title': title,
    'place': place,
    'dateTime': dateTime.toIso8601String(),
    'note': note,
  };
  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
    id: j['id'] as String,
    profileId: j['profileId'] as String,
    title: j['title'] as String? ?? '',
    place: j['place'] as String? ?? '',
    dateTime: DateTime.parse(j['dateTime'] as String),
    note: j['note'] as String? ?? '',
  );
}

class AppSettings {
  bool onboardingDone = false;
  bool disclaimerAck = false;
  int soundIndex = 0; // index into SoundTones
  bool haptics = true;
  String themeMode = 'system'; // system | light | dark
  bool seniorMode = false;
  int refillSummaryWeekday = 1; // Mon
  String currentProfileId = '';

  Map<String, dynamic> toJson() => {
    'onboardingDone': onboardingDone,
    'disclaimerAck': disclaimerAck,
    'soundIndex': soundIndex,
    'haptics': haptics,
    'themeMode': themeMode,
    'seniorMode': seniorMode,
    'refillSummaryWeekday': refillSummaryWeekday,
    'currentProfileId': currentProfileId,
  };
  void loadJson(Map<String, dynamic> j) {
    onboardingDone = j['onboardingDone'] as bool? ?? false;
    disclaimerAck = j['disclaimerAck'] as bool? ?? false;
    soundIndex = j['soundIndex'] as int? ?? 0;
    haptics = j['haptics'] as bool? ?? true;
    themeMode = j['themeMode'] as String? ?? 'system';
    seniorMode = j['seniorMode'] as bool? ?? false;
    refillSummaryWeekday = j['refillSummaryWeekday'] as int? ?? 1;
    currentProfileId = j['currentProfileId'] as String? ?? '';
  }
}

/// The 5 synthesized reminder tones (assets + Android raw resources share names).
class SoundTones {
  static const names = [
    'Soft chime',
    'Bell',
    'Gentle chime',
    'Pulse',
    'Calm',
    'Alarm — long & loud (12s)',
    'Beacon — long & loud (10s)',
    'Big bell — long & loud (12s)',
  ];
  static const files = [
    'tone_soft',
    'tone_bell',
    'tone_chime',
    'tone_pulse',
    'tone_calm',
    'tone_alarm',
    'tone_beacon',
    'tone_bigbell',
  ];
  static String fileFor(int i) => files[i.clamp(0, files.length - 1)];
  static String nameFor(int i) => names[i.clamp(0, names.length - 1)];
}

const medPalette = <int>[
  0xFF0E9F8A, // teal
  0xFF2E7CD6, // blue
  0xFF7C5CD6, // violet
  0xFFE2703A, // orange
  0xFFD64570, // rose
  0xFF3E9B4F, // green
  0xFFB8860B, // gold
  0xFF607D8B, // slate
];

const profilePalette = <int>[
  0xFF0E9F8A,
  0xFFE2703A,
  0xFF7C5CD6,
  0xFF2E7CD6,
  0xFFD64570,
  0xFF3E9B4F,
];

const instructionOptions = <String>[
  '',
  'With food',
  'Before food',
  'After food',
  'Empty stomach',
  'With a full glass of water',
  'Do not crush or chew',
];

const skipReasons = <String>['Forgot', 'Felt unwell', 'Out of stock', 'Other'];
