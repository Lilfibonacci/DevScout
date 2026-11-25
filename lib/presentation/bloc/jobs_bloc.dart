import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/job_entity.dart';
import '../../domain/usecases/get_cached_jobs_usecase.dart';
import '../../domain/usecases/scrape_jobs_usecase.dart';
import '../../domain/usecases/toggle_bookmark_usecase.dart';
import 'jobs_event.dart';
import 'jobs_state.dart';

class JobsBloc extends Bloc<JobsEvent, JobsState> {
  final GetCachedJobsUseCase getCachedJobsUseCase;
  final ScrapeJobsUseCase scrapeJobsUseCase;
  final ToggleBookmarkUseCase toggleBookmarkUseCase;
  final Map<String, JobEntity> _pinnedJobs = <String, JobEntity>{};

  JobsBloc({
    required this.getCachedJobsUseCase,
    required this.scrapeJobsUseCase,
    required this.toggleBookmarkUseCase,
  }) : super(JobsState()) {
    on<JobsInitializedEvent>(_onInitialized);
    on<JobsRefreshRequestedEvent>(_onRefreshRequested);
    on<JobsSearchQueryChangedEvent>(_onSearchQueryChanged);
    on<JobsRoleFilterChangedEvent>(_onRoleFilterChanged);
    on<JobsSourceFilterChangedEvent>(_onSourceFilterChanged);
    on<JobsRemoteOnlyToggledEvent>(_onRemoteOnlyToggled);
    on<JobsBookmarkedOnlyToggledEvent>(_onBookmarkedOnlyToggled);
    on<JobsClearFiltersEvent>(_onClearFilters);
    on<JobBookmarkToggledEvent>(_onBookmarkToggled);
    on<JobsUpsertJobEvent>(_onUpsertJob);
  }

  List<JobEntity> _mergeWithPinned(List<JobEntity> incoming) {
    final byId = <String, JobEntity>{
      for (final job in incoming) job.id: job,
    };

    final upgradedIds = <String>[];
    for (final entry in _pinnedJobs.entries) {
      final existing = byId[entry.key];
      if (existing == null) {
        byId[entry.key] = entry.value;
      } else if (existing.description.trim().length >=
          entry.value.description.trim().length) {
        upgradedIds.add(entry.key);
      } else {
        byId[entry.key] = entry.value;
      }
    }
    for (final id in upgradedIds) {
      _pinnedJobs.remove(id);
    }

    final merged = byId.values.toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return merged;
  }

  void _onUpsertJob(
    JobsUpsertJobEvent event,
    Emitter<JobsState> emit,
  ) {
    final incoming = event.job;
    final existingPinned = _pinnedJobs[incoming.id];
    if (existingPinned == null ||
        incoming.description.trim().length >=
            existingPinned.description.trim().length) {
      _pinnedJobs[incoming.id] = incoming;
    }

    final merged = _mergeWithPinned(state.allJobs);
    emit(
      state.copyWith(
        status: state.status == JobsStatus.initial
            ? JobsStatus.success
            : state.status,
        allJobs: merged,
      ),
    );
  }

  Future<void> _onInitialized(
    JobsInitializedEvent event,
    Emitter<JobsState> emit,
  ) async {
    emit(state.copyWith(status: JobsStatus.loading));

    final cachedData = await getCachedJobsUseCase();
    if (cachedData.jobs.isNotEmpty) {
      emit(
        state.copyWith(
          status: JobsStatus.success,
          allJobs: _mergeWithPinned(cachedData.jobs),
          bookmarkedIds: cachedData.bookmarkedIds,
        ),
      );
    } else {
      emit(state.copyWith(bookmarkedIds: cachedData.bookmarkedIds));
    }

    await _performScrape(emit, showFeedback: false);
  }

  Future<void> _onRefreshRequested(
    JobsRefreshRequestedEvent event,
    Emitter<JobsState> emit,
  ) async {
    emit(state.copyWith(status: JobsStatus.loading));
    await _performScrape(emit, showFeedback: event.showFeedback);
  }

  Future<void> _performScrape(
    Emitter<JobsState> emit, {
    required bool showFeedback,
  }) async {
    try {
      final summary = await scrapeJobsUseCase(
        customQuery:
            state.searchQuery.trim().isNotEmpty ? state.searchQuery : null,
      );

      String? msg;
      if (showFeedback) {
        msg = summary.newlyNotifiedCount > 0
            ? '${summary.newlyNotifiedCount} آگهی جدید یافت شد و لیست به‌روزرسانی گردید!'
            : 'آگهی‌های پونیشا، کارلنسر، جابینجا و جاب‌ویژن به‌روزرسانی شدند.';
      }

      emit(
        state.copyWith(
          status: JobsStatus.success,
          allJobs: _mergeWithPinned(summary.jobs),
          sourceStatuses: summary.sourceStatuses,
          lastUpdated: summary.fetchedAt,
          feedbackMessage: msg,
          feedbackVersion: state.feedbackVersion + 1,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: state.allJobs.isNotEmpty
              ? JobsStatus.success
              : JobsStatus.failure,
        ),
      );
    }
  }

  void _onSearchQueryChanged(
    JobsSearchQueryChangedEvent event,
    Emitter<JobsState> emit,
  ) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onRoleFilterChanged(
    JobsRoleFilterChangedEvent event,
    Emitter<JobsState> emit,
  ) {
    emit(state.copyWith(selectedRoleFilter: event.roleFilter));
  }

  void _onSourceFilterChanged(
    JobsSourceFilterChangedEvent event,
    Emitter<JobsState> emit,
  ) {
    emit(
      state.copyWith(
        selectedSourceFilter: event.sourceFilter,
        clearSourceFilter: event.sourceFilter == null,
      ),
    );
  }

  void _onRemoteOnlyToggled(
    JobsRemoteOnlyToggledEvent event,
    Emitter<JobsState> emit,
  ) {
    emit(state.copyWith(onlyRemote: event.onlyRemote));
  }

  void _onBookmarkedOnlyToggled(
    JobsBookmarkedOnlyToggledEvent event,
    Emitter<JobsState> emit,
  ) {
    emit(state.copyWith(onlyBookmarked: event.onlyBookmarked));
  }

  void _onClearFilters(
    JobsClearFiltersEvent event,
    Emitter<JobsState> emit,
  ) {
    emit(
      state.copyWith(
        searchQuery: '',
        selectedRoleFilter: JobRoleFilter.all,
        clearSourceFilter: true,
        onlyRemote: false,
        onlyBookmarked: false,
      ),
    );
  }

  Future<void> _onBookmarkToggled(
    JobBookmarkToggledEvent event,
    Emitter<JobsState> emit,
  ) async {
    final updatedBookmarks = await toggleBookmarkUseCase(event.jobId);
    emit(state.copyWith(bookmarkedIds: updatedBookmarks));
  }
}
