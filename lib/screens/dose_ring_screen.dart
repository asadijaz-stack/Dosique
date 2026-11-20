import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../services/dose_alarm_service.dart';
import '../services/schedule_engine.dart';
import '../theme/app_theme.dart';

/// Full-screen "alarm clock" screen shown while a dose alarm is ringing.
/// The tone keeps looping until the user acts here (or taps Stop on the
/// alarm notification).
class DoseRingScreen extends StatefulWidget {
  final int alarmId;
  final String medId;
  final String medName;
  final DateTime scheduledFor;
  final String body;

  const DoseRingScreen({
    super.key,
    required this.alarmId,
    required this.medId,
    required this.medName,
    required this.scheduledFor,
    required this.body,
  });

  @override
  State<DoseRingScreen> createState() => _DoseRingScreenState();
}

class _DoseRingScreenState extends State<DoseRingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);
  bool _acting = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Medication? _med(AppStore store) {
    for (final m in store.meds) {
      if (m.id == widget.medId) return m;
    }
    return null;
  }

  DoseInstance _instance(Medication med) {
    Schedule? match;
    for (final s in med.schedules) {
      if (occurrencesOn(
        s,
        widget.scheduledFor,
      ).any((t) => t.isAtSameMomentAs(widget.scheduledFor))) {
        match = s;
        break;
      }
    }
    return DoseInstance(
      med: med,
      schedule: match ?? med.schedules.first,
      scheduledFor: widget.scheduledFor,
    );
  }

  Future<void> _act(Future<void> Function(AppStore store) action) async {
    if (_acting) return;
    _acting = true;
    final store = context.read<AppStore>();
    await DoseAlarmService.instance.stop(widget.alarmId);
    await action(store);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final med = _med(store);
    return Scaffold(
      backgroundColor: AppTheme.seed,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.08).animate(_pulse),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.alarm_rounded,
                    size: 58,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Time for your medicine',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.medName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (widget.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
              const SizedBox(height: 40),
              if (med != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _act(
                      (store) =>
                          store.setDoseStatus(_instance(med), DoseStatus.taken),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text(
                      'Taken',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.seed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _act((store) async {
                          await DoseAlarmService.instance.snooze(
                            med: med,
                            scheduledFor: widget.scheduledFor,
                            profileName: store.currentProfile.name,
                            soundIndex: store.settings.soundIndex,
                            minutes: 10,
                          );
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Snooze 10 min'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _act(
                          (store) => store.setDoseStatus(
                            _instance(med),
                            DoseStatus.skipped,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Skip'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _act((_) async {}),
                child: const Text(
                  'Stop ringing',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
