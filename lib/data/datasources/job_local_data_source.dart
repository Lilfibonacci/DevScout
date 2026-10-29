import 'dart:convert';
import 'dart:isolate';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/job_model.dart';

abstract class JobLocalDataSource {
  Future<List<JobModel>> getCachedJobs();
  Future<void> cacheJobs(List<JobModel> jobs);

  Future<Set<String>> getBookmarkedIds();
  Future<Set<String>> toggleBookmark(String jobId);

  Set<String> getSeenJobIds();
  Future<void> saveSeenJobIds(Set<String> ids);

  Set<String> getNotifiedJobIds();
  Future<void> saveNotifiedJobIds(Set<String> ids);

  bool getBoolSetting(String key, {bool defaultValue = true});
  Future<void> setBoolSetting(String key, bool value);
}

class JobLocalDataSourceImpl implements JobLocalDataSource {
  final SharedPreferences sharedPreferences;
  final bool useWorkerIsolate;

  static const String cachedJobsKey = 'cached_jobs_json';
  static const String bookmarkedIdsKey = 'bookmarked_job_ids';
  static const String seenJobIdsKey = 'seen_job_ids';
  static const String notifiedJobIdsKey = 'notified_job_ids';

  const JobLocalDataSourceImpl({
    required this.sharedPreferences,
    this.useWorkerIsolate = true,
  });

  @override
  Future<List<JobModel>> getCachedJobs() async {
    final jsonStr = sharedPreferences.getString(cachedJobsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      if (useWorkerIsolate) {
        return await Isolate.run(() => _decodeCachedJobs(jsonStr));
      }
      return _decodeCachedJobs(jsonStr);
    } catch (_) {
      return [];
    }
  }

  static List<JobModel> _decodeCachedJobs(String jsonStr) {
    final decoded = jsonDecode(jsonStr) as List<dynamic>;
    final models = decoded
        .map((e) => JobModel.fromJson(e as Map<String, dynamic>))
        .where((job) => !RegExp(r'_(fl|an|app)_\d{3}$').hasMatch(job.id))
        .toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return models;
  }

  @override
  Future<void> cacheJobs(List<JobModel> jobs) async {
    final String encoded;
    if (useWorkerIsolate) {
      encoded = await Isolate.run(() => _encodeJobsForCache(jobs));
    } else {
      encoded = _encodeJobsForCache(jobs);
    }
    await sharedPreferences.setString(cachedJobsKey, encoded);
    await sharedPreferences.setString(
      'last_background_scrape_time',
      DateTime.now().toIso8601String(),
    );
  }

  static String _encodeJobsForCache(List<JobModel> jobs) {
    final sorted = List<JobModel>.from(jobs)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return jsonEncode(sorted.map((e) => e.toJson()).toList());
  }

  @override
  Future<Set<String>> getBookmarkedIds() async {
    final list = sharedPreferences.getStringList(bookmarkedIdsKey) ?? [];
    return list.toSet();
  }

  @override
  Future<Set<String>> toggleBookmark(String jobId) async {
    final current = await getBookmarkedIds();
    if (current.contains(jobId)) {
      current.remove(jobId);
    } else {
      current.add(jobId);
    }
    await sharedPreferences.setStringList(bookmarkedIdsKey, current.toList());
    return current;
  }

  @override
  Set<String> getSeenJobIds() {
    return (sharedPreferences.getStringList(seenJobIdsKey) ?? []).toSet();
  }

  @override
  Future<void> saveSeenJobIds(Set<String> ids) async {
    await sharedPreferences.setStringList(seenJobIdsKey, ids.toList());
  }

  @override
  Set<String> getNotifiedJobIds() {
    return (sharedPreferences.getStringList(notifiedJobIdsKey) ?? []).toSet();
  }

  @override
  Future<void> saveNotifiedJobIds(Set<String> ids) async {
    await sharedPreferences.setStringList(notifiedJobIdsKey, ids.toList());
  }

  @override
  bool getBoolSetting(String key, {bool defaultValue = true}) {
    return sharedPreferences.getBool(key) ?? defaultValue;
  }

  @override
  Future<void> setBoolSetting(String key, bool value) async {
    await sharedPreferences.setBool(key, value);
  }
}
