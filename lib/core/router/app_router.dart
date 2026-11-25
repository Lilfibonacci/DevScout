import 'package:go_router/go_router.dart';
import '../../domain/entities/job_entity.dart';
import '../../presentation/bloc/jobs_bloc.dart';
import '../../presentation/bloc/jobs_event.dart';
import '../../presentation/bloc/jobs_state.dart';
import '../../presentation/pages/home_page.dart';
import '../../presentation/pages/job_detail_page.dart';
import '../../presentation/pages/notification_settings_page.dart';
import '../../presentation/pages/splash_page.dart';
import '../di/injection_container.dart';
import '../services/deep_link_service.dart';
import '../services/notification_tap_payload.dart';

class JobDetailRouteArgs {
  final JobEntity? initialJob;
  final String? fallbackUrl;
  final bool isPreviewOnly;

  const JobDetailRouteArgs({
    this.initialJob,
    this.fallbackUrl,
    this.isPreviewOnly = false,
  });
}

class AppRouter {
  String _initialLocation = '/splash';
  Object? _initialExtra;
  bool _hasHandledDeepLink = false;
  GoRouter? _router;

  bool get hasHandledDeepLink => _hasHandledDeepLink;

  /// پیکربندی مسیر آغازین پیش از ساخت اولین فریم برای پرش از اسپلش هنگام کلیک روی نوتیفیکیشن
  void configureInitialLaunch(NotificationTapPayload? payload) {
    if (payload == null) return;
    final jobId = payload.jobId;
    if (jobId != null && jobId.isNotEmpty) {
      _hasHandledDeepLink = true;
      final location = '/job/${Uri.encodeComponent(jobId)}';
      final extra = JobDetailRouteArgs(
        initialJob: payload.job,
        fallbackUrl: payload.targetUrl,
        isPreviewOnly: payload.isPreviewOnly,
      );
      if (_router == null) {
        _initialLocation = location;
        _initialExtra = extra;
      } else {
        _router!.go(location, extra: extra);
      }
    }
  }

  GoRouter get router => _router ??= GoRouter(
        initialLocation: _initialLocation,
        initialExtra: _initialExtra,
        overridePlatformDefaultLocation: _hasHandledDeepLink,
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
                  JobEntity? extraJob;
                  String? fallbackUrl;
                  bool isPreviewOnly = false;

                  if (state.extra is JobDetailRouteArgs) {
                    final args = state.extra as JobDetailRouteArgs;
                    extraJob = args.initialJob;
                    fallbackUrl = args.fallbackUrl;
                    isPreviewOnly = args.isPreviewOnly;
                  } else if (state.extra is JobEntity) {
                    extraJob = state.extra as JobEntity;
                  }

                  return JobDetailPage(
                    jobId: id,
                    initialJob: extraJob,
                    fallbackUrl: fallbackUrl,
                    isPreviewOnly: isPreviewOnly,
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

  /// هدایت آنی هنگام کلیک روی نوتیفیکیشن محلی یا فایربیس (همراه با تزریق فوری به BLoC)
  void handleNotificationTap(NotificationTapPayload payload) {
    _hasHandledDeepLink = true;
    final bloc = sl<JobsBloc>();

    if (payload.job != null) {
      bloc.add(JobsUpsertJobEvent(payload.job!));
    }

    final jobId = payload.jobId;
    if (jobId != null && jobId.isNotEmpty) {
      router.go(
        '/job/${Uri.encodeComponent(jobId)}',
        extra: JobDetailRouteArgs(
          initialJob: payload.job,
          fallbackUrl: payload.targetUrl,
          isPreviewOnly: payload.isPreviewOnly,
        ),
      );

      if (payload.job == null || payload.isPreviewOnly) {
        if (bloc.state.status != JobsStatus.loading) {
          bloc.add(const JobsRefreshRequestedEvent(showFeedback: false));
        }
      }
      return;
    }

    final targetUrl = payload.targetUrl;
    if (targetUrl != null && targetUrl.isNotEmpty) {
      sl<DeepLinkService>().openOriginalJobUrl(targetUrl);
    }
  }

  /// هدایت خودکار هنگام کلیک روی دیپ‌لینک ورودی
  void handleIncomingDeepLink(String? jobId, String? targetUrl) {
    handleNotificationTap(
      NotificationTapPayload.fromDeepLink(
        jobId: jobId,
        targetUrl: targetUrl,
      ),
    );
  }
}
