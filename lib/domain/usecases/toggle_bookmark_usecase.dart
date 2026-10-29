import '../repositories/job_repository.dart';

class ToggleBookmarkUseCase {
  final JobRepository repository;

  const ToggleBookmarkUseCase(this.repository);

  Future<Set<String>> call(String jobId) {
    return repository.toggleBookmark(jobId);
  }
}
