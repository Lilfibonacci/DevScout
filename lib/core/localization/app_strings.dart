import 'package:flutter/material.dart';
import '../../domain/entities/job_entity.dart';

class AppStrings {
  final Locale locale;

  const AppStrings(this.locale);

  bool get isFa => locale.languageCode == 'fa';

  static AppStrings of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return AppStrings(locale);
  }

  String get appName => 'DevScout';

  String get appTagline => isFa
      ? 'جستجوگر یکپارچه فرصت‌های فلاتر و اندروید'
      : 'Flutter & Android Opportunity Aggregator';

  String get freelanceTab =>
      isFa ? 'پروژه‌های فریلنسری' : 'Freelance Projects';

  String get employmentTab =>
      isFa ? 'آگهی‌های استخدامی' : 'Full-time & Jobs';

  String get searchHint => isFa
      ? 'جستجوی عنوان، شرکت، مهارت یا شهر...'
      : 'Search title, company, skill or city...';

  String get allSources => isFa ? 'همه منابع' : 'All Sources';
  String get remoteOnly => isFa ? 'دورکاری' : 'Remote';
  String get bookmarkedOnly => isFa ? 'ذخیره‌شده' : 'Saved';
  String get clearFilters => isFa ? 'بازنشانی فیلترها' : 'Reset filters';
  String get noResults => isFa
      ? 'موردی با این فیلترها یافت نشد.'
      : 'No listings match the selected filters.';
  String get loadingJobs => isFa
      ? 'در حال دریافت جدیدترین آگهی‌ها...'
      : 'Fetching latest listings...';

  String get drawerAppearance => isFa ? 'ظاهر برنامه' : 'Appearance';
  String get darkMode => isFa ? 'حالت تیره' : 'Dark Mode';
  String get lightMode => isFa ? 'حالت روشن' : 'Light Mode';
  String get drawerLanguage => isFa ? 'زبان برنامه' : 'Language';
  String get notificationsMenu =>
      isFa ? 'تنظیمات نوتیفیکیشن و پس‌زمینه' : 'Notifications & Background Sync';
  String get notificationsSubtitle => isFa
      ? 'مدیریت اعلان‌های آنی و بررسی خودکار'
      : 'Manage alerts and background worker';
  String get savedJobsMenu =>
      isFa ? 'فقط آگهی‌های ذخیره‌شده' : 'Show Saved Listings Only';
  String get directPortalsHeader =>
      isFa ? 'باز کردن مستقیم پلتفرم‌ها' : 'Direct Portal Shortcuts';

  String get viewInSource =>
      isFa ? 'مشاهده در سایت مرجع' : 'Open Original Listing';
  String get jobDetailsTitle =>
      isFa ? 'جزئیات موقعیت شغلی' : 'Listing Details';
  String get compensationLabel =>
      isFa ? 'حقوق / بودجه' : 'Compensation';
  String get locationLabel => isFa ? 'موقعیت مکانی' : 'Location';
  String get workModeLabel => isFa ? 'نحوه همکاری' : 'Work Mode';
  String get contractLabel => isFa ? 'نوع قرارداد' : 'Contract';
  String get descriptionHeader => isFa ? 'توضیحات' : 'Description';
  String get skillsHeader => isFa ? 'مهارت‌ها' : 'Skills & Stack';
  String get copyLink => isFa ? 'کپی لینک' : 'Copy Link';
  String get linkCopied =>
      isFa ? 'لینک آگهی کپی شد.' : 'Listing URL copied.';

  String sourceName(JobSource source) {
    if (isFa) return source.persianName;
    switch (source) {
      case JobSource.ponisha:
        return 'Ponisha';
      case JobSource.karlancer:
        return 'Karlancer';
      case JobSource.jobinja:
        return 'Jobinja';
      case JobSource.jobvision:
        return 'JobVision';
    }
  }

  String roleFilterTitle(JobRoleFilter filter) {
    if (isFa) {
      switch (filter) {
        case JobRoleFilter.all:
          return 'همه';
        case JobRoleFilter.flutter:
          return 'فلاتر (Flutter)';
        case JobRoleFilter.android:
          return 'اندروید (Android)';
      }
    } else {
      switch (filter) {
        case JobRoleFilter.all:
          return 'All';
        case JobRoleFilter.flutter:
          return 'Flutter';
        case JobRoleFilter.android:
          return 'Android';
      }
    }
  }

  String workModeText(WorkMode mode) {
    if (isFa) {
      switch (mode) {
        case WorkMode.remote:
          return 'دورکاری';
        case WorkMode.hybrid:
          return 'هیبرید';
        case WorkMode.onSite:
          return 'حضوری';
      }
    } else {
      switch (mode) {
        case WorkMode.remote:
          return 'Remote';
        case WorkMode.hybrid:
          return 'Hybrid';
        case WorkMode.onSite:
          return 'On-site';
      }
    }
  }
}
