import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../services/schedule_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'med_edit_screen.dart';

class MedsScreen extends StatelessWidget {
  const MedsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final active = store.currentMeds.where((m) => !m.archived).toList();
    final archived = store.currentMeds.where((m) => m.archived).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Medicines',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${active.length} active',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (active.isEmpty)
          EmptyState(
            icon: Icons.medication_rounded,
            title: 'No medicines yet',
            message: 'Add a medicine with its schedule and Dosique will handle the reminders.',
            action: FilledButton.icon(
              onPressed: () => _add(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add medicine'),
            ),
          ),
        ...active.asMap().entries.map((e) {
          final m = e.value;
          final low = isLowStock(m);
          final exp = isExpired(m, now);
          final soon = expirySoon(m, now);
          final days = stockDaysLeft(m);
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MedDetailScreen(medId: m.id)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    MedAvatar(med: m, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            m.schedules.map((s) => s.describe()).join(' · '),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _tag(
                                context,
                                Icons.inventory_2_rounded,
                                '${fmtQty(m.stockQty)} ${m.form.unit} left${days != null ? ' (~${days.floor()} days)' : ''}',
                                low ? AppTheme.danger : null,
                              ),
                              if (exp)
                                _tag(
                                  context,
                                  Icons.warning_rounded,
                                  'Expired',
                                  AppTheme.danger,
                                ),
                              if (soon && !exp)
                                _tag(
                                  context,
                                  Icons.event_rounded,
                                  'Expires soon',
                                  AppTheme.warn,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ).stagger(e.key);
        }),
        if (archived.isNotEmpty) ...[
          const SectionTitle(title: 'Paused'),
          ...archived.map(
            (m) => Card(
              child: ListTile(
                leading: MedAvatar(med: m, size: 44),
                title: Text(
                  m.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Paused — no reminders'),
                trailing: TextButton(
                  onPressed: () => store.setArchived(m, false),
                  child: const Text('Resume'),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MedDetailScreen(medId: m.id),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _tag(BuildContext context, IconData icon, String text, Color? color) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }

  static void _add(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MedEditScreen()),
    );
  }
}

class MedDetailScreen extends StatelessWidget {
  final String medId;
  const MedDetailScreen({super.key, required this.medId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final med = store.medById(medId);
    if (med == null) {
      return const Scaffold(body: Center(child: Text('Medicine not found')));
    }
    final now = DateTime.now();
    final days = stockDaysLeft(med);

    // Per-med adherence (last 30 days)
    var taken = 0, total = 0;
    for (var i = 0; i < 30; i++) {
      final day = dayOnly(now).subtract(Duration(days: i));
      final inst = instancesForDay([med], store.currentLogs, day);
      final a = adherenceFor(inst, now);
      taken += a.taken;
      total += a.total;
    }
    final pct = total == 0 ? null : taken / total;

    return Scaffold(
      appBar: AppBar(
        title: Text(med.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MedEditScreen(existing: med)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  MedAvatar(med: med, size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          med.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(med.form.label),
                        if (med.instruction.isNotEmpty) Text(med.instruction),
                        if (med.archived)
                          const Text(
                            'Paused',
                            style: TextStyle(
                              color: AppTheme.warn,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (pct != null)
                    AdherenceRing(
                      pct: pct,
                      size: 76,
                      centerLabel: '${(pct * 100).round()}%',
                      subLabel: '30 days',
                    ),
                ],
              ),
            ),
          ),
          const SectionTitle(title: 'Schedule'),
          Card(
            child: Column(
              children: [
                for (final s in med.schedules)
                  ListTile(
                    leading: Icon(
                      s.isPrn ? Icons.touch_app_rounded : Icons.alarm_rounded,
                    ),
                    title: Text(s.describe()),
                    subtitle:
                        s.type == ScheduleType.course &&
                            courseProgress(s, now) != null
                        ? Text(
                            'Day ${courseProgress(s, now)!.$1} of ${s.courseDays}',
                          )
                        : null,
                  ),
              ],
            ),
          ),
          const SectionTitle(title: 'Stock'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${fmtQty(med.stockQty)} ${med.form.unit} left',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (days != null)
                        Text(
                          '~${days.floor()} days',
                          style: TextStyle(
                            color: isLowStock(med)
                                ? AppTheme.danger
                                : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${fmtQty(med.doseAmount)} ${med.form.unit} per dose · low-stock warning at ${med.lowStockDays} days',
                  ),
                  if (med.expiryDate != null)
                    Text(
                      'Expires ${med.expiryDate!.day}/${med.expiryDate!.month}/${med.expiryDate!.year}${isExpired(med, now) ? ' — EXPIRED' : ''}',
                      style: TextStyle(
                        color: isExpired(med, now)
                            ? AppTheme.danger
                            : expirySoon(med, now)
                            ? AppTheme.warn
                            : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final q in [7, 14, 30])
                        ActionChip(
                          label: Text('Refill +$q'),
                          onPressed: () async {
                            await store.refill(med, q.toDouble());
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Refilled: ${med.name} now has ${fmtQty(med.stockQty)} ${med.form.unit}',
                                ),
                              ),
                            );
                          },
                        ),
                      ActionChip(
                        label: const Text('Custom amount'),
                        onPressed: () => _customRefill(context, store, med),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (med.notes.isNotEmpty ||
              med.prescriber.isNotEmpty ||
              med.pharmacy.isNotEmpty) ...[
            const SectionTitle(title: 'Details'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (med.prescriber.isNotEmpty)
                      Text('Prescriber: ${med.prescriber}'),
                    if (med.pharmacy.isNotEmpty)
                      Text('Pharmacy: ${med.pharmacy}'),
                    if (med.notes.isNotEmpty) Text(med.notes),
                  ],
                ),
              ),
            ),
          ],
          const SectionTitle(title: 'Manage'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    med.archived
                        ? Icons.play_circle_rounded
                        : Icons.pause_circle_rounded,
                  ),
                  title: Text(
                    med.archived ? 'Resume medicine' : 'Pause medicine',
                  ),
                  subtitle: Text(
                    med.archived
                        ? 'Reminders will start again'
                        : 'Stops reminders, keeps history',
                  ),
                  onTap: () => store.setArchived(med, !med.archived),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppTheme.danger,
                  ),
                  title: const Text(
                    'Delete medicine',
                    style: TextStyle(color: AppTheme.danger),
                  ),
                  subtitle: const Text(
                    'Removes the medicine and its dose history',
                  ),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Delete ${med.name}?'),
                        content: const Text(
                          'This removes the medicine and all its dose history. This cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await store.deleteMedication(med.id);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _customRefill(
    BuildContext context,
    AppStore store,
    Medication med,
  ) async {
    final ctrl = TextEditingController();
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refill amount'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Add (${med.form.unit})'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (v != null && v > 0) await store.refill(med, v);
  }
}
