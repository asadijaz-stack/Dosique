import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../services/dose_alarm_service.dart';
import '../services/schedule_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'med_edit_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late final ConfettiController _confetti;
  Timer? _ticker;
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    if (h < 21) return 'Good evening';
    return 'Good night';
  }

  void _celebrateIfDone(List<DoseInstance> today, DateTime now) {
    final due = today.where((i) => !i.scheduledFor.isAfter(now)).toList();
    final allTaken =
        today.isNotEmpty &&
        due.isNotEmpty &&
        due.every((i) => i.log?.status == DoseStatus.taken) &&
        today.where((i) => i.scheduledFor.isAfter(now)).isEmpty;
    if (allTaken && !_celebrated) {
      _celebrated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
    } else if (!allTaken) {
      _celebrated = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final profile = store.currentProfile;
    final today = store.todayInstances();
    final adh = adherenceFor(today, now);
    final streak = currentStreak(store.currentMeds, store.currentLogs, now);
    final next = today
        .where(
          (i) =>
              i.log == null &&
              i.scheduledFor.isAfter(now.subtract(const Duration(minutes: 60))),
        )
        .firstOrNull;
    _celebrateIfDone(today, now);

    final prnMeds = store.currentMeds
        .where((m) => !m.archived && m.hasPrnOnly)
        .toList();
    final groups = <String, List<DoseInstance>>{};
    for (final i in today) {
      groups.putIfAbsent(dayPart(i.scheduledFor), () => []).add(i);
    }
    const order = ['Morning', 'Afternoon', 'Evening', 'Night'];

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_greeting()},',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        Text(
                          profile.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          DateFormat('EEEE, d MMMM').format(now),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (streak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warn.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            size: 17,
                            color: AppTheme.warn,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$streak day${streak == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.warn,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => _showProfileSwitcher(context),
                    borderRadius: BorderRadius.circular(30),
                    child: ProfileAvatar(profile: profile, size: 48),
                  ),
                ],
              ),
            ),

            // Ring + next dose card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    AdherenceRing(
                      pct: adh.pct,
                      centerLabel: '${(adh.pct * 100).round()}%',
                      subLabel: 'today',
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: next == null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  today.isEmpty
                                      ? 'No doses today'
                                      : 'All caught up',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  today.isEmpty
                                      ? 'Add a medicine to get gentle reminders.'
                                      : 'Nothing else due. Nice work.',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NEXT DOSE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.seed,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  next.med.title,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${fmtTime(next.scheduledFor)} · ${_countdown(next.scheduledFor, now)}',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                if (next.med.instruction.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    next.med.instruction,
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),

            if (today.isEmpty && prnMeds.isEmpty)
              EmptyState(
                icon: Icons.medication_rounded,
                title: 'No medicines yet',
                message: 'Add your first medicine and Dosique will remind you — no account, everything stays on this phone.',
                action: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MedEditScreen()),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add medicine'),
                ),
              ),

            for (final part in order)
              if (groups[part] != null) ...[
                SectionTitle(title: part),
                ...groups[part]!.asMap().entries.map(
                  (e) => _DoseRow(instance: e.value).stagger(e.key),
                ),
              ],

            if (prnMeds.isNotEmpty) ...[
              const SectionTitle(title: 'As needed'),
              ...prnMeds.map(
                (m) => Card(
                  child: ListTile(
                    leading: MedAvatar(med: m),
                    title: Text(
                      m.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(m.schedules.first.describe()),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        await store.logPrn(m);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${m.name} logged as taken'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () {
                                final log = store.currentLogs
                                    .where((l) => l.medId == m.id && l.isPrn)
                                    .lastOrNull;
                                if (log != null) store.deleteLog(log);
                              },
                            ),
                          ),
                        );
                      },
                      child: const Text('Log dose'),
                    ),
                  ),
                ).stagger(0),
              ),
            ],
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 28,
            gravity: 0.25,
            colors: const [
              AppTheme.seed,
              AppTheme.emerald,
              AppTheme.warn,
              AppTheme.ok,
            ],
          ),
        ),
      ],
    );
  }

  String _countdown(DateTime t, DateTime now) {
    final d = t.difference(now);
    if (d.isNegative) return 'due now';
    if (d.inMinutes < 60) return 'in ${d.inMinutes} min';
    if (d.inHours < 24) {
      return 'in ${d.inHours} h ${d.inMinutes % 60} min';
    }
    return 'tomorrow';
  }

  void _showProfileSwitcher(BuildContext context) {
    final store = context.read<AppStore>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Whose medicines?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            for (final p in store.profiles)
              ListTile(
                leading: ProfileAvatar(profile: p),
                title: Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(p.kind.label),
                trailing: p.id == store.currentProfile.id
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.seed,
                      )
                    : null,
                onTap: () {
                  store.switchProfile(p.id);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  final DoseInstance instance;
  const _DoseRow({required this.instance});

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final now = DateTime.now();
    final st = instance.statusAt(now);
    final med = instance.med;
    final done = st == ResolvedStatus.taken || st == ResolvedStatus.skipped;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                MedAvatar(med: med, size: 50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          decoration: done && st == ResolvedStatus.skipped
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      Text(
                        [
                          fmtTime(instance.scheduledFor),
                          if (med.instruction.isNotEmpty) med.instruction,
                          if (instance.schedule.type == ScheduleType.course)
                            'Day ${courseProgress(instance.schedule, instance.scheduledFor)?.$1 ?? ''} of ${instance.schedule.courseDays}',
                        ].join(' · '),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (st == ResolvedStatus.taken &&
                          instance.log?.takenAt != null)
                        Text(
                          'Taken at ${fmtTime(instance.log!.takenAt!)}',
                          style: const TextStyle(
                            color: AppTheme.ok,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                StatusChip(status: st),
              ],
            ),
            if (!done) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _markTaken(context, store),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Taken'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.seed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _skip(context, store),
                    child: const Text('Skip'),
                  ),
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.more_horiz_rounded),
                    tooltip: 'Snooze',
                    onSelected: (mins) async {
                      await DoseAlarmService.instance.snooze(
                        med: med,
                        scheduledFor: instance.scheduledFor,
                        profileName: store.currentProfile.name,
                        soundIndex: store.settings.soundIndex,
                        minutes: mins,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Reminder snoozed for $mins minutes'),
                        ),
                      );
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 10, child: Text('Snooze 10 min')),
                      PopupMenuItem(value: 20, child: Text('Snooze 20 min')),
                      PopupMenuItem(value: 30, child: Text('Snooze 30 min')),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _markTaken(BuildContext context, AppStore store) async {
    final prev = store.logFor(instance);
    await store.setDoseStatus(instance, DoseStatus.taken);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${instance.med.name} marked as taken'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => store.setDoseStatus(
            instance,
            prev?.status,
            skipReason: prev?.skipReason ?? '',
            takenAt: prev?.takenAt,
          ),
        ),
      ),
    );
  }

  Future<void> _skip(BuildContext context, AppStore store) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Why are you skipping?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            for (final r in skipReasons)
              ListTile(title: Text(r), onTap: () => Navigator.pop(ctx, r)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null) return;
    final prev = store.logFor(instance);
    await store.setDoseStatus(instance, DoseStatus.skipped, skipReason: reason);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${instance.med.name} skipped'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => store.setDoseStatus(
            instance,
            prev?.status,
            skipReason: prev?.skipReason ?? '',
            takenAt: prev?.takenAt,
          ),
        ),
      ),
    );
  }
}
