import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// دسته‌بندی اصلی تب‌های اپلیکیشن
enum JobTabCategory {
  /// پروژه‌های فریلنسری (پونیشا و کارلنسر)
  freelance,

  /// آگهی‌های استخدامی (جابینجا و جاب‌ویژن)
  employment,
}

/// سایت‌های منبع آگهی
enum JobSource {
  ponisha,
  karlancer,
  jobinja,
  jobvision,
}

extension JobSourceExtension on JobSource {
  String get persianName {
    switch (this) {
      case JobSource.ponisha:
        return 'پونیشا';
      case JobSource.karlancer:
        return 'کارلنسر';
      case JobSource.jobinja:
        return 'جابینجا';
      case JobSource.jobvision:
        return 'جاب‌ویژن';
    }
  }

  String get domain {
    switch (this) {
      case JobSource.ponisha:
        return 'ponisha.ir';
      case JobSource.karlancer:
        return 'karlancer.com';
      case JobSource.jobinja:
        return 'jobinja.ir';
      case JobSource.jobvision:
        return 'jobvision.ir';
    }
  }

  JobTabCategory get tabCategory {
    switch (this) {
      case JobSource.ponisha:
      case JobSource.karlancer:
        return JobTabCategory.freelance;
      case JobSource.jobinja:
      case JobSource.jobvision:
        return JobTabCategory.employment;
    }
  }

  Color get brandColor {
    switch (this) {
      case JobSource.ponisha:
        return const Color(0xFF00A693);
      case JobSource.karlancer:
        return const Color(0xFF2563EB);
      case JobSource.jobinja:
        return const Color(0xFF10B981);
      case JobSource.jobvision:
        return const Color(0xFF6366F1);
    }
  }

  IconData get icon {
    switch (this) {
      case JobSource.ponisha:
        return Icons.laptop_mac_rounded;
      case JobSource.karlancer:
        return Icons.rocket_launch_rounded;
      case JobSource.jobinja:
        return Icons.business_center_rounded;
      case JobSource.jobvision:
        return Icons.apartment_rounded;
    }
  }
}

/// وضعیت دورکاری یا حضوری بودن آگهی
enum WorkMode {
  remote,
  hybrid,
  onSite,
}

extension WorkModeExtension on WorkMode {
  String get label {
    switch (this) {
      case WorkMode.remote:
        return 'دورکاری (Remote)';
      case WorkMode.hybrid:
        return 'هیبرید (نیمه‌حضوری)';
      case WorkMode.onSite:
        return 'حضوری';
    }
  }

  Color get badgeColor {
    switch (this) {
      case WorkMode.remote:
        return const Color(0xFF059669);
      case WorkMode.hybrid:
        return const Color(0xFFD97706);
      case WorkMode.onSite:
        return const Color(0xFF475569);
    }
  }

  IconData get icon {
    switch (this) {
      case WorkMode.remote:
        return Icons.home_work_rounded;
      case WorkMode.hybrid:
        return Icons.sync_alt_rounded;
      case WorkMode.onSite:
        return Icons.location_city_rounded;
    }
  }
}

/// فیلتر تخصص (فلاتر، اندروید)
enum JobRoleFilter {
  all,
  flutter,
  android,
}

extension JobRoleFilterExtension on JobRoleFilter {
  String get title {
    switch (this) {
      case JobRoleFilter.all:
        return 'همه تخصص‌ها';
      case JobRoleFilter.flutter:
        return 'فلاتر دولوپر (Flutter)';
      case JobRoleFilter.android:
        return 'توسعه‌دهنده اندروید';
    }
  }

  Color? get dotColor {
    switch (this) {
      case JobRoleFilter.all:
        return null;
      case JobRoleFilter.flutter:
        return const Color(0xFF0284C7);
      case JobRoleFilter.android:
        return const Color(0xFF16A34A);
    }
  }
}

/// موجودیت دامنه (Domain Entity) برای هر آگهی شغلی یا پروژه فریلنسری
class JobEntity extends Equatable {
  final String id;
  final String title;
  final String companyOrClient;
  final JobSource source;
  final String salaryOrBudget;
  final String city;
  final WorkMode workMode;
  final String contractType;
  final String description;
  final List<String> skills;
  final String publishedTimeText;
  final DateTime publishedAt;
  final String originalUrl;
  final String? proposalsCountText;
  final bool isUrgent;

  const JobEntity({
    required this.id,
    required this.title,
    required this.companyOrClient,
    required this.source,
    required this.salaryOrBudget,
    required this.city,
    required this.workMode,
    required this.contractType,
    required this.description,
    required this.skills,
    required this.publishedTimeText,
    required this.publishedAt,
    required this.originalUrl,
    this.proposalsCountText,
    this.isUrgent = false,
  });

  JobTabCategory get tabCategory => source.tabCategory;

  bool get isRemote =>
      workMode == WorkMode.remote || workMode == WorkMode.hybrid;

  bool get hasDisplayableCompanyOrClient {
    final trimmed = companyOrClient.trim();
    if (trimmed.isEmpty) return false;
    if (source == JobSource.ponisha || source == JobSource.karlancer) {
      return false;
    }
    if (trimmed.startsWith('کارفرما در')) return false;
    return true;
  }

  String get appDeepLink =>
      'jobradar://job?id=${Uri.encodeComponent(id)}&url=${Uri.encodeComponent(originalUrl)}';

  bool matchesRoleFilter(JobRoleFilter filter) {
    if (filter == JobRoleFilter.all) return true;
    final combined =
        '${title.toLowerCase()} ${description.toLowerCase()} ${skills.join(' ').toLowerCase()}';
    switch (filter) {
      case JobRoleFilter.flutter:
        return combined.contains('flutter') ||
            combined.contains('فلاتر') ||
            combined.contains('dart') ||
            combined.contains('دارت');
      case JobRoleFilter.android:
        return combined.contains('android') ||
            combined.contains('اندروید') ||
            combined.contains('kotlin') ||
            combined.contains('کاتلین') ||
            combined.contains('java');
      case JobRoleFilter.all:
        return true;
    }
  }

  @override
  List<Object?> get props => [
        id,
        title,
        companyOrClient,
        source,
        salaryOrBudget,
        city,
        workMode,
        contractType,
        description,
        skills,
        publishedTimeText,
        publishedAt,
        originalUrl,
        proposalsCountText,
        isUrgent,
      ];
}
