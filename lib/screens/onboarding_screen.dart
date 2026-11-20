import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../data/store.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// 4 animated pages: what it does, privacy promise, permission, disclaimer.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _ack = false;
  bool? _permissionGranted;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _OnbPage(
                    icon: Icons.medication_rounded,
                    title: 'Never miss a dose',
                    body:
                        'Gentle, on-time reminders for every medicine — daily, weekly, '
                        'every few hours, or a short course like antibiotics. Unlimited '
                        'medicines, forever free.',
                  ),
                  _OnbPage(
                    icon: Icons.lock_rounded,
                    title: 'Private by design',
                    body:
                        'No account. No sign-up. No ads. Everything you enter stays on '
                        'this phone — nothing is collected or sent anywhere. You only '
                        'share when you choose to.',
                  ),
                  _OnbPage(
                    icon: Icons.notifications_active_rounded,
                    title: 'Reminders need permission',
                    body:
                        'Dosique uses notifications to remind you at dose time, and exact '
                        'alarms so those reminders arrive on time — even if the phone has '
                        'been idle. You can change this any time in Settings.',
                    action: Column(
                      children: [
                        FilledButton.icon(
                          onPressed: () async {
                            final ok = await NotificationService.instance
                                .requestPermissions();
                            setState(() => _permissionGranted = ok);
                          },
                          icon: const Icon(Icons.notifications_rounded),
                          label: const Text('Allow reminders'),
                        ),
                        if (_permissionGranted != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              _permissionGranted!
                                  ? 'Reminders are on. You can continue.'
                                  : 'No problem — you can allow them later in Settings > Reminders.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _OnbPage(
                    icon: Icons.health_and_safety_rounded,
                    title: 'One honest note',
                    body:
                        'Dosique is a reminder and recording tool. It is not a medical '
                        'device: it does not give medical advice, does not check drug '
                        'interactions, and never tells you what dose to take. Always '
                        'follow your prescriber\u2019s instructions.',
                    action: CheckboxListTile(
                      value: _ack,
                      onChanged: (v) => setState(() => _ack = v ?? false),
                      title: const Text('I understand'),
                      controlAffinity: ListTileControlAffinity.leading,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++)
                  AnimatedContainer(
                    duration: 250.ms,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _page == i ? 26 : 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _page == i
                          ? AppTheme.seed
                          : AppTheme.seed.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _controller.previousPage(
                        duration: 300.ms,
                        curve: Curves.easeOut,
                      ),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _page == 3
                        ? (_ack
                              ? () async {
                                  await context
                                      .read<AppStore>()
                                      .finishOnboarding();
                                }
                              : null)
                        : () => _controller.nextPage(
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),
                    child: Text(_page == 3 ? 'Start using Dosique' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnbPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const _OnbPage({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF14B8A6),
                      Color(0xFF0E9F8A),
                      Color(0xFF059669),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.seed.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(icon, size: 58, color: Colors.white),
              )
              .animate()
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: 450.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 300.ms),
          const SizedBox(height: 30),
          Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              )
              .animate(delay: 100.ms)
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.08, end: 0),
          const SizedBox(height: 12),
          Text(
                body,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              )
              .animate(delay: 200.ms)
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.08, end: 0),
          if (action != null) ...[
            const SizedBox(height: 24),
            action!.animate(delay: 300.ms).fadeIn(duration: 350.ms),
          ],
        ],
      ),
    );
  }
}
