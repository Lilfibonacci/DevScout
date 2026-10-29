import '../../domain/entities/job_entity.dart';

class JobModel extends JobEntity {
  const JobModel({
    required super.id,
    required super.title,
    required super.companyOrClient,
    required super.source,
    required super.salaryOrBudget,
    required super.city,
    required super.workMode,
    required super.contractType,
    required super.description,
    required super.skills,
    required super.publishedTimeText,
    required super.publishedAt,
    required super.originalUrl,
    super.proposalsCountText,
    super.isUrgent = false,
  });

  factory JobModel.fromEntity(JobEntity entity) {
    return JobModel(
      id: entity.id,
      title: entity.title,
      companyOrClient: entity.companyOrClient,
      source: entity.source,
      salaryOrBudget: entity.salaryOrBudget,
      city: entity.city,
      workMode: entity.workMode,
      contractType: entity.contractType,
      description: entity.description,
      skills: entity.skills,
      publishedTimeText: entity.publishedTimeText,
      publishedAt: entity.publishedAt,
      originalUrl: entity.originalUrl,
      proposalsCountText: entity.proposalsCountText,
      isUrgent: entity.isUrgent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'companyOrClient': companyOrClient,
      'source': source.name,
      'salaryOrBudget': salaryOrBudget,
      'city': city,
      'workMode': workMode.name,
      'contractType': contractType,
      'description': description,
      'skills': skills,
      'publishedTimeText': publishedTimeText,
      'publishedAt': publishedAt.toIso8601String(),
      'originalUrl': originalUrl,
      'proposalsCountText': proposalsCountText,
      'isUrgent': isUrgent,
    };
  }

  factory JobModel.fromJson(Map<String, dynamic> json) {
    final sourceStr = (json['source'] ?? 'jobinja').toString();
    final source = JobSource.values.firstWhere(
      (s) => s.name == sourceStr,
      orElse: () => JobSource.jobinja,
    );

    final workModeStr = (json['workMode'] ?? 'onSite').toString();
    final workMode = WorkMode.values.firstWhere(
      (w) => w.name == workModeStr,
      orElse: () => WorkMode.onSite,
    );

    return JobModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'بدون عنوان').toString(),
      companyOrClient:
          (json['companyOrClient'] ?? source.persianName).toString(),
      source: source,
      salaryOrBudget: (json['salaryOrBudget'] ?? 'توافقی').toString(),
      city: (json['city'] ?? 'ایران').toString(),
      workMode: workMode,
      contractType: (json['contractType'] ?? 'تمام‌وقت').toString(),
      description: (json['description'] ?? '').toString(),
      skills: (json['skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      publishedTimeText: (json['publishedTimeText'] ?? 'جدید').toString(),
      publishedAt: DateTime.tryParse((json['publishedAt'] ?? '').toString()) ??
          DateTime.now(),
      originalUrl:
          (json['originalUrl'] ?? 'https://${source.domain}').toString(),
      proposalsCountText: json['proposalsCountText']?.toString(),
      isUrgent: json['isUrgent'] == true,
    );
  }
}
