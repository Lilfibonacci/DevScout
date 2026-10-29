import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../../data/datasources/job_local_data_source.dart';
import '../../data/datasources/job_remote_data_source.dart';
import '../../data/repositories/job_repository_impl.dart';
import '../../domain/entities/job_entity.dart';
import 'notification_service.dart';

/// نقطه ورود ایزوله پس‌زمینه اندروید (زمانی که اپ کاملاً بسته یا در پس‌زمینه است)
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationService = NotificationService(sharedPreferences: prefs);
      await notificationService.initForBackgroundIsolate();

      final localDataSource = JobLocalDataSourceImpl(
        sharedPreferences: prefs,
        useWorkerIsolate: false,
      );
      final remoteDataSource = JobRemoteDataSourceImpl(
        useWorkerIsolate: false,
      );
      final repository = JobRepositoryImpl(
        remoteDataSource: remoteDataSource,
        localDataSource: localDataSource,
        notificationService: notificationService,
      );

      final isTest = taskName == BackgroundWorkerService.oneOffTestTaskName;
      final summary =
          await repository.scrapeAndSyncJobs(isBackgroundCheck: true);

      // در تست پس‌زمینه اگر آگهی جدیدی منتشر نشده بود، آخرین آگهی را به عنوان اثبات کارکرد ارسال کن
      if (isTest && summary.newlyNotifiedCount == 0 && summary.jobs.isNotEmpty) {
        final sample = summary.jobs.first;
        await notificationService.showInstantNotification(
          title: '🔔 تست موفق پس‌زمینه (اپ کاملاً بسته است): ${sample.title}',
          body:
              '💰 ${sample.salaryOrBudget} | 📍 ${sample.city} (${sample.source.persianName})\nسرویس پس‌زمینه DevScout در زمان بسته بودن اپ با موفقیت اجرا شد!',
          jobId: sample.id,
          targetUrl: sample.originalUrl,
        );
      }

      return true;
    } catch (e, stack) {
      debugPrint('Background scrape task error: $e\n$stack');
      return false;
    }
  });
}

class BackgroundWorkerService {
  final SharedPreferences sharedPreferences;

  BackgroundWorkerService({required this.sharedPreferences});

  static const String periodicUniqueName = 'job_radar_periodic_scraper';
  static const String periodicScrapeTaskName = 'scrape_jobs_periodic_task';

  static const String oneOffUniqueName = 'job_radar_oneoff_test';
  static const String oneOffTestTaskName = 'scrape_jobs_oneoff_test_task';

  static const String onCloseUniqueName = 'job_radar_on_close_check';
  static const String onCloseTaskName = 'scrape_jobs_on_close_task';

  bool isSupportedAndActive = false;

  Future<void> initializeAndSchedule() async {
    try {
      await Workmanager().initialize(backgroundCallbackDispatcher);
      final enabled =
          sharedPreferences.getBool('background_worker_enabled') ?? true;
      if (enabled) {
        await registerPeriodicScrape();
      }
      isSupportedAndActive = enabled;
    } catch (e) {
      debugPrint('WorkManager init skipped on this platform: $e');
      isSupportedAndActive = false;
    }
  }

  Future<void> registerPeriodicScrape() async {
    try {
      await Workmanager().registerPeriodicTask(
        periodicUniqueName,
        periodicScrapeTaskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
      isSupportedAndActive = true;
    } catch (e) {
      debugPrint('Failed to register periodic background task: $e');
    }
  }

  Future<void> scheduleCheckOnAppExit() async {
    try {
      final enabled =
          sharedPreferences.getBool('background_worker_enabled') ?? true;
      if (!enabled) return;

      await Workmanager().registerOneOffTask(
        onCloseUniqueName,
        onCloseTaskName,
        initialDelay: const Duration(seconds: 15),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    } catch (e) {
      debugPrint('Failed to schedule on-exit task: $e');
    }
  }

  Future<void> cancelBackgroundScrape() async {
    try {
      await Workmanager().cancelByUniqueName(periodicUniqueName);
      await Workmanager().cancelByUniqueName(onCloseUniqueName);
      isSupportedAndActive = false;
    } catch (_) {}
  }

  Future<void> triggerDelayedBackgroundTest() async {
    try {
      await Workmanager().registerOneOffTask(
        oneOffUniqueName,
        oneOffTestTaskName,
        initialDelay: const Duration(seconds: 8),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    } catch (e) {
      debugPrint('Failed to schedule one-off background test: $e');
    }
  }
}
