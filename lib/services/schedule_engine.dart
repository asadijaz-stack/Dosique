import '../models/models.dart';

/// Pure-Dart schedule maths — occurrence generation, dose resolution,
/// stock projections and adherence stats. No Flutter imports, fully testable.

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int minutesOf(String hhmm) {
  final p = hhmm.split(':');
  return (int.tryParse(p[0]) ?? 8) * 60 +
      (p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0);
}

DateTime atMinutes(DateTime day, int mins) =>
    DateTime(day.year, day.month, day.day).add(Duration(minutes: mins));

/// All reminder times a schedule produces on [day] (empty for PRN).
List<DateTime> occurrencesOn(Schedule s, DateTime day) {
  final d = dayOnly(day);
  switch (s.type) {
    case ScheduleType.prn:
      return const [];
    case ScheduleType.daily:
    case ScheduleType.course:
      if (s.type == ScheduleType.course) {
        final start = dayOnly(s.startDate ?? d);
        final diff = d.difference(start).inDays;
        if (diff < 0 || diff >= s.courseDays) return const [];
      }
      return s.times.map((t) => atMinutes(d, minutesOf(t))).toList()..sort();
    case ScheduleType.weekdays:
      if (!s.weekdays.contains(d.weekday)) return const [];
      return s.times.map((t) => atMinutes(d, minutesOf(t))).toList()..sort();
    case ScheduleType.everyXDays:
      final anchor = dayOnly(s.startDate ?? d);
      final diff = d.difference(anchor).inDays;
      if (diff < 0 || diff % s.everyXDays != 0) return const [];
      return s.times.map((t) => atMinutes(d, minutesOf(t))).toList()..sort();
    case ScheduleType.intervalHours:
      final start = minutesOf(s.startTime);
      var end = minutesOf(s.endTime);
      if (end <= start) end = start; // degenerate window -> only the start dose
      final out = <DateTime>[];
      var m = start;
      while (m <= end) {
        out.add(atMinutes(d, m));
        if (s.intervalHours <= 0) break;
        m += s.intervalHours * 60;
      }
      return out;
  }
}

/// Occurrences in [from, to] inclusive days, for notification scheduling.
List<DateTime> occurrencesBetween(Schedule s, DateTime from, DateTime to) {
  final out = <DateTime>[];
  var d = dayOnly(from);
  final end = dayOnly(to);
  while (!d.isAfter(end)) {
    out.addAll(occurrencesOn(s, d));
    d = d.add(const Duration(days: 1));
  }
  return out;
}

/// For a course schedule: (currentDay, totalDays) on [day], or null when the
/// course is not running that day.
(int, int)? courseProgress(Schedule s, DateTime day) {
  if (s.type != ScheduleType.course || s.startDate == null) return null;
  final diff = dayOnly(day).difference(dayOnly(s.startDate!)).inDays;
  if (diff < 0 || diff >= s.courseDays) return null;
  return (diff + 1, s.courseDays);
}

enum ResolvedStatus { upcoming, due, taken, skipped, missed }

class DoseInstance {
  final Medication med;
  final Schedule schedule;
  final DateTime scheduledFor;
  final DoseLog? log;
  const DoseInstance({
    required this.med,
    required this.schedule,
    required this.scheduledFor,
    this.log,
  });

  String get key => '${med.id}_${scheduledFor.toIso8601String()}';

  ResolvedStatus statusAt(DateTime now) {
    if (log != null) {
      return log!.status == DoseStatus.taken
          ? ResolvedStatus.taken
          : ResolvedStatus.skipped;
    }
    if (scheduledFor.isAfter(now)) return ResolvedStatus.upcoming;
    // Due window: within 60 minutes after the scheduled time it is "due",
    // after that an unmarked past dose counts as missed.
    if (now.difference(scheduledFor) < const Duration(minutes: 60)) {
      return ResolvedStatus.due;
    }
    return ResolvedStatus.missed;
  }
}

/// Resolve every scheduled dose instance for [day] across [meds].
List<DoseInstance> instancesForDay(
  List<Medication> meds,
  List<DoseLog> logs,
  DateTime day,
) {
  final byKey = {for (final l in logs) l.key: l};
  final out = <DoseInstance>[];
  for (final med in meds) {
    if (med.archived) continue;
    for (final s in med.schedules) {
      for (final t in occurrencesOn(s, day)) {
        out.add(
          DoseInstance(
            med: med,
            schedule: s,
            scheduledFor: t,
            log: byKey['${med.id}_${t.toIso8601String()}'],
          ),
        );
      }
    }
  }
  out.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
  return out;
}

