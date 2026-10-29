import '../entities/scrape_summary_entity.dart';
import '../repositories/job_repository.dart';

class ScrapeJobsUseCase {
  final JobRepository repository;

  const ScrapeJobsUseCase(this.repository);

  Future<ScrapeSummaryEntity> call({
    String? customQuery,
    bool isBackgroundCheck = false,
  }) {
    return repository.scrapeAndSyncJobs(
      customQuery: customQuery,
      isBackgroundCheck: isBackgroundCheck,
    );
  }
}
