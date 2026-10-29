import '../entities/job_entity.dart';
import '../entities/scrape_summary_entity.dart';

abstract class JobRepository {
  /// دریافت آگهی‌های کش‌شده در حافظه محلی (SharedPreferences)
  Future<List<JobEntity>> getCachedJobs();

  /// دریافت لیست شناسه‌های آگهی‌های نشان‌شده (Bookmarked)
  Future<Set<String>> getBookmarkedIds();

  /// تغییر وضعیت نشان کردن یک آگهی و بازگرداندن مجموعه جدید
  Future<Set<String>> toggleBookmark(String jobId);

  /// اسکرپ همزمان ۴ سایت، ذخیره در کش، و ارسال نوتیفیکیشن برای آگهی‌های جدید غیرتکراری
  Future<ScrapeSummaryEntity> scrapeAndSyncJobs({
    String? customQuery,
    bool isBackgroundCheck = false,
  });
}