/// Scheduled doses per day for a med (used for stock-days maths).
double dosesPerDay(Medication med) {
  var total = 0.0;
  final probe = DateTime.now();
  for (final s in med.schedules) {
    switch (s.type) {
      case ScheduleType.prn:
        break;
      case ScheduleType.daily:
      case ScheduleType.course:
        total += s.times.length;
        break;
      case ScheduleType.weekdays:
        total += s.times.length * (s.weekdays.length / 7.0);
        break;
      case ScheduleType.everyXDays:
        total += s.times.length / (s.everyXDays <= 0 ? 1 : s.everyXDays);
        break;
      case ScheduleType.intervalHours:
        total += occurrencesOn(s, probe).length;
        break;
    }
  }
  return total;
}

/// Days of stock left; null when stock tracking does not apply.
double? stockDaysLeft(Medication med) {
  final perDay = dosesPerDay(med) * med.doseAmount;
  if (perDay <= 0) return null;
  return med.stockQty / perDay;
}

bool isLowStock(Medication med) {
  final days = stockDaysLeft(med);
  if (days == null) {
    return med.stockQty > 0 && med.stockQty <= med.doseAmount * 3;
  }
  return days <= med.lowStockDays;
}

bool isExpired(Medication med, DateTime now) =>
    med.expiryDate != null && dayOnly(med.expiryDate!).isBefore(dayOnly(now));

bool expirySoon(Medication med, DateTime now) {
  if (med.expiryDate == null || isExpired(med, now)) return false;
  return med.expiryDate!.difference(now).inDays <= 30;
}

class Adherence {
  final int taken;
  final int skipped;
  final int missed;
  const Adherence(this.taken, this.skipped, this.missed);
  int get total => taken + skipped + missed;
  double get pct => total == 0 ? 1.0 : taken / total;
}

/// Adherence over instances whose scheduled time is not in the future.
Adherence adherenceFor(List<DoseInstance> instances, DateTime now) {
  var t = 0, s = 0, m = 0;
  for (final i in instances) {
    if (i.scheduledFor.isAfter(now)) continue;
    switch (i.statusAt(now)) {
      case ResolvedStatus.taken:
        t++;
        break;
      case ResolvedStatus.skipped:
        s++;
        break;
      case ResolvedStatus.missed:
      case ResolvedStatus.due:
        m++;
        break;
      case ResolvedStatus.upcoming:
        break;
    }
  }
  return Adherence(t, s, m);
}

/// Current streak: consecutive days (ending today, or yesterday if today
/// has no completed doses yet) where every due dose was taken.
int currentStreak(List<Medication> meds, List<DoseLog> logs, DateTime now) {
  var streak = 0;
  var day = dayOnly(now);
  // If today still has pending/unmarked doses, start counting from yesterday.
  final today = instancesForDay(meds, logs, day);
  final todayDone =
      today.isNotEmpty &&
      today.every((i) => i.log != null || i.scheduledFor.isAfter(now));
  if (!todayDone) day = day.subtract(const Duration(days: 1));
  while (true) {
    final inst = instancesForDay(
      meds,
      logs,
      day,
    ).where((i) => !i.scheduledFor.isAfter(now)).toList();
    if (inst.isEmpty) {
      // No doses scheduled that day: don't break the streak, but don't
      // count it either — step back at most 370 days to stay bounded.
      day = day.subtract(const Duration(days: 1));
      if (dayOnly(now).difference(day).inDays > 370) break;
      continue;
    }
    final allTaken = inst.every((i) => i.log?.status == DoseStatus.taken);
    if (!allTaken) break;
    streak++;
    day = day.subtract(const Duration(days: 1));
    if (dayOnly(now).difference(day).inDays > 370) break;
  }
  return streak;
}

/// Group label for a time of day.
String dayPart(DateTime t) {
  final h = t.hour;
  if (h < 12) return 'Morning';
  if (h < 17) return 'Afternoon';
  if (h < 21) return 'Evening';
  return 'Night';
}
