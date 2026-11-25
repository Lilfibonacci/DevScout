import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_radar/core/di/injection_container.dart';
import 'package:job_radar/core/router/app_router.dart';
import 'package:job_radar/core/services/notification_service.dart';
import 'package:job_radar/core/services/notification_tap_payload.dart';
import 'package:job_radar/data/models/job_model.dart';
import 'package:job_radar/domain/entities/job_entity.dart';
import 'package:job_radar/domain/entities/scrape_summary_entity.dart';
import 'package:job_radar/domain/repositories/job_repository.dart';
import 'package:job_radar/domain/usecases/get_cached_jobs_usecase.dart';
import 'package:job_radar/domain/usecases/scrape_jobs_usecase.dart';
import 'package:job_radar/domain/usecases/toggle_bookmark_usecase.dart';
import 'package:job_radar/presentation/bloc/jobs_bloc.dart';
import 'package:job_radar/presentation/bloc/jobs_event.dart';
import 'package:job_radar/presentation/bloc/locale_cubit.dart';
import 'package:job_radar/presentation/bloc/theme_cubit.dart';
import 'package:job_radar/presentation/pages/home_page.dart';
import 'package:job_radar/presentation/pages/job_detail_page.dart';
import 'package:job_radar/presentation/pages/splash_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeJobRepository implements JobRepository {
  List<JobEntity> cachedJobs;
  ScrapeSummaryEntity Function()? onScrape;
  int scrapeCalls = 0;

  _FakeJobRepository({
    this.cachedJobs = const <JobEntity>[],
    this.onScrape,
  });

  @override
  Future<Set<String>> getBookmarkedIds() async => <String>{};

  @override
  Future<List<JobEntity>> getCachedJobs() async => cachedJobs;

  @override
  Future<ScrapeSummaryEntity> scrapeAndSyncJobs({
    String? customQuery,
    bool isBackgroundCheck = false,
  }) async {
    scrapeCalls++;
    if (onScrape != null) {
      return onScrape!();
    }
    return ScrapeSummaryEntity(
      jobs: cachedJobs,
      sourceStatuses: const {},
      fetchedAt: DateTime.now(),
      newlyNotifiedCount: 0,
    );
  }

  @override
  Future<Set<String>> toggleBookmark(String jobId) async => {jobId};
}

