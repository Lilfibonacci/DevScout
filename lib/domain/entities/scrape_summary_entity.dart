import 'package:equatable/equatable.dart';
import 'job_entity.dart';

class SourceScrapeStatusEntity extends Equatable {
  final JobSource source;
  final bool isLiveScraped;
  final int count;
  final String statusMessage;

  const SourceScrapeStatusEntity({
    required this.source,
    required this.isLiveScraped,
    required this.count,
    required this.statusMessage,
  });

  @override
  List<Object?> get props => [source, isLiveScraped, count, statusMessage];
}

class ScrapeSummaryEntity extends Equatable {
  final List<JobEntity> jobs;
  final Map<JobSource, SourceScrapeStatusEntity> sourceStatuses;
  final DateTime fetchedAt;
  final int newlyNotifiedCount;

  const ScrapeSummaryEntity({
    required this.jobs,
    required this.sourceStatuses,
    required this.fetchedAt,
    this.newlyNotifiedCount = 0,
  });

  @override
  List<Object?> get props => [
        jobs,
        sourceStatuses,
        fetchedAt,
        newlyNotifiedCount,
      ];
}
