import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Add / edit a medication: details, photo, stock, and 1+ schedules.
class MedEditScreen extends StatefulWidget {
  final Medication? existing;
  const MedEditScreen({super.key, this.existing});

  @override
  State<MedEditScreen> createState() => _MedEditScreenState();
}

class _MedEditScreenState extends State<MedEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _strength;
  late final TextEditingController _notes;
  late final TextEditingController _prescriber;
  late final TextEditingController _pharmacy;
  late final TextEditingController _stock;
  late final TextEditingController _doseAmount;
  late MedForm _form;
  late int _color;
  late String _instruction;
  String? _photoPath;
  late int _lowStockDays;
  DateTime? _expiry;
  late List<Schedule> _schedules;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _name = TextEditingController(text: m?.name ?? '');
    _strength = TextEditingController(text: m?.strength ?? '');
    _notes = TextEditingController(text: m?.notes ?? '');
    _prescriber = TextEditingController(text: m?.prescriber ?? '');
    _pharmacy = TextEditingController(text: m?.pharmacy ?? '');
    _stock = TextEditingController(text: m == null ? '30' : fmtQty(m.stockQty));
    _doseAmount = TextEditingController(
      text: m == null ? '1' : fmtQty(m.doseAmount),
    );
    _form = m?.form ?? MedForm.tablet;
    _color = m?.colorValue ?? medPalette.first;
    _instruction = m?.instruction ?? '';
    _photoPath = m?.photoPath;
    _lowStockDays = m?.lowStockDays ?? 7;
    _expiry = m?.expiryDate;
    _schedules =
        m?.schedules.map((s) => Schedule.fromJson(s.toJson())).toList() ??
        [Schedule(id: newId())];
    if (_schedules.isEmpty) _schedules = [Schedule(id: newId())];
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _strength,
      _notes,
      _prescriber,
      _pharmacy,
      _stock,
      _doseAmount,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
      imageQuality: 80,
    );
    if (x == null || !mounted) return;
    final store = context.read<AppStore>();
    final medId =
        widget.existing?.id ?? 'new${DateTime.now().millisecondsSinceEpoch}';
    final saved = await store.saveMedPhoto(medId, File(x.path));
    setState(() => _photoPath = saved ?? x.path);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the medicine a name first')),
      );
      return;
    }
    setState(() => _saving = true);
    final store = context.read<AppStore>();
    final old = widget.existing;
    final med = Medication(
      id: old?.id ?? newId(),
      profileId: store.currentProfile.id,
      name: _name.text.trim(),
      strength: _strength.text.trim(),
      form: _form,
      colorValue: _color,
      instruction: _instruction,
      notes: _notes.text.trim(),
      prescriber: _prescriber.text.trim(),
      pharmacy: _pharmacy.text.trim(),
      photoPath: _photoPath,
      archived: old?.archived ?? false,
      schedules: _schedules,
      stockQty: double.tryParse(_stock.text.trim()) ?? 0,
      doseAmount: double.tryParse(_doseAmount.text.trim()) ?? 1,
      lowStockDays: _lowStockDays,
      expiryDate: _expiry,
      createdAt: old?.createdAt,
    );
    // If a photo was picked for a brand-new med under a temp id, move it.
    if (!_isEdit && _photoPath != null && !_photoPath!.contains(med.id)) {
      final moved = await store.saveMedPhoto(med.id, File(_photoPath!));
      if (moved != null) med.photoPath = moved;
    }
    await store.saveMedication(med);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final med = widget.existing;
    if (med == null) return;
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
    if (ok != true || !mounted) return;
    await context.read<AppStore>().deleteMedication(med.id);
    if (!mounted) return;
    // Leave both the edit screen and the (now deleted) medicine's detail
    // screen, back to the medicines list.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit medicine' : 'Add medicine'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Photo + colour
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                InkWell(
                  onTap: _pickPhoto,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Color(_color).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _photoPath != null && File(_photoPath!).existsSync()
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(
                              File(_photoPath!),
                              fit: BoxFit.cover,
                              width: 76,
                              height: 76,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_form.icon, color: Color(_color), size: 28),
                              const Text(
                                'Add photo',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in medPalette)
                        InkWell(
                          onTap: () => setState(() => _color = c),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: _color == c
                                  ? Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      width: 2.5,
                                    )
                                  : null,
                            ),
                            child: _color == c
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _field(
            _name,
            'Medicine name *',
            'e.g. Paracetamol',
            Icons.medication_rounded,
          ),
          _field(_strength, 'Strength', 'e.g. 500 mg', Icons.scale_rounded),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: DropdownButtonFormField<MedForm>(
              initialValue: _form,
              decoration: const InputDecoration(labelText: 'Form'),
              items: MedForm.values
                  .map(
                    (f) => DropdownMenuItem(
                      value: f,
                      child: Row(
                        children: [
                          Icon(f.icon, size: 19),
                          const SizedBox(width: 8),
                          Text(f.label),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _form = v ?? _form),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: DropdownButtonFormField<String>(
              initialValue: _instruction,
              decoration: const InputDecoration(labelText: 'Instruction'),
              items: instructionOptions
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s.isEmpty ? 'None' : s),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _instruction = v ?? ''),
            ),
          ),
          _field(
            _notes,
            'Notes (optional)',
            'Anything you want to remember',
            Icons.notes_rounded,
            maxLines: 2,
          ),
          _field(
            _prescriber,
            'Prescriber (optional)',
            'e.g. Dr. Smith',
            Icons.person_rounded,
          ),
          _field(
            _pharmacy,
            'Pharmacy (optional)',
            'e.g. High Street Pharmacy',
            Icons.local_pharmacy_rounded,
          ),

          const SectionTitle(title: 'Schedule'),
          ..._schedules.asMap().entries.map(
            (e) => _ScheduleEditor(
              schedule: e.value,
              onChanged: () => setState(() {}),
              onRemove: _schedules.length > 1
                  ? () => setState(() => _schedules.removeAt(e.key))
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _schedules.add(Schedule(id: newId()))),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add another schedule'),
            ),
          ),

          const SectionTitle(title: 'Stock & refills'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _numField(_stock, 'In stock (${_form.unit})')),
                const SizedBox(width: 12),
                Expanded(
                  child: _numField(_doseAmount, 'Per dose (${_form.unit})'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<int>(
              initialValue: _lowStockDays,
              decoration: const InputDecoration(labelText: 'Low-stock warning'),
              items: const [3, 5, 7, 10, 14]
                  .map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text('When $d days of doses remain'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _lowStockDays = v ?? 7),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.event_rounded),
            title: const Text('Expiry date'),
            subtitle: Text(
              _expiry == null
                  ? 'Not set'
                  : '${_expiry!.day}/${_expiry!.month}/${_expiry!.year}',
            ),
            trailing: _expiry == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => setState(() => _expiry = null),
                  ),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate:
                    _expiry ?? DateTime.now().add(const Duration(days: 90)),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (d != null) setState(() => _expiry = d);
            },
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_isEdit ? 'Save changes' : 'Add medicine'),
            ),
          ),
          if (_isEdit) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.danger,
                ),
                label: const Text(
                  'Delete medicine',
                  style: TextStyle(color: AppTheme.danger),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.danger),
                ),
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Text(
              'Dosique only reminds and records — it does not check interactions or give dosage advice. Always follow your prescriber\u2019s instructions.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _ScheduleEditor extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  const _ScheduleEditor({
    required this.schedule,
    required this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final s = schedule;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ScheduleType>(
                    initialValue: s.type,
                    decoration: const InputDecoration(labelText: 'When'),
                    items: ScheduleType.values
                        .map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.label)),
                        )
                        .toList(),
                    onChanged: (v) {
                      s.type = v ?? s.type;
                      if (s.type == ScheduleType.course &&
                          s.startDate == null) {
                        s.startDate = DateTime.now();
                      }
                      if (s.type == ScheduleType.everyXDays &&
                          s.startDate == null) {
                        s.startDate = DateTime.now();
                      }
                      onChanged();
                    },
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (s.type == ScheduleType.daily ||
                s.type == ScheduleType.weekdays ||
                s.type == ScheduleType.everyXDays ||
                s.type == ScheduleType.course)
              _TimesRow(schedule: s, onChanged: onChanged),
            if (s.type == ScheduleType.weekdays) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(
                        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d -
                            1],
                      ),
                      selected: s.weekdays.contains(d),
                      onSelected: (sel) {
                        sel ? s.weekdays.add(d) : s.weekdays.remove(d);
                        s.weekdays.sort();
                        onChanged();
                      },
                    ),
                ],
              ),
            ],
            if (s.type == ScheduleType.everyXDays)
              _Stepper(
                label: 'Repeat every',
                suffix: ' days',
                value: s.everyXDays,
                min: 2,
                max: 30,
                onChanged: (v) {
                  s.everyXDays = v;
                  onChanged();
                },
              ),
            if (s.type == ScheduleType.course) ...[
              _Stepper(
                label: 'Course length',
                suffix: ' days',
                value: s.courseDays,
                min: 1,
                max: 90,
                onChanged: (v) {
                  s.courseDays = v;
                  onChanged();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded),
                title: const Text('Starts'),
                subtitle: Text(
                  s.startDate == null
                      ? 'Today'
                      : '${s.startDate!.day}/${s.startDate!.month}/${s.startDate!.year}',
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: s.startDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) {
                    s.startDate = d;
                    onChanged();
                  }
                },
              ),
            ],
            if (s.type == ScheduleType.intervalHours) ...[
              _Stepper(
                label: 'Every',
                suffix: ' hours',
                value: s.intervalHours,
                min: 1,
                max: 24,
                onChanged: (v) {
                  s.intervalHours = v;
                  onChanged();
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: _TimeTile(
                      label: 'From',
                      value: s.startTime,
                      onPicked: (t) {
                        s.startTime = t;
                        onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimeTile(
                      label: 'Until',
                      value: s.endTime,
                      onPicked: (t) {
                        s.endTime = t;
                        onChanged();
                      },
                    ),
                  ),
                ],
              ),
            ],
            if (s.type == ScheduleType.prn) ...[
              const Text(
                'No reminders. You log each dose yourself from the Today screen.',
              ),
              const SizedBox(height: 8),
              _Stepper(
                label: 'Optional note: max per 24 h',
                suffix: '',
                value: s.prnMaxPerDay ?? 0,
                min: 0,
                max: 24,
                onChanged: (v) {
                  s.prnMaxPerDay = v == 0 ? null : v;
                  onChanged();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimesRow extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback onChanged;
  const _TimesRow({required this.schedule, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < schedule.times.length; i++)
          InputChip(
            label: Text(schedule.times[i]),
            onPressed: () async {
              final p = schedule.times[i].split(':');
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: int.tryParse(p[0]) ?? 8,
                  minute: int.tryParse(p[1]) ?? 0,
                ),
              );
              if (t != null) {
                schedule.times[i] =
                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                schedule.times.sort();
                onChanged();
              }
            },
            onDeleted: schedule.times.length > 1
                ? () {
                    schedule.times.removeAt(i);
                    onChanged();
                  }
                : null,
          ),
        ActionChip(
          avatar: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add time'),
          onPressed: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 20, minute: 0),
            );
            if (t != null) {
              schedule.times.add(
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
              );
              schedule.times.sort();
              onChanged();
            }
          },
        ),
      ],
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onPicked;
  const _TimeTile({
    required this.label,
    required this.value,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      onTap: () async {
        final p = value.split(':');
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: int.tryParse(p[0]) ?? 8,
            minute: int.tryParse(p[1]) ?? 0,
          ),
        );
        if (t != null) {
          onPicked(
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
          );
        }
      },
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final String suffix;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _Stepper({
    required this.label,
    required this.suffix,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          Text(
            '$value$suffix',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
