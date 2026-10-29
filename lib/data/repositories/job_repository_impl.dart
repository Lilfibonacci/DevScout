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

    var jobs = output.jobs;
    if (jobs.isNotEmpty) {
      await localDataSource.cacheJobs(jobs);
    } else {
      // در صورت عدم دسترسی موقت به شبکه، بازگرداندن آخرین کش مرتب‌شده
      jobs = await localDataSource.getCachedJobs();
    }

    final newlyNotifiedCount = await notificationService.notifyNewScrapedJobs(
      jobs,
      isBackgroundCheck: isBackgroundCheck,
    );

    return ScrapeSummaryEntity(
      jobs: jobs,
      sourceStatuses: output.sourceStatuses,
      fetchedAt: output.fetchedAt,
      newlyNotifiedCount: newlyNotifiedCount,
    );
  }
}
