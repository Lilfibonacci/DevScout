import 'package:equatable/equatable.dart';
import '../../domain/entities/job_entity.dart';

sealed class JobsEvent extends Equatable {
  const JobsEvent();

  @override
  List<Object?> get props => [];
}

class JobsInitializedEvent extends JobsEvent {
  const JobsInitializedEvent();
}

class JobsRefreshRequestedEvent extends JobsEvent {
  final bool showFeedback;

  const JobsRefreshRequestedEvent({this.showFeedback = true});

  @override
  List<Object?> get props => [showFeedback];
}

class JobsSearchQueryChangedEvent extends JobsEvent {
  final String query;

  const JobsSearchQueryChangedEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class JobsRoleFilterChangedEvent extends JobsEvent {
  final JobRoleFilter roleFilter;

  const JobsRoleFilterChangedEvent(this.roleFilter);

  @override
  List<Object?> get props => [roleFilter];
}

class JobsSourceFilterChangedEvent extends JobsEvent {
  final JobSource? sourceFilter;

  const JobsSourceFilterChangedEvent(this.sourceFilter);

  @override
  List<Object?> get props => [sourceFilter];
}

class JobsRemoteOnlyToggledEvent extends JobsEvent {
  final bool onlyRemote;

  const JobsRemoteOnlyToggledEvent(this.onlyRemote);

  @override
  List<Object?> get props => [onlyRemote];
}

class JobsBookmarkedOnlyToggledEvent extends JobsEvent {
  final bool onlyBookmarked;

  const JobsBookmarkedOnlyToggledEvent(this.onlyBookmarked);

  @override
  List<Object?> get props => [onlyBookmarked];
}

class JobsClearFiltersEvent extends JobsEvent {
  const JobsClearFiltersEvent();
}

class JobBookmarkToggledEvent extends JobsEvent {
  final String jobId;

  const JobBookmarkToggledEvent(this.jobId);

  @override
  List<Object?> get props => [jobId];
}
