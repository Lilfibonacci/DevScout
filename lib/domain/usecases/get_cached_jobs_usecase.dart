import '../entities/job_entity.dart';
import '../repositories/job_repository.dart';

class CachedJobsData {
  final List<JobEntity> jobs;
  final Set<String> bookmarkedIds;

  const CachedJobsData({
    required this.jobs,
    required this.bookmarkedIds,
  });
}

class GetCachedJobsUseCase {
  final JobRepository repository;

  const GetCachedJobsUseCase(this.repository);

  Future<CachedJobsData> call() async {
    final jobs = await repository.getCachedJobs();
    final bookmarks = await repository.getBookmarkedIds();
    return CachedJobsData(jobs: jobs, bookmarkedIds: bookmarks);
  }
}
