import 'package:go_router/go_router.dart';
import '../../domain/entities/job_entity.dart';
import '../../presentation/pages/home_page.dart';
import '../../presentation/pages/job_detail_page.dart';
import '../../presentation/pages/notification_settings_page.dart';
import '../../presentation/pages/splash_page.dart';
import '../di/injection_container.dart';
import '../services/deep_link_service.dart';

class AppRouter {
  late final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomePage(),
        routes: [
          GoRoute(
            path: 'job/:id',
            name: 'jobDetail',
            builder: (context, state) {
              final id = Uri.decodeComponent(state.pathParameters['id'] ?? '');
              final extraJob = state.extra is JobEntity
                  ? state.extra as JobEntity
                  : null;
              return JobDetailPage(
                jobId: id,
                initialJob: extraJob,
              );
            },
          ),
          GoRoute(
            path: 'settings/notifications',
            name: 'notificationSettings',
            builder: (context, state) => const NotificationSettingsPage(),
          ),
        ],
      ),
    ],
  );

  /// هدایت خودکار هنگام کلیک روی نوتیفیکیشن یا دیپ‌لینک ورودی
  void handleIncomingDeepLink(String? jobId, String? targetUrl) {
    if (jobId != null && jobId.isNotEmpty) {
      router.push('/job/${Uri.encodeComponent(jobId)}');
      return;
    }
    if (targetUrl != null && targetUrl.isNotEmpty) {
      sl<DeepLinkService>().openOriginalJobUrl(targetUrl);
    }
  }
}
