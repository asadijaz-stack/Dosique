import 'package:dosique/data/store.dart';
import 'package:dosique/main.dart';
import 'package:dosique/models/models.dart';
import 'package:dosique/services/schedule_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Medication _med({
  String id = 'm1',
  List<Schedule>? schedules,
  double stock = 30,
  double dose = 1,
  int lowDays = 7,
  DateTime? expiry,
}) =>
    Medication(
      id: id,
      profileId: 'p1',
      name: 'TestMed',
      strength: '500 mg',
      schedules: schedules ??
          [
            Schedule(id: 's1', times: ['08:00'])
          ],
      stockQty: stock,
      doseAmount: dose,
      lowStockDays: lowDays,
      expiryDate: expiry,
    );

String _hh(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('occurrence generation', () {
    test('daily produces sorted times', () {
      final s = Schedule(id: 's', times: ['20:00', '08:00']);
      final occ = occurrencesOn(s, DateTime(2026, 3, 10));
      expect(occ.length, 2);
      expect(occ.first.hour, 8);
      expect(occ.last.hour, 20);
    });

    test('weekdays only fires on selected days', () {
      // 2026-03-09 is a Monday.
      final s = Schedule(
          id: 's',
          type: ScheduleType.weekdays,
          weekdays: [1, 3, 5],
          times: ['09:00']);
      expect(occurrencesOn(s, DateTime(2026, 3, 9)).length, 1); // Mon
      expect(occurrencesOn(s, DateTime(2026, 3, 10)).length, 0); // Tue
      expect(occurrencesOn(s, DateTime(2026, 3, 11)).length, 1); // Wed
    });

    test('every X days respects the anchor', () {
      final s = Schedule(
        id: 's',
        type: ScheduleType.everyXDays,
        everyXDays: 3,
        startDate: DateTime(2026, 3, 1),
        times: ['08:00'],
      );
      expect(occurrencesOn(s, DateTime(2026, 3, 1)).length, 1);
      expect(occurrencesOn(s, DateTime(2026, 3, 2)).length, 0);
      expect(occurrencesOn(s, DateTime(2026, 3, 4)).length, 1);
      expect(occurrencesOn(s, DateTime(2026, 2, 27)).length, 0);
    });

    test('interval hours stays inside the window', () {
      final s = Schedule(
        id: 's',
        type: ScheduleType.intervalHours,
        intervalHours: 8,
        startTime: '08:00',
        endTime: '22:00',
      );
      final occ = occurrencesOn(s, DateTime(2026, 3, 10));
      expect(occ.map((d) => d.hour).toList(), [8, 16]);
      final s4 = Schedule(
        id: 's',
        type: ScheduleType.intervalHours,
        intervalHours: 4,
        startTime: '06:00',
        endTime: '22:00',
      );
      expect(
          occurrencesOn(s4, DateTime(2026, 3, 10)).map((d) => d.hour).toList(),
          [6, 10, 14, 18, 22]);
    });

    test('course runs for exactly courseDays then stops', () {
      final s = Schedule(
        id: 's',
        type: ScheduleType.course,
        courseDays: 7,
        startDate: DateTime(2026, 3, 1),
        times: ['08:00', '20:00'],
      );
      expect(occurrencesOn(s, DateTime(2026, 3, 7)).length, 2); // day 7
      expect(occurrencesOn(s, DateTime(2026, 3, 8)).length, 0); // day 8: done
      expect(courseProgress(s, DateTime(2026, 3, 3)), (3, 7));
      expect(courseProgress(s, DateTime(2026, 3, 9)), isNull);
    });

    test('PRN produces no scheduled occurrences', () {
      final s = Schedule(id: 's', type: ScheduleType.prn);
      expect(occurrencesOn(s, DateTime(2026, 3, 10)), isEmpty);
      expect(occurrencesBetween(s, DateTime(2026, 3, 1), DateTime(2026, 3, 31)),
          isEmpty);
    });

    test('occurrencesBetween spans days', () {
      final s = Schedule(id: 's', times: ['08:00', '20:00']);
      final occ =
          occurrencesBetween(s, DateTime(2026, 3, 1), DateTime(2026, 3, 3));
      expect(occ.length, 6);
    });
  });

  group('dose resolution and adherence', () {
    test('logged dose resolves as taken; unmarked old dose is missed', () {
      final med = _med();
      final day = DateTime(2026, 3, 10);
      final logs = [
        DoseLog(
          id: 'l1',
          profileId: 'p1',
          medId: 'm1',
          scheduledFor: DateTime(2026, 3, 10, 8),
          status: DoseStatus.taken,
          takenAt: DateTime(2026, 3, 10, 8, 5),
        ),
      ];
      final inst = instancesForDay([med], logs, day);
      expect(inst.length, 1);
      expect(
          inst.first.statusAt(DateTime(2026, 3, 10, 9)), ResolvedStatus.taken);
      final unmarked = instancesForDay([med], const [], day);
      expect(unmarked.first.statusAt(DateTime(2026, 3, 10, 9, 30)),
          ResolvedStatus.missed);
      expect(unmarked.first.statusAt(DateTime(2026, 3, 10, 8, 30)),
          ResolvedStatus.due);
      expect(unmarked.first.statusAt(DateTime(2026, 3, 10, 7, 0)),
          ResolvedStatus.upcoming);
    });

    test('adherence maths counts taken/skipped/missed', () {
      final med = _med(schedules: [
        Schedule(id: 's1', times: ['06:00', '07:00', '08:00'])
      ]);
      final day = DateTime(2026, 3, 10);
      final logs = [
        DoseLog(
            id: 'a',
            profileId: 'p1',
            medId: 'm1',
            scheduledFor: DateTime(2026, 3, 10, 6),
            status: DoseStatus.taken),
        DoseLog(
            id: 'b',
            profileId: 'p1',
            medId: 'm1',
            scheduledFor: DateTime(2026, 3, 10, 7),
            status: DoseStatus.skipped),
      ];
      final a = adherenceFor(
          instancesForDay([med], logs, day), DateTime(2026, 3, 10, 12));
      expect(a.taken, 1);
      expect(a.skipped, 1);
      expect(a.missed, 1);
      expect(a.pct, closeTo(1 / 3, 0.001));
    });

    test('streak counts consecutive all-taken days', () {
      final now = DateTime.now();
      final past = now.subtract(const Duration(hours: 2));
      final med = _med(schedules: [
        Schedule(id: 's1', times: [_hh(past)])
      ]);
      final logs = <DoseLog>[];
      for (var i = 0; i < 3; i++) {
        final d = dayOnly(now).subtract(Duration(days: i));
        logs.add(DoseLog(
          id: 'l$i',
          profileId: 'p1',
          medId: 'm1',
          scheduledFor:
              DateTime(d.year, d.month, d.day, past.hour, past.minute),
          status: DoseStatus.taken,
        ));
      }
      expect(currentStreak([med], logs, now), 3);
      // Break yesterday -> streak falls back to just today (0 completed streak
      // beyond the break): today taken, yesterday skipped => streak 1.
      logs[1] = DoseLog(
        id: 'l1',
        profileId: 'p1',
        medId: 'm1',
        scheduledFor: logs[1].scheduledFor,
        status: DoseStatus.skipped,
      );
      expect(currentStreak([med], logs, now), 1);
    });
  });

  group('stock', () {
    test('stock days and low-stock threshold', () {
      final med = _med(
        schedules: [
          Schedule(id: 's1', times: ['08:00', '20:00'])
        ],
        stock: 10,
      );
      expect(dosesPerDay(med), 2);
      expect(stockDaysLeft(med), 5);
      expect(isLowStock(med), isTrue);
      med.stockQty = 40;
      expect(stockDaysLeft(med), 20);
      expect(isLowStock(med), isFalse);
    });

    test('expiry flags', () {
      final now = DateTime(2026, 3, 10);
      expect(isExpired(_med(expiry: DateTime(2026, 3, 9)), now), isTrue);
      expect(expirySoon(_med(expiry: DateTime(2026, 3, 25)), now), isTrue);
      expect(expirySoon(_med(expiry: DateTime(2027, 1, 1)), now), isFalse);
    });
  });

  group('store behaviour', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('taking a dose decrements stock; clearing restores it', () async {
      final store = AppStore();
      await store.load();
      final med = _med(id: 'mx', stock: 10);
      med.profileId = store.currentProfile.id;
      await store.saveMedication(med);
      final inst = instancesForDay([med], const [], DateTime.now()).first;
      await store.setDoseStatus(inst, DoseStatus.taken);
      expect(med.stockQty, 9);
      expect(store.logFor(inst)?.status, DoseStatus.taken);
      await store.setDoseStatus(inst, null);
      expect(med.stockQty, 10);
      expect(store.logFor(inst), isNull);
      // Taken -> skipped restores stock too.
      await store.setDoseStatus(inst, DoseStatus.taken);
      await store.setDoseStatus(inst, DoseStatus.skipped, skipReason: 'Forgot');
      expect(med.stockQty, 10);
      expect(store.logFor(inst)?.skipReason, 'Forgot');
    });

    test('PRN quick-log decrements stock and records the dose', () async {
      final store = AppStore();
      await store.load();
      final med = _med(
        id: 'prn1',
        stock: 5,
        schedules: [
          Schedule(id: 'sp', type: ScheduleType.prn, prnMaxPerDay: 4)
        ],
      );
      med.profileId = store.currentProfile.id;
      await store.saveMedication(med);
      await store.logPrn(med);
      expect(med.stockQty, 4);
      expect(store.currentLogs.where((l) => l.isPrn).length, 1);
    });

    test('JSON backup round-trip preserves everything', () async {
      final store = AppStore();
      await store.load();
      final med = _med(id: 'bk1', stock: 12);
      med.profileId = store.currentProfile.id;
      med.schedules.add(Schedule(
        id: 's2',
        type: ScheduleType.course,
        courseDays: 7,
        startDate: DateTime(2026, 3, 1),
        times: ['21:00'],
      ));
      await store.saveMedication(med);
      await store.saveAppointment(Appointment(
        id: 'ap1',
        profileId: store.currentProfile.id,
        title: 'Check-up',
        dateTime: DateTime.now().add(const Duration(days: 3)),
      ));
      store.settings.soundIndex = 3;
      store.settings.seniorMode = true;

      final exported = store.exportJson();
      final other = AppStore();
      final ok = await other.importJson(exported);
      expect(ok, isTrue);
      expect(other.meds.length, 1);
      expect(other.meds.first.schedules.length, 2);
      expect(other.meds.first.stockQty, 12);
      expect(other.appointments.length, 1);
      expect(other.settings.soundIndex, 3);
      expect(other.settings.seniorMode, isTrue);
      expect(other.profiles.length, store.profiles.length);
    });

    test('medication JSON round-trip keeps all fields', () {
      final med = _med(stock: 7.5, dose: 2.5, expiry: DateTime(2027, 5, 1));
      med.instruction = 'With food';
      med.notes = 'note';
      final back = Medication.fromJson(med.toJson());
      expect(back.stockQty, 7.5);
      expect(back.doseAmount, 2.5);
      expect(back.expiryDate, DateTime(2027, 5, 1));
      expect(back.instruction, 'With food');
      expect(back.title, 'TestMed 500 mg');
    });
  });

  testWidgets('onboarding shows for a fresh install', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await tester.runAsync(() => store.load());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: store, child: const DosiqueApp()),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Never miss a dose'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