JobModel _buildSampleJob({
  String id = 'ponisha_777001',
  String title = 'توسعه اپلیکیشن فروشگاهی با فلاتر',
  String description =
      'پیاده‌سازی کامل رابط کاربری فلاتر با BLoC و اتصال به وب‌سرویس REST.',
  JobSource source = JobSource.ponisha,
  DateTime? publishedAt,
}) {
  return JobModel(
    id: id,
    title: title,
    companyOrClient: source == JobSource.jobinja ? 'شرکت نمونه' : '',
    source: source,
    salaryOrBudget: '۳۰,۰۰۰,۰۰۰ تومان',
    city: 'تهران',
    workMode: WorkMode.remote,
    contractType: 'پروژه‌ای / فریلنسری',
    description: description,
    skills: const ['Flutter', 'Dart', 'BLoC'],
    publishedTimeText: 'لحظاتی پیش',
    publishedAt: publishedAt ?? DateTime.now(),
    originalUrl: 'https://ponisha.ir/project/777001',
    isUrgent: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationTapPayload parsing', () {
    test('parses rich FCM payload directly into complete JobModel', () {
      final payload = NotificationTapPayload.fromDataMap({
        'id': 'ponisha_888',
        'jobId': 'ponisha_888',
        'title': 'ساخت اپلیکیشن فلاتر',
        'company': '',
        'source': 'پونیشا',
        'sourceKey': 'ponisha',
        'salary': '۲۵,۰۰۰,۰۰۰ تا ۴۰,۰۰۰,۰۰۰ تومان',
        'city': 'سراسر ایران (آنلاین)',
        'workMode': 'remote',
        'contractType': 'پروژه‌ای / فریلنسری',
        'description': 'نیازمند توسعه‌دهنده مسلط به فلاتر و BLoC.',
        'skills': jsonEncode(['Flutter', 'Dart', 'BLoC']),
        'publishedAt': '2026-11-25T20:00:00.000Z',
        'publishedTimeText': 'لحظاتی پیش',
        'proposalsCountText': '۴ پیشنهاد ثبت شده',
        'isUrgent': 'true',
        'url': 'https://ponisha.ir/project/888',
      });

      expect(payload.jobId, 'ponisha_888');
      expect(payload.targetUrl, 'https://ponisha.ir/project/888');
      expect(payload.isPreviewOnly, isFalse);
      expect(payload.job, isNotNull);
      expect(payload.job!.source, JobSource.ponisha);
      expect(payload.job!.workMode, WorkMode.remote);
      expect(payload.job!.skills, ['Flutter', 'Dart', 'BLoC']);
      expect(payload.job!.proposalsCountText, '۴ پیشنهاد ثبت شده');
      expect(payload.job!.isUrgent, isTrue);
    });

    test('parses legacy minimal FCM payload into preview JobModel', () {
      final payload = NotificationTapPayload.fromDataMap(
        {
          'id': 'karlancer_1234',
          'jobId': 'karlancer_1234',
          'url': 'https://www.karlancer.com/projects/1234',
          'source': 'کارلنسر',
        },
        notificationTitle: '🔔 کارلنسر: توسعه اپ اندروید',
        notificationBody: '📍 سراسر ایران (دورکاری) | 💰 ۱۵,۰۰۰,۰۰۰ تومان',
      );

      expect(payload.jobId, 'karlancer_1234');
      expect(payload.isPreviewOnly, isTrue);
      expect(payload.job, isNotNull);
      expect(payload.job!.source, JobSource.karlancer);
      expect(payload.job!.title, 'توسعه اپ اندروید');
    });

    test('parses local notification JSON payload with embedded job', () {
      final job = _buildSampleJob(id: 'jobinja_abc1');
      final raw = jsonEncode({
        'jobId': job.id,
        'targetUrl': job.originalUrl,
        'job': job.toJson(),
      });

      final payload = NotificationTapPayload.fromLocalPayload(raw);
      expect(payload.jobId, 'jobinja_abc1');
      expect(payload.isPreviewOnly, isFalse);
      expect(payload.job, isNotNull);
      expect(payload.job!.title, job.title);
    });
  });

  group('NotificationService deduplication & caching', () {
    test('stableNotificationId is deterministic and sanitizeTag caps length',
        () {
      final id1 = NotificationService.stableNotificationId('ponisha_777001');
      final id2 = NotificationService.stableNotificationId('ponisha_777001');
      final id3 = NotificationService.stableNotificationId('ponisha_777002');
      expect(id1, id2);
      expect(id1, isNot(equals(id3)));
      expect(id1, greaterThanOrEqualTo(0));
      expect(id1, lessThan(100000));

      final longTag = NotificationService.sanitizeTag('a/b:c ' * 20);
      expect(longTag, isNotNull);
      expect(longTag!.length, 64);
      expect(longTag.contains('/'), isFalse);
    });

    test(
        'foreground scrape records IDs without firing local notifications and background skips known jobs',
        () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'fcm_push_active': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final service = NotificationService(sharedPreferences: prefs);

      final job = _buildSampleJob(id: 'ponisha_fg_1');
      final fgCount = await service.notifyNewScrapedJobs(
        [job],
        isBackgroundCheck: false,
      );
      expect(fgCount, 1);
      expect(await service.isJobAlreadyNotified(job.id), isTrue);

      // Background check for the exact same recent job must NOT re-notify
      final bgCount = await service.notifyNewScrapedJobs(
        [job],
        isBackgroundCheck: true,
      );
      expect(bgCount, 0);
    });

    test(
        'background check suppresses local notifications when fcm_push_active is true',
        () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'fcm_push_active': true,
        'known_job_ids': ['existing_1'],
        'notified_job_ids': ['existing_1'],
      });
      final prefs = await SharedPreferences.getInstance();
      final service = NotificationService(sharedPreferences: prefs);

      final brandNewJob = _buildSampleJob(id: 'karlancer_new_99');
      final bgCount = await service.notifyNewScrapedJobs(
        [brandNewJob],
        isBackgroundCheck: true,
      );
      expect(bgCount, 0);
      expect(prefs.getStringList('known_job_ids'), contains('karlancer_new_99'));
      expect(
        prefs.getStringList('notified_job_ids'),
        contains('karlancer_new_99'),
      );
    });

    test(
        'background check without FCM notifies brand-new job at most once and never re-notifies',
        () async {
      SharedPreferences.setMockInitialValues({
        'notifications_enabled': true,
        'fcm_push_active': false,
        'known_job_ids': ['existing_1'],
        'notified_job_ids': ['existing_1'],
      });
      final prefs = await SharedPreferences.getInstance();
      final service = NotificationService(sharedPreferences: prefs);

      final brandNewJob = _buildSampleJob(id: 'ponisha_new_42');
      final firstCount = await service.notifyNewScrapedJobs(
        [brandNewJob],
        isBackgroundCheck: true,
      );
      expect(firstCount, 1);

      final secondCount = await service.notifyNewScrapedJobs(
        [brandNewJob],
        isBackgroundCheck: true,
      );
      expect(secondCount, 0);
    });

    test('cacheJobFromPush inserts new job and preserves richer descriptions',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = NotificationService(sharedPreferences: prefs);

      final richJob = _buildSampleJob(
        id: 'jobvision_500',
        description:
            'این یک توضیح بسیار کامل و طولانی درباره موقعیت شغلی فلاتر در شرکت نمونه است.',
      );
      final previewJob = _buildSampleJob(
        id: 'jobvision_500',
        description: 'خلاصه کوتاه',
      );

      await service.cacheJobFromPush(richJob);
      await service.cacheJobFromPush(previewJob);

      final raw = prefs.getString('cached_jobs_json');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List<dynamic>;
      expect(decoded.length, 1);
      expect(
        (decoded.first as Map<String, dynamic>)['description'],
        richJob.description,
      );
    });
  });

  group('JobsBloc upsert & merge', () {
    test('keeps notification-upserted job across cache load and upgrades when live scrape brings richer details',
        () async {
      final previewJob = _buildSampleJob(
        id: 'ponisha_notif_1',
        description: 'پیش‌نمایش',
      );
      final cachedOther = _buildSampleJob(id: 'karlancer_cached_2');
      final fullScraped = _buildSampleJob(
        id: 'ponisha_notif_1',
        description:
            'توضیحات کامل و دقیق پروژه فلاتر که پس از اتمام اسکرپ از سرور دریافت شد.',
      );

      final fakeRepo = _FakeJobRepository(
        cachedJobs: [cachedOther],
        onScrape: () => ScrapeSummaryEntity(
          jobs: [cachedOther, fullScraped],
          sourceStatuses: const {},
          fetchedAt: DateTime.now(),
          newlyNotifiedCount: 1,
        ),
      );

      final bloc = JobsBloc(
        getCachedJobsUseCase: GetCachedJobsUseCase(fakeRepo),
        scrapeJobsUseCase: ScrapeJobsUseCase(fakeRepo),
        toggleBookmarkUseCase: ToggleBookmarkUseCase(fakeRepo),
      );

      bloc.add(JobsUpsertJobEvent(previewJob));
      bloc.add(const JobsInitializedEvent());

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final resolved = bloc.state.findJobById('ponisha_notif_1');
      expect(resolved, isNotNull);
      expect(resolved!.description, fullScraped.description);
      expect(bloc.state.findJobById('karlancer_cached_2'), isNotNull);

      await bloc.close();
    });
  });

  group('AppRouter & JobDetailPage instant notification launch', () {
    testWidgets(
        'launches directly into JobDetailPage skipping SplashPage and pops back to HomePage',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await initDependencies();

      final richJob = _buildSampleJob(
        id: 'ponisha_direct_1',
        title: 'اپلیکیشن فوری فلاتر برای تست نوتیفیکیشن',
      );
      final fakeRepo = _FakeJobRepository(cachedJobs: const []);
      sl.unregister<JobRepository>();
      sl.registerLazySingleton<JobRepository>(() => fakeRepo);

      sl<JobsBloc>().add(JobsUpsertJobEvent(richJob));
      sl<AppRouter>().configureInitialLaunch(
        NotificationTapPayload(
          jobId: richJob.id,
          targetUrl: richJob.originalUrl,
          job: richJob,
          isPreviewOnly: false,
        ),
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<JobsBloc>.value(value: sl<JobsBloc>()),
            BlocProvider<ThemeCubit>.value(value: sl<ThemeCubit>()),
            BlocProvider<LocaleCubit>.value(value: sl<LocaleCubit>()),
          ],
          child: MaterialApp.router(
            locale: const Locale('fa', 'IR'),
            supportedLocales: const [
              Locale('fa', 'IR'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: sl<AppRouter>().router,
          ),
        ),
      );
      await tester.pump();

      // Immediate render on JobDetailPage with zero splash delay
      expect(find.byType(JobDetailPage), findsOneWidget);
      expect(find.byType(SplashPage), findsNothing);
      expect(find.text(richJob.title), findsOneWidget);

      // Advance past old 2.4s splash timer to confirm it does not hijack the route
      await tester.pump(const Duration(milliseconds: 2600));
      expect(find.byType(JobDetailPage), findsOneWidget);

      // Navigate back -> HomePage is on stack underneath
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await sl.reset();
    });

    testWidgets(
        'missing job route displays external browser fallback button immediately',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await initDependencies();

      final fakeRepo = _FakeJobRepository(cachedJobs: const []);
      sl.unregister<JobRepository>();
      sl.registerLazySingleton<JobRepository>(() => fakeRepo);

      sl<AppRouter>().configureInitialLaunch(
        const NotificationTapPayload(
          jobId: 'ponisha_missing_999',
          targetUrl: 'https://ponisha.ir/project/999',
          isPreviewOnly: true,
        ),
      );

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<JobsBloc>.value(value: sl<JobsBloc>()),
            BlocProvider<ThemeCubit>.value(value: sl<ThemeCubit>()),
            BlocProvider<LocaleCubit>.value(value: sl<LocaleCubit>()),
          ],
          child: MaterialApp.router(
            locale: const Locale('fa', 'IR'),
            supportedLocales: const [
              Locale('fa', 'IR'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: sl<AppRouter>().router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(JobDetailPage), findsOneWidget);
      expect(find.text('مشاهده در سایت مرجع'), findsOneWidget);
      expect(fakeRepo.scrapeCalls, greaterThanOrEqualTo(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await sl.reset();
    });
  });
}
