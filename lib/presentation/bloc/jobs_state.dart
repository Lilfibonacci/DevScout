import 'package:equatable/equatable.dart';
import '../../domain/entities/job_entity.dart';
import '../../domain/entities/scrape_summary_entity.dart';

enum JobsStatus { initial, loading, success, failure }

class JobsState extends Equatable {
  final JobsStatus status;
  final List<JobEntity> allJobs;
  final Map<JobSource, SourceScrapeStatusEntity> sourceStatuses;
  final Set<String> bookmarkedIds;
  final String searchQuery;
  final JobRoleFilter selectedRoleFilter;
  final JobSource? selectedSourceFilter;
  final bool onlyRemote;
  final bool onlyBookmarked;
  final DateTime? lastUpdated;
  final String? feedbackMessage;
  final int feedbackVersion;

  JobsState({
    this.status = JobsStatus.initial,
    this.allJobs = const [],
    this.sourceStatuses = const {},
    this.bookmarkedIds = const {},
    this.searchQuery = '',
    this.selectedRoleFilter = JobRoleFilter.all,
    this.selectedSourceFilter,
    this.onlyRemote = false,
    this.onlyBookmarked = false,
    this.lastUpdated,
    this.feedbackMessage,
    this.feedbackVersion = 0,
  });

  late final List<JobEntity> freelanceJobs =
      getFilteredJobsForTab(JobTabCategory.freelance);

  late final List<JobEntity> employmentJobs =
      getFilteredJobsForTab(JobTabCategory.employment);

  late final Map<JobRoleFilter, int> roleCounts = {
    for (final role in JobRoleFilter.values)
      role: allJobs.where((j) => j.matchesRoleFilter(role)).length,
  };

  JobEntity? findJobById(String id) {
    for (final job in allJobs) {
      if (job.id == id) return job;
    }
    return null;
  }

  List<JobEntity> getFilteredJobsForTab(JobTabCategory tabCategory) {
    final filtered = allJobs.where((job) {
      if (job.tabCategory != tabCategory) return false;

      if (selectedSourceFilter != null &&
          selectedSourceFilter!.tabCategory == tabCategory &&
          job.source != selectedSourceFilter) {
        return false;
      }

      if (!job.matchesRoleFilter(selectedRoleFilter)) {
        return false;
      }

      if (onlyRemote && !job.isRemote) {
        return false;
      }

      if (onlyBookmarked && !bookmarkedIds.contains(job.id)) {
        return false;
      }

      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        final haystack =
            '${job.title} ${job.companyOrClient} ${job.city} ${job.description} ${job.skills.join(' ')}'
                .toLowerCase();
        if (!haystack.contains(q)) return false;
      }

      return true;
    }).toList();

    // تضمین نمایش جدیدترین آگهی‌ها در بالای لیست
    filtered.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return filtered;
  }

  JobsState copyWith({
    JobsStatus? status,
    List<JobEntity>? allJobs,
    Map<JobSource, SourceScrapeStatusEntity>? sourceStatuses,
    Set<String>? bookmarkedIds,
    String? searchQuery,
    JobRoleFilter? selectedRoleFilter,
    JobSource? selectedSourceFilter,
    bool clearSourceFilter = false,
    bool? onlyRemote,
    bool? onlyBookmarked,
    DateTime? lastUpdated,
    String? feedbackMessage,
    int? feedbackVersion,
  }) {
    return JobsState(
      status: status ?? this.status,
      allJobs: allJobs ?? this.allJobs,
      sourceStatuses: sourceStatuses ?? this.sourceStatuses,
      bookmarkedIds: bookmarkedIds ?? this.bookmarkedIds,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedRoleFilter: selectedRoleFilter ?? this.selectedRoleFilter,
      selectedSourceFilter: clearSourceFilter
          ? null
          : (selectedSourceFilter ?? this.selectedSourceFilter),
      onlyRemote: onlyRemote ?? this.onlyRemote,
      onlyBookmarked: onlyBookmarked ?? this.onlyBookmarked,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      feedbackMessage: feedbackMessage,
      feedbackVersion: feedbackVersion ?? this.feedbackVersion,
    );
  }

  @override
  List<Object?> get props => [
        status,
        allJobs,
        sourceStatuses,
        bookmarkedIds,
        searchQuery,
        selectedRoleFilter,
        selectedSourceFilter,
        onlyRemote,
        onlyBookmarked,
        lastUpdated,
        feedbackMessage,
        feedbackVersion,
      ];
}
