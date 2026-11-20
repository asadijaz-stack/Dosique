import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// Light appointments: doctor / pharmacy visits with local reminders
/// (1 day before at 09:00, and 1 hour before).
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final now = DateTime.now();
    final upcoming = store.currentAppointments
        .where((a) => !a.dateTime.isBefore(now))
        .toList();
    final past = store.currentAppointments
        .where((a) => a.dateTime.isBefore(now))
        .toList()
        .reversed
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (upcoming.isEmpty && past.isEmpty)
            const EmptyState(
              icon: Icons.event_rounded,
              title: 'No appointments',
              message: 'Add a doctor or pharmacy visit and Dosique will remind you the day before and an hour before.',
            ),
          if (upcoming.isNotEmpty) ...[
            const SectionTitle(title: 'Upcoming'),
            ...upcoming.map((a) => _tile(context, a)),
          ],
          if (past.isNotEmpty) ...[
            const SectionTitle(title: 'Past'),
            ...past.map((a) => Opacity(opacity: 0.6, child: _tile(context, a))),
          ],
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Appointment a) {
    final df = DateFormat('EEE, d MMM');
    return Card(
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.event_rounded),
        ),
        title: Text(
          a.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            df.format(a.dateTime),
            fmtTime(a.dateTime),
            if (a.place.isNotEmpty) a.place,
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () => _edit(context, a),
      ),
    );
  }

  Future<void> _edit(BuildContext context, Appointment? existing) async {
    final store = context.read<AppStore>();
    final title = TextEditingController(text: existing?.title ?? '');
    final place = TextEditingController(text: existing?.place ?? '');
    final note = TextEditingController(text: existing?.note ?? '');
    var when =
        existing?.dateTime ??
        DateTime.now().add(const Duration(days: 7, hours: 2));

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null ? 'New appointment' : 'Edit appointment',
                style: Theme.of(ctx).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Blood test review',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: place,
                decoration: const InputDecoration(
                  labelText: 'Doctor / clinic / pharmacy (optional)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded),
                title: Text(DateFormat('EEEE, d MMMM yyyy').format(when)),
                subtitle: Text(fmtTime(when)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: when,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 30),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (d == null || !ctx.mounted) return;
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(when),
                  );
                  setSheet(
                    () => when = DateTime(
                      d.year,
                      d.month,
                      d.day,
                      t?.hour ?? when.hour,
                      t?.minute ?? when.minute,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  await store.saveAppointment(
                    Appointment(
                      id: existing?.id ?? newId(),
                      profileId: store.currentProfile.id,
                      title: title.text.trim(),
                      place: place.text.trim(),
                      dateTime: when,
                      note: note.text.trim(),
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: const Text('Save appointment'),
              ),
              if (existing != null)
                TextButton(
                  onPressed: () async {
                    await store.deleteAppointment(existing.id);
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment saved — reminders are set')),
      );
    }
  }
}
