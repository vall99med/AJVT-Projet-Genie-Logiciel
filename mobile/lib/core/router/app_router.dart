import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/pin_screen.dart';
import '../../features/member/presentation/register_screen.dart';
import '../../features/member/presentation/profile_screen.dart';
import '../../features/member/presentation/member_card_screen.dart';
import '../../features/member/presentation/members_list_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/payment/presentation/submit_payment_screen.dart';
import '../../features/payment/presentation/payment_history_screen.dart';
import '../../features/payment/presentation/review_payments_screen.dart';
import '../../features/payment/presentation/receipt_viewer_screen.dart';
import '../../features/posts/presentation/feed_screen.dart';
import '../../features/posts/presentation/post_detail_screen.dart';
import '../../features/posts/presentation/create_post_screen.dart';
import '../../features/posts/presentation/events_screen.dart';
import '../../features/posts/presentation/event_detail_screen.dart';
import '../../features/posts/presentation/create_event_screen.dart';
import '../../features/posts/presentation/event_attendance_screen.dart';
import '../../features/member/presentation/directory_screen.dart';
import '../../features/member/presentation/member_profile_screen.dart';

// Notifier qui relie l'état Riverpod au refresh GoRouter
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authNotifierProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authNotifierProvider);
    final loc  = state.matchedLocation;

    final authRoutes  = {'/phone', '/login', '/otp', '/pin'};
    final isAuthRoute = authRoutes.any((r) => loc.startsWith(r));

    // Utilisateur authentifié sur un écran d'auth → redirection vers l'app
    if (auth.isAuthenticated && isAuthRoute) {
      return '/feed';
    }
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: '/phone',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/phone', builder: (_, __) => const PhoneScreen()),
      GoRoute(path: '/login', builder: (_, __) => const PhoneScreen(startWithLogin: true)),
      GoRoute(
        path: '/otp',
        builder: (_, s) {
          final extra = s.extra as Map<String, dynamic>;
          return OtpScreen(
            phone: extra['phone'] as String,
            mode:  extra['mode']  as String? ?? 'signup',
          );
        },
      ),
      GoRoute(
        path: '/pin',
        builder: (_, s) {
          final extra = s.extra as Map<String, dynamic>;
          return PinScreen(
            phone:   extra['phone']   as String,
            isLogin: extra['isLogin'] as bool?   ?? false,
            isReset: extra['isReset'] as bool?   ?? false,
            otpCode: extra['otpCode'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/register',
        builder: (_, s) => RegisterScreen(phone: s.extra as String),
      ),
      GoRoute(path: '/profile',   builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/card',      builder: (_, __) => const MemberCardScreen()),
      GoRoute(path: '/members',   builder: (_, __) => const MembersListScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),

      // ── Paiements ──────────────────────────────────────────────────
      GoRoute(path: '/payment/submit',  builder: (_, __) => const SubmitPaymentScreen()),
      GoRoute(path: '/payment/history', builder: (_, __) => const PaymentHistoryScreen()),
      GoRoute(path: '/payment/review',  builder: (_, __) => const ReviewPaymentsScreen()),
      GoRoute(
        path: '/payment/receipt',
        builder: (_, s) => ReceiptViewerScreen(imageUrl: s.extra as String),
      ),

      // ── Fil d'actualité ────────────────────────────────────────────
      GoRoute(path: '/feed',         builder: (_, __) => const FeedScreen()),
      GoRoute(path: '/post/create',  builder: (_, __) => const CreatePostScreen()),
      GoRoute(
        path: '/post/:id',
        builder: (_, s) => PostDetailScreen(id: int.parse(s.pathParameters['id']!)),
      ),

      // ── Annuaire avancé (BF-10 à BF-13) ───────────────────────────
      GoRoute(path: '/directory', builder: (_, __) => const DirectoryScreen()),
      GoRoute(
        path: '/member/:id',
        builder: (_, s) => MemberProfileScreen(userId: int.parse(s.pathParameters['id']!)),
      ),

      // ── Événements ─────────────────────────────────────────────────
      GoRoute(path: '/events',        builder: (_, __) => const EventsScreen()),
      GoRoute(path: '/event/create',  builder: (_, __) => const CreateEventScreen()),
      GoRoute(
        path: '/event/:id',
        builder: (_, s) => EventDetailScreen(id: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/event/:id/attendance',
        builder: (_, s) => EventAttendanceScreen(eventId: int.parse(s.pathParameters['id']!)),
      ),
    ],
  );
});
