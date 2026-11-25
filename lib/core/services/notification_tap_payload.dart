import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../data/models/job_model.dart';
import '../../domain/entities/job_entity.dart';

/// مدل استاندارد اطلاعات حمل‌شده در کلیک نوتیفیکیشن یا دیپ‌لینک برای باز شدن آنی صفحه آگهی
class NotificationTapPayload {
  final String? jobId;
  final String? targetUrl;
  final JobModel? job;
  final bool isPreviewOnly;

  const NotificationTapPayload({
    this.jobId,
    this.targetUrl,
    this.job,
    this.isPreviewOnly = false,
  });

  bool get hasAction =>
      (jobId != null && jobId!.isNotEmpty) ||
      (targetUrl != null && targetUrl!.isNotEmpty);

  factory NotificationTapPayload.fromRemoteMessage(RemoteMessage message) {
    return NotificationTapPayload.fromDataMap(
      message.data,
      notificationTitle: message.notification?.title,
      notificationBody: message.notification?.body,
    );
  }

  factory NotificationTapPayload.fromLocalPayload(String? rawPayload) {
    if (rawPayload == null || rawPayload.trim().isEmpty) {
      return const NotificationTapPayload();
    }
    final trimmed = rawPayload.trim();
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return NotificationTapPayload.fromDataMap(decoded);
      }
      if (decoded is Map) {
        return NotificationTapPayload.fromDataMap(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return NotificationTapPayload(targetUrl: trimmed, isPreviewOnly: true);
      }
    }
    return const NotificationTapPayload();
  }

  factory NotificationTapPayload.fromDeepLink({
    String? jobId,
    String? targetUrl,
  }) {
    return NotificationTapPayload(
      jobId: _cleanOptional(jobId),
      targetUrl: _cleanOptional(targetUrl),
      isPreviewOnly: true,
    );
  }

  factory NotificationTapPayload.fromDataMap(
    Map<String, dynamic> data, {
    String? notificationTitle,
    String? notificationBody,
  }) {
    final jobId = _cleanOptional(data['jobId'] ?? data['id']);
    final targetUrl = _cleanOptional(
      data['url'] ?? data['originalUrl'] ?? data['targetUrl'],
    );

    final embeddedJob = data['job'];
    if (embeddedJob is Map) {
      final parsedJob = JobModel.fromJson(
        Map<String, dynamic>.from(embeddedJob),
      );
      return NotificationTapPayload(
        jobId: jobId ?? parsedJob.id,
        targetUrl: targetUrl ?? parsedJob.originalUrl,
        job: parsedJob,
        isPreviewOnly: false,
      );
    }

    final rawTitle = _cleanOptional(data['title']);
    final fallbackTitle = _cleanNotificationTitle(notificationTitle);
    final effectiveTitle = rawTitle ?? fallbackTitle;

    if (jobId != null &&
        jobId.isNotEmpty &&
        effectiveTitle != null &&
        effectiveTitle.isNotEmpty) {
      final source = _resolveSource(
        sourceKey: _cleanOptional(data['sourceKey']),
        sourceLabel: _cleanOptional(data['source']),
        jobId: jobId,
        targetUrl: targetUrl,
      );
      final rawDesc = _cleanOptional(data['description']);
      final hasFullDesc = rawDesc != null && rawDesc.isNotEmpty;
      final description = hasFullDesc
          ? rawDesc
          : (_cleanOptional(notificationBody) ?? effectiveTitle);

      final workMode = _resolveWorkMode(
        data['workMode']?.toString(),
        fallbackText: '$effectiveTitle $description',
      );
      final skills = _parseSkills(data['skills']);
      final publishedAt =
          DateTime.tryParse((data['publishedAt'] ?? '').toString()) ??
          DateTime.now();

      final defaultCity =
          source == JobSource.ponisha || source == JobSource.karlancer
              ? 'سراسر ایران (آنلاین)'
              : 'تهران';
      final defaultContract =
          source.tabCategory == JobTabCategory.freelance
              ? 'پروژه‌ای / فریلنسری'
              : 'تمام‌وقت';

      final model = JobModel(
        id: jobId,
        title: effectiveTitle,
        companyOrClient:
            _cleanOptional(data['company'] ?? data['companyOrClient']) ?? '',
        source: source,
        salaryOrBudget:
            _cleanOptional(data['salary'] ?? data['salaryOrBudget']) ??
                'توافقی',
        city: _cleanOptional(data['city']) ?? defaultCity,
        workMode: workMode,
        contractType:
            _cleanOptional(data['contractType']) ?? defaultContract,
        description: description,
        skills: skills,
        publishedTimeText:
            _cleanOptional(data['publishedTimeText']) ?? 'لحظاتی پیش',
        publishedAt: publishedAt,
        originalUrl: targetUrl ?? 'https://${source.domain}',
        proposalsCountText: _cleanOptional(data['proposalsCountText']),
        isUrgent: data['isUrgent'] == true ||
            data['isUrgent']?.toString().toLowerCase() == 'true',
      );

      return NotificationTapPayload(
        jobId: jobId,
        targetUrl: model.originalUrl,
        job: model,
        isPreviewOnly: !hasFullDesc,
      );
    }

    return NotificationTapPayload(
      jobId: jobId,
      targetUrl: targetUrl,
      isPreviewOnly: true,
    );
  }

  static String? _cleanOptional(dynamic value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _cleanNotificationTitle(String? rawTitle) {
    final cleaned = _cleanOptional(rawTitle);
    if (cleaned == null) return null;
    return cleaned
        .replaceFirst(RegExp(r'^🔔\s*'), '')
        .replaceFirst(
          RegExp(r'^(آگهی جدید در|جدیدترین در|آگهی فوری)\s*[^:]+:\s*'),
          '',
        )
        .replaceFirst(
          RegExp(r'^(پونیشا|کارلنسر|جابینجا|جاب‌ویژن|جاب ویژن)\s*:\s*'),
          '',
        )
        .trim();
  }

  static JobSource _resolveSource({
    String? sourceKey,
    String? sourceLabel,
    required String jobId,
    String? targetUrl,
  }) {
    final candidates = [
      sourceKey?.toLowerCase() ?? '',
      sourceLabel?.toLowerCase() ?? '',
      jobId.toLowerCase(),
      targetUrl?.toLowerCase() ?? '',
    ].join(' ');

    if (candidates.contains('ponisha') || candidates.contains('پونیشا')) {
      return JobSource.ponisha;
    }
    if (candidates.contains('karlancer') || candidates.contains('کارلنسر')) {
      return JobSource.karlancer;
    }
    if (candidates.contains('jobvision') ||
        candidates.contains('جاب‌ویژن') ||
        candidates.contains('جاب ویژن')) {
      return JobSource.jobvision;
    }
    return JobSource.jobinja;
  }

  static WorkMode _resolveWorkMode(
    String? rawMode, {
    required String fallbackText,
  }) {
    final combined = '${rawMode ?? ''} $fallbackText'.toLowerCase();
    if (combined.contains('hybrid') ||
        combined.contains('هیبرید') ||
        combined.contains('نیمه حضوری') ||
        combined.contains('نیمه‌حضوری')) {
      return WorkMode.hybrid;
    }
    if (combined.contains('remote') ||
        combined.contains('دورکار') ||
        combined.contains('آنلاین')) {
      return WorkMode.remote;
    }
    return WorkMode.onSite;
  }

  static List<String> _parseSkills(dynamic rawSkills) {
    if (rawSkills == null) return const <String>[];
    if (rawSkills is List) {
      return rawSkills
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .take(5)
          .toList();
    }
    final str = rawSkills.toString().trim();
    if (str.isEmpty) return const <String>[];
    if (str.startsWith('[')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .take(5)
              .toList();
        }
      } catch (_) {}
    }
    return str
        .split(RegExp(r'[,،]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(5)
        .toList();
  }
}
