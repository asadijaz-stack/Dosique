import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../services/pdf_service.dart';
import '../services/schedule_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'appointments_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _player = AudioPlayer();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _previewTone(int i) async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/${SoundTones.fileFor(i)}.wav'));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.settings;
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            'More',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),

        // Profiles
        const SectionTitle(title: 'Profiles'),
        Card(
          child: Column(
            children: [
              for (final p in store.profiles)
                ListTile(
                  leading: ProfileAvatar(profile: p, size: 40),
                  title: Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(p.kind.label),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (p.id == store.currentProfile.id)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.seed,
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editProfile(context, p),
                      ),
                    ],
                  ),
                  onTap: () => store.switchProfile(p.id),
                ),
              ListTile(
                leading: const Icon(Icons.person_add_rounded),
                title: const Text('Add a person or pet'),
                onTap: () => _editProfile(context, null),
              ),
            ],
          ),
        ),

        // Share & report
        const SectionTitle(title: 'Share with family or your doctor'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share today\u2019s schedule'),
                subtitle: const Text('Send it by any app — no account needed'),
                onTap: () {
                  final text = ShareService.scheduleText(
                    profile: store.currentProfile,
                    meds: store.currentMeds,
                    today: store.todayInstances(),
                    now: now,
                  );
                  ShareService.shareText(text);
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_rounded),
                title: const Text('Send via WhatsApp'),
                onTap: () {
                  final text = ShareService.scheduleText(
                    profile: store.currentProfile,
                    meds: store.currentMeds,
                    today: store.todayInstances(),
                    now: now,
                  );
                  ShareService.shareWhatsApp(text);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sms_rounded),
                title: const Text('Send via SMS'),
                onTap: () {
                  final missed = <DoseInstance>[];
                  for (var i = 0; i < 7; i++) {
                    final day = dayOnly(now).subtract(Duration(days: i));
                    missed.addAll(
                      instancesForDay(
                        store.currentMeds,
                        store.currentLogs,
                        day,
                      ).where((x) => x.statusAt(now) == ResolvedStatus.missed),
                    );
                  }
                  ShareService.shareSms(
                    ShareService.missedText(
                      profile: store.currentProfile,
                      missed: missed,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded),
                title: const Text('Doctor report (PDF)'),
                subtitle: const Text(
                  'Medicines, 30-day adherence and dose history',
                ),
                onTap: () => _doctorReport(context),
              ),
              ListTile(
                leading: const Icon(Icons.event_rounded),
                title: const Text('Appointments'),
                subtitle: Text(
                  '${store.currentAppointments.where((a) => !a.dateTime.isBefore(now)).length} upcoming',
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
                ),
              ),
            ],
          ),
        ),

        // Reminders
        const SectionTitle(title: 'Reminders'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.music_note_rounded),
                title: const Text('Reminder tone'),
                subtitle: Text(SoundTones.nameFor(s.soundIndex)),
                trailing: IconButton(
                  icon: const Icon(Icons.play_circle_rounded),
                  onPressed: () => _previewTone(s.soundIndex),
                ),
                onTap: () async {
                  final pick = await showModalBottomSheet<int>(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Reminder tone',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          for (var i = 0; i < SoundTones.names.length; i++)
                            ListTile(
                              title: Text(SoundTones.names[i]),
                              trailing: IconButton(
                                icon: const Icon(Icons.play_circle_rounded),
                                onPressed: () => _previewTone(i),
                              ),
                              selected: i == s.soundIndex,
                              onTap: () => Navigator.pop(ctx, i),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  );
                  if (pick != null) {
                    s.soundIndex = pick;
                    await store.updateSettings();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_rounded),
                title: const Text('Check notification permission'),
                subtitle: const Text(
                  'Reminders need permission to show on time',
                ),
                onTap: () async {
                  final ok = await NotificationService.instance
                      .requestPermissions();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? 'Notifications are on' : 'Notifications are off — enable them in system settings so reminders can reach you',
                      ),
                    ),
                  );
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.vibration_rounded),
                title: const Text('Haptics'),
                subtitle: const Text('Gentle vibration on taps'),
                value: s.haptics,
                onChanged: (v) async {
                  s.haptics = v;
                  await store.updateSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_view_week_rounded),
                title: const Text('Weekly refill summary day'),
                subtitle: Text(
                  DateFormat('EEEE')
                      .format(DateTime(2026, 1, 4 + s.refillSummaryWeekday)),
                ),
                onTap: () async {
                  final pick = await showModalBottomSheet<int>(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var d = 1; d <= 7; d++)
                            ListTile(
                              title: Text(
                                DateFormat('EEEE')
                                    .format(DateTime(2026, 1, 4 + d)),
                              ),
                              selected: d == s.refillSummaryWeekday,
                              onTap: () => Navigator.pop(ctx, d),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (pick != null) {
                    s.refillSummaryWeekday = pick;
                    await store.updateSettings();
                  }
                },
              ),
            ],
          ),
        ),

        // Appearance & accessibility
        const SectionTitle(title: 'Appearance & accessibility'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.brightness_6_rounded),
                title: const Text('Theme'),
                subtitle: Text(
                  s.themeMode == 'system'
                      ? 'System'
                      : s.themeMode == 'light'
                      ? 'Light'
                      : 'Dark',
                ),
                onTap: () async {
                  final pick = await showModalBottomSheet<String>(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (v, l) in [
                            ('system', 'System'),
                            ('light', 'Light'),
                            ('dark', 'Dark'),
                          ])
                            ListTile(
                              title: Text(l),
                              selected: v == s.themeMode,
                              onTap: () => Navigator.pop(ctx, v),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (pick != null) {
                    s.themeMode = pick;
                    await store.updateSettings();
                  }
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.text_increase_rounded),
                title: const Text('Large text (senior mode)'),
                subtitle: const Text(
                  'Bigger text and buttons throughout the app',
                ),
                value: s.seniorMode,
                onChanged: (v) async {
                  s.seniorMode = v;
                  await store.updateSettings();
                },
              ),
            ],
          ),
        ),

        // Backup
        const SectionTitle(title: 'Backup'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Export backup (JSON)'),
                subtitle: const Text(
                  'All profiles, medicines, history and settings',
                ),
                onTap: () async {
                  final dir = await getTemporaryDirectory();
                  final f = File('${dir.path}/dosique_backup.json');
                  await f.writeAsString(store.exportJson());
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(f.path)],
                      subject: 'Dosique backup',
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_open_rounded),
                title: const Text('Import backup'),
                subtitle: const Text(
                  'Replaces everything currently in the app',
                ),
                onTap: () async {
                  final picked = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['json'],
                  );
                  if (picked.isEmpty) return;
                  final bytes = await picked.first.readAsBytes();
                  if (!context.mounted) return;
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Import this backup?'),
                      content: const Text(
                        'Everything currently in Dosique will be replaced by the backup.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Import'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  final done = await store.importJson(utf8.decode(bytes));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        done
                            ? 'Backup imported'
                            : 'That file could not be read as a Dosique backup',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // About
        const SectionTitle(title: 'About'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset('assets/icon/icon.png', width: 44, height: 44),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dosique',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text('Version 1.0.0 · 100% free'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Privacy: Dosique has no account and no server. All your data '
                  'stays on this phone. Nothing is collected, tracked or sold. '
                  'The only way data leaves is when you share it yourself.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Disclaimer: Dosique is a reminder and recording tool only. '
                  'It is not a medical device, does not provide medical advice, '
                  'does not check drug interactions, and never changes a dose. '
                  'Always follow your prescriber\u2019s instructions and talk to '
                  'your doctor or pharmacist about your medicines.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _doctorReport(BuildContext context) async {
    final store = context.read<AppStore>();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
    );
    if (range == null) return;
    await ShareService.shareDoctorReport(
      profile: store.currentProfile,
      meds: store.currentMeds,
      logs: store.currentLogs,
      from: range.start,
      to: range.end,
      now: DateTime.now(),
    );
  }

  Future<void> _editProfile(BuildContext context, Profile? existing) async {
    final store = context.read<AppStore>();
    final name = TextEditingController(text: existing?.name ?? '');
    var kind = existing?.kind ?? ProfileKind.family;
    var color = existing?.colorValue ?? profilePalette[1];
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
                existing == null ? 'Add profile' : 'Edit profile',
                style: Theme.of(ctx).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                autofocus: existing == null,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<ProfileKind>(
                segments: ProfileKind.values
                    .map(
                      (k) => ButtonSegment(
                        value: k,
                        label: Text(k.label),
                        icon: Icon(k.icon),
                      ),
                    )
                    .toList(),
                selected: {kind},
                onSelectionChanged: (v) => setSheet(() => kind = v.first),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in profilePalette)
                    InkWell(
                      onTap: () => setSheet(() => color = c),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: color == c
                              ? Border.all(color: Colors.black54, width: 2.5)
                              : null,
                        ),
                        child: color == c
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
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (name.text.trim().isEmpty) return;
                  if (existing == null) {
                    await store.addProfile(name.text.trim(), kind, color);
                  } else {
                    existing
                      ..name = name.text.trim()
                      ..kind = kind
                      ..colorValue = color;
                    await store.updateProfile(existing);
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: const Text('Save profile'),
              ),
              if (existing != null && store.profiles.length > 1)
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: ctx,
                      builder: (dctx) => AlertDialog(
                        title: Text('Delete ${existing.name}?'),
                        content: const Text(
                          'Their medicines, history and appointments will be removed.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await store.deleteProfile(existing.id);
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    }
                  },
                  child: const Text(
                    'Delete profile',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (saved == true && context.mounted) setState(() {});
  }
}
