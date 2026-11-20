import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/schedule_engine.dart';
import '../theme/app_theme.dart';

String fmtQty(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

String fmtTime(DateTime t) => DateFormat('h:mm a').format(t);

/// Circular avatar with a med's colour + form icon (or its photo).
class MedAvatar extends StatelessWidget {
  final Medication med;
  final double size;
  const MedAvatar({super.key, required this.med, this.size = 48});

  @override
  Widget build(BuildContext context) {
    if (med.photoPath != null && File(med.photoPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.32),
        child: Image.file(
          File(med.photoPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: med.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(med.form.icon, color: med.color, size: size * 0.52),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final double size;
  const ProfileAvatar({super.key, required this.profile, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: profile.color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        profile.initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

/// Status chip for a dose instance.
class StatusChip extends StatelessWidget {
  final ResolvedStatus status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      ResolvedStatus.taken => (
        'Taken',
        AppTheme.ok,
        Icons.check_circle_rounded,
      ),
      ResolvedStatus.skipped => (
        'Skipped',
        AppTheme.warn,
        Icons.skip_next_rounded,
      ),
      ResolvedStatus.missed => ('Missed', AppTheme.danger, Icons.error_rounded),
      ResolvedStatus.due => (
        'Due now',
        AppTheme.seed,
        Icons.notifications_active_rounded,
      ),
      ResolvedStatus.upcoming => (
        'Upcoming',
        Colors.grey,
        Icons.schedule_rounded,
      ),
    };
    return Chip(
      avatar: Icon(icon, size: 15, color: color),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 2),
    );
  }
}

/// Animated adherence ring.
class AdherenceRing extends StatelessWidget {
  final double pct; // 0..1
  final double size;
  final String centerLabel;
  final String? subLabel;
  const AdherenceRing({
    super.key,
    required this.pct,
    this.size = 132,
    required this.centerLabel,
    this.subLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct.clamp(0, 1)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: size * 0.085,
                strokeCap: StrokeCap.round,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation(AppTheme.seed),
              ),
            ),
          ),
          // Center text is constrained to well inside the ring's inner
          // diameter and auto-shrinks, so a 4-character label like "100%"
          // can never touch or overlap the ring stroke at any font scale.
          SizedBox(
            width: size * 0.7,
            height: size * 0.7,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerLabel,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: size * 0.22,
                    ),
                  ),
                  if (subLabel != null)
                    Text(
                      subLabel!,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppTheme.seed.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppTheme.seed),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0);
  }
}

/// Staggered entrance wrapper for list children.
extension AnimateListItem on Widget {
  Widget stagger(int index) =>
      animate(delay: (40 * index).ms)
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.05, end: 0, curve: Curves.easeOut);
}
