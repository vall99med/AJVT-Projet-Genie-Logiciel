import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../core/l10n/app_localizations.dart';

class MainNavBar extends ConsumerWidget {
  final int currentIndex;
  const MainNavBar({required this.currentIndex, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role       = ref.watch(authNotifierProvider).role ?? '';
    final isAdminMod = role == 'admin' || role == 'moderator';
    final t          = AppLocalizations.of(context);

    void onTap(int i) {
      if (i == currentIndex) return;
      if (isAdminMod) {
        switch (i) {
          case 0: context.go('/feed');
          case 1: context.go('/events');
          case 2: context.go('/dashboard');
          case 3: context.go('/payment/review');
        }
      } else {
        switch (i) {
          case 0: context.go('/feed');
          case 1: context.go('/events');
          case 2: context.go('/directory');
          case 3: context.go('/profile');
        }
      }
    }

    final memberDestinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: t.translate('nav_home'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.event_outlined),
        selectedIcon: const Icon(Icons.event),
        label: t.translate('nav_events'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.people_outline),
        selectedIcon: const Icon(Icons.people),
        label: t.translate('nav_directory'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: t.translate('nav_profile'),
      ),
    ];

    final adminDestinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: t.translate('nav_home'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.event_outlined),
        selectedIcon: const Icon(Icons.event),
        label: t.translate('nav_events'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.bar_chart_outlined),
        selectedIcon: const Icon(Icons.bar_chart),
        label: t.translate('nav_admin'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long),
        label: t.translate('nav_receipts'),
      ),
    ];

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: isAdminMod ? adminDestinations : memberDestinations,
    );
  }
}
