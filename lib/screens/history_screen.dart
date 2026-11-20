import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../services/schedule_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Calendar history: tap any day to see and fix its doses.
/// Fixing a past dose is a headline feature — mistakes happen.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = dayOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final meds = store.currentMeds;
    final logs = store.currentLogs;

    // Stats
    var weekA = const Adherence(0, 0, 0);
    var monthA = const Adherence(0, 0, 0);
    for (var i = 0; i < 30; i++) {
      final day = dayOnly(now).subtract(Duration(days: i));
      final a = adherenceFor(instancesForDay(meds, logs, day), now);
      monthA = Adherence(
        monthA.taken + a.taken,
        monthA.skipped + a.skipped,
        monthA.missed + a.missed,
      );
      if (i < 7) {
        weekA = Adherence(
          weekA.taken + a.taken,
          weekA.skipped + a.skipped,
          weekA.missed + a.missed,
        );
      }
    }
    final streak = currentStreak(meds, logs, now);

    // Calendar cells
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday - 1; // Mon-first
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(_month.year, _month.month, d),
    ];

    final dayInstances = instancesForDay(meds, logs, _selected);
    final dayPrn =
        logs
            .where(
              (l) => l.isPrn && dayOnly(l.scheduledFor) == dayOnly(_selected),
            )
            .toList()
          ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            'History',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        // Stats strip
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat(context, 'This week', '${(weekA.pct * 100).round()}%'),
                _stat(context, '30 days', '${(monthA.pct * 100).round()}%'),
                _stat(
                  context,
                  'Streak',
                  '$streak day${streak == 1 ? '' : 's'}',
                ),
                _stat(context, 'Taken', '${monthA.taken}'),
              ],
            ),
          ),
        ),
        // Per-med adherence bars
        if (meds.where((m) => !m.archived).isNotEmpty) ...[
          const SectionTitle(title: 'Per medicine (30 days)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final m in meds.where((m) => !m.archived))
                    _medBar(context, m, logs, now),
                ],
              ),
            ),
          ),
        ],
        // Month header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final d in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: cells.length,
            itemBuilder: (context, i) {
              final d = cells[i];
              if (d == null) return const SizedBox.shrink();
              final a = adherenceFor(instancesForDay(meds, logs, d), now);
              final has = a.total > 0;
              final isSel = dayOnly(d) == dayOnly(_selected);
              final isToday = dayOnly(d) == dayOnly(now);
              Color bg = Colors.transparent;
              if (has) {
                bg = a.pct >= 0.99
                    ? AppTheme.ok.withValues(alpha: 0.25)
                    : a.pct >= 0.5
                    ? AppTheme.warn.withValues(alpha: 0.25)
                    : AppTheme.danger.withValues(alpha: 0.22);
              }
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selected = dayOnly(d)),
                child: Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel
                          ? AppTheme.seed
                          : isToday
                          ? AppTheme.seed.withValues(alpha: 0.5)
                          : Colors.transparent,
                      width: isSel ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontWeight: isToday
                              ? FontWeight.w900
                              : FontWeight.w600,
                        ),
                      ),
                      if (has)
                        Text(
                          '${(a.pct * 100).round()}%',
                          style: const TextStyle(fontSize: 9),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SectionTitle(title: DateFormat('EEEE, d MMMM').format(_selected)),
        if (dayInstances.isEmpty && dayPrn.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('No doses scheduled this day.'),
          ),
        ...dayInstances.map((i) => _DayDoseTile(instance: i)),
        ...dayPrn.map((l) {
          final med = store.medById(l.medId);
          return Card(
            child: ListTile(
              leading: med == null ? null : MedAvatar(med: med, size: 42),
              title: Text('${med?.title ?? 'Medicine'} (as needed)'),
              subtitle: Text('Taken at ${fmtTime(l.scheduledFor)}'),
              trailing: const StatusChip(status: ResolvedStatus.taken),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove this log entry?'),
                    content: const Text(
                      'The dose amount will be added back to stock.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await store.deleteLog(l);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.seed),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _medBar(
    BuildContext context,
    Medication m,
    List<DoseLog> logs,
    DateTime now,
  ) {
    var taken = 0, total = 0;
    for (var i = 0; i < 30; i++) {
      final day = dayOnly(now).subtract(Duration(days: i));
      final a = adherenceFor(instancesForDay([m], logs, day), now);
      taken += a.taken;
      total += a.total;
    }
    final pct = total == 0 ? 1.0 : taken / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              m.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 9,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  pct >= 0.9
                      ? AppTheme.ok
                      : pct >= 0.6
                      ? AppTheme.warn
                      : AppTheme.danger,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              total == 0 ? '—' : '${(pct * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// One dose on the selected day — tap to fix its status.
class _DayDoseTile extends StatelessWidget {
  final DoseInstance instance;
  const _DayDoseTile({required this.instance});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final st = instance.statusAt(now);
    final med = instance.med;
    return Card(
      child: ListTile(
        leading: MedAvatar(med: med, size: 42),
        title: Text(
          med.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            fmtTime(instance.scheduledFor),
            if (instance.log?.takenAt != null)
              'taken ${fmtTime(instance.log!.takenAt!)}',
            if (instance.log?.skipReason.isNotEmpty ?? false)
              'reason: ${instance.log!.skipReason}',
          ].join(' · '),
        ),
        trailing: StatusChip(status: st),
        onTap: () => _edit(context),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final store = Provider.of<AppStore>(context, listen: false);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${instance.med.title} · ${fmtTime(instance.scheduledFor)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.ok,
              ),
              title: const Text('Mark as taken'),
              onTap: () => Navigator.pop(ctx, 'taken'),
            ),
            ListTile(
              leading: const Icon(Icons.access_time_rounded),
              title: const Text('Mark taken at a different time…'),
              onTap: () => Navigator.pop(ctx, 'taken_at'),
            ),
            ListTile(
              leading: const Icon(
                Icons.skip_next_rounded,
                color: AppTheme.warn,
              ),
              title: const Text('Mark as skipped'),
              onTap: () => Navigator.pop(ctx, 'skipped'),
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt_rounded),
              title: const Text('Clear mark (back to unmarked)'),
              onTap: () => Navigator.pop(ctx, 'clear'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'taken':
        await store.setDoseStatus(
          instance,
          DoseStatus.taken,
          takenAt: instance.scheduledFor,
        );
        break;
      case 'taken_at':
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(
            instance.log?.takenAt ?? instance.scheduledFor,
          ),
        );
        if (t == null) return;
        final when = DateTime(
          instance.scheduledFor.year,
          instance.scheduledFor.month,
          instance.scheduledFor.day,
          t.hour,
          t.minute,
        );
        await store.setDoseStatus(instance, DoseStatus.taken, takenAt: when);
        break;
      case 'skipped':
        await store.setDoseStatus(
          instance,
          DoseStatus.skipped,
          skipReason: 'Edited in history',
        );
        break;
      case 'clear':
        await store.setDoseStatus(instance, null);
        break;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Dose updated')));
  }
}
