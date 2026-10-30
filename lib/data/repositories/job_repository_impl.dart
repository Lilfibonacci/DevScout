import '../../core/services/notification_service.dart';
import '../../domain/entities/job_entity.dart';
import '../../domain/entities/scrape_summary_entity.dart';
import '../../domain/repositories/job_repository.dart';
import '../datasources/job_local_data_source.dart';
import '../datasources/job_remote_data_source.dart';

class JobRepositoryImpl implements JobRepository {
  final JobRemoteDataSource remoteDataSource;
  final JobLocalDataSource localDataSource;
  final NotificationService notificationService;

  const JobRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.notificationService,
  });

  @override
  Future<List<JobEntity>> getCachedJobs() async {
    return localDataSource.getCachedJobs();
  }

  @override
  Future<Set<String>> getBookmarkedIds() async {
    return localDataSource.getBookmarkedIds();
  }

  @override
  Future<Set<String>> toggleBookmark(String jobId) async {
    return localDataSource.toggleBookmark(jobId);
  }

  @override
  Future<ScrapeSummaryEntity> scrapeAndSyncJobs({
    String? customQuery,
    bool isBackgroundCheck = false,
  }) async {
    final output = await remoteDataSource.scrapeAllSources(
      customQuery: customQuery,
    );

    final cachedJobs = await localDataSource.getCachedJobs();
    final statuses = Map<JobSource, SourceScrapeStatusEntity>.from(
      output.sourceStatuses,
    );

    var jobs = List.of(output.jobs);
    if (jobs.isNotEmpty) {
      // اگر یکی از سایت‌ها (مثلاً جابینجا در زمان قطعی موقت یا VPN) خطا داد،
      // آگهی‌های کش‌شده قبلی همان سایت را حفظ کن تا لیست آن سایت خالی نشود.
      for (final source in JobSource.values) {
        final st = statuses[source];
        if (st == null || !st.isLiveScraped || st.count == 0) {
          final fallbackForSource =
              cachedJobs.where((j) => j.source == source).toList();
          if (fallbackForSource.isNotEmpty) {
            for (final item in fallbackForSource) {
              if (!jobs.any((existing) => existing.id == item.id)) {
                jobs.add(item);
              }
            }
            statuses[source] = SourceScrapeStatusEntity(
              source: source,
              isLiveScraped: false,
              count: fallbackForSource.length,
              statusMessage:
                  'از حافظه کش (${fallbackForSource.length} آگهی ذخیره شده)',
            );
          }
        }
      }
      jobs.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      await localDataSource.cacheJobs(jobs);
    } else {
      // در صورت عدم دسترسی موقت به شبکه، بازگرداندن آخرین کش مرتب‌شده
      jobs = cachedJobs;
    }

    final newlyNotifiedCount = await notificationService.notifyNewScrapedJobs(
      jobs,
      isBackgroundCheck: isBackgroundCheck,
    );

    return ScrapeSummaryEntity(
      jobs: jobs,
      sourceStatuses: statuses,
      fetchedAt: output.fetchedAt,
      newlyNotifiedCount: newlyNotifiedCount,
    );
  }
}
