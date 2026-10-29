import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/job_entity.dart';
import '../../domain/entities/scrape_summary_entity.dart';
import '../models/job_model.dart';

class RemoteScrapeOutput {
  final List<JobModel> jobs;
  final Map<JobSource, SourceScrapeStatusEntity> sourceStatuses;
  final DateTime fetchedAt;

  const RemoteScrapeOutput({
    required this.jobs,
    required this.sourceStatuses,
    required this.fetchedAt,
  });
}

abstract class JobRemoteDataSource {
  Future<RemoteScrapeOutput> scrapeAllSources({String? customQuery});
}

class JobRemoteDataSourceImpl implements JobRemoteDataSource {
  final http.Client _client;
  final bool _useWorkerIsolate;
  final NumberFormat _numberFormat = NumberFormat.decimalPattern('fa');

  JobRemoteDataSourceImpl({http.Client? client, bool? useWorkerIsolate})
      : _useWorkerIsolate = useWorkerIsolate ?? (client == null),
        _client = client ?? _createResilientHttpClient();

  JobRemoteDataSourceImpl._internalWorker()
      : _useWorkerIsolate = false,
        _client = _createResilientHttpClient();

  static http.Client _createResilientHttpClient() {
    final ioHttpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    return IOClient(ioHttpClient);
  }

  static const Map<String, String> _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,application/json,*/*;q=0.8',
    'Accept-Language': 'fa-IR,fa;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  static const List<String> _mobileKeywords = [
    'flutter',
    'فلاتر',
    'dart',
    'دارت',
    'android',
    'اندروید',
    'kotlin',
    'کاتلین',
    'mobile',
    'موبایل',
    'اپلیکیشن',
    'ساخت اپ',
    'توسعه اپ',
    'react native',
    'ری اکت نیتیو',
    'ios',
  ];

  @override
  Future<RemoteScrapeOutput> scrapeAllSources({String? customQuery}) async {
    if (_useWorkerIsolate) {
      return Isolate.run(() => _scrapeInWorkerIsolate(customQuery));
    }
    return _scrapeAllInternal(customQuery: customQuery);
  }

  static Future<RemoteScrapeOutput> _scrapeInWorkerIsolate(
    String? customQuery,
  ) async {
    final worker = JobRemoteDataSourceImpl._internalWorker();
    try {
      return await worker._scrapeAllInternal(customQuery: customQuery);
    } finally {
      worker._client.close();
    }
  }

  Future<RemoteScrapeOutput> _scrapeAllInternal({String? customQuery}) async {
    final results = await Future.wait([
      _scrapePonisha(customQuery: customQuery),
      _scrapeKarlancer(customQuery: customQuery),
      _scrapeJobinja(customQuery: customQuery),
      _scrapeJobVision(customQuery: customQuery),
    ]);

    final statuses = <JobSource, SourceScrapeStatusEntity>{};
    for (final res in results) {
      statuses[res.$2.source] = res.$2;
    }

    final allJobs = <JobModel>[
      ...results[0].$1,
      ...results[1].$1,
      ...results[2].$1,
      ...results[3].$1,
    ];

    // مرتب‌سازی دقیق بر اساس جدیدترین آگهی‌ها در صدر لیست
    allJobs.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return RemoteScrapeOutput(
      jobs: allJobs,
      sourceStatuses: statuses,
      fetchedAt: DateTime.now(),
    );
  }

  // ===========================================================================
  // ۱. پونیشا (Ponisha.ir)
  // ===========================================================================
  Future<(List<JobModel>, SourceScrapeStatusEntity)> _scrapePonisha({
    String? customQuery,
  }) async {
    final scraped = <JobModel>[];
    final queries = <String>[
      if (customQuery != null && customQuery.trim().isNotEmpty)
        customQuery.trim(),
      'flutter',
      'android',
      'اپلیکیشن موبایل',
    ];

    try {
      for (final q in queries.take(3)) {
        final url =
            'https://ponisha.ir/search/projects?query=${Uri.encodeComponent(q)}';
        final response = await _client
            .get(Uri.parse(url), headers: _browserHeaders)
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final htmlStr = utf8.decode(response.bodyBytes, allowMalformed: true);
          final document = html_parser.parse(htmlStr);
          final nextDataEl = document.querySelector('script#__NEXT_DATA__');

          if (nextDataEl != null && nextDataEl.text.isNotEmpty) {
            final parsed = _parsePonishaNextJson(nextDataEl.text);
            for (final item in parsed) {
              if (!scraped.any((e) => e.id == item.id)) {
                scraped.add(item);
              }
            }
          }
        }
      }
    } catch (_) {}

    if (scraped.isNotEmpty) {
      return (
        scraped,
        SourceScrapeStatusEntity(
          source: JobSource.ponisha,
          isLiveScraped: true,
          count: scraped.length,
          statusMessage: 'زنده از پونیشا (${scraped.length} پروژه واقعی)',
        ),
      );
    }

    return (
      const <JobModel>[],
      const SourceScrapeStatusEntity(
        source: JobSource.ponisha,
        isLiveScraped: false,
        count: 0,
        statusMessage: 'خطا در اتصال به پونیشا',
      ),
    );
  }

  List<JobModel> _parsePonishaNextJson(String jsonText) {
    final items = <JobModel>[];
    try {
      final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
      final queries = decoded['props']?['pageProps']?['dehydratedState']
          ?['queries'] as List<dynamic>?;

      if (queries == null) return items;

      for (final q in queries) {
        final stateData = q['state']?['data'];
        if (stateData is Map<String, dynamic> && stateData['data'] is List) {
          final projectList = stateData['data'] as List<dynamic>;
          for (final raw in projectList) {
            if (raw is! Map<String, dynamic>) continue;

            final id = (raw['id'] ?? '').toString();
            final title = _cleanText((raw['title'] ?? '').toString());
            final slug = (raw['slug'] ?? '').toString();
            final description =
                _cleanText((raw['description'] ?? title).toString());

            if (id.isEmpty || title.isEmpty) continue;

            final skillsList = <String>[];
            if (raw['skills'] is List) {
              for (final s in (raw['skills'] as List)) {
                if (s is Map && s['title'] != null) {
                  skillsList.add(s['title'].toString());
                }
              }
            }

            final minAmount = raw['amount_min'];
            final maxAmount = raw['amount_max'];
            String budget = 'بودجه توافقی';
            if (minAmount is num && maxAmount is num && maxAmount > 0) {
              budget =
                  '${_formatMoney(minAmount)} تا ${_formatMoney(maxAmount)} تومان';
            }

            final bidsCount = raw['project_bids_count'];
            final bidsText =
                bidsCount != null ? '$bidsCount پیشنهاد ثبت شده' : null;

            final approvedMs = raw['approved_at'];
            DateTime publishedAt = DateTime.now();
            if (approvedMs is int && approvedMs > 0) {
              publishedAt = DateTime.fromMillisecondsSinceEpoch(approvedMs);
            }

            final encodedSlug = Uri.encodeComponent(slug);
            final originalUrl = slug.isNotEmpty
                ? 'https://ponisha.ir/project/$id/$encodedSlug'
                : 'https://ponisha.ir/project/$id';

            items.add(
              JobModel(
                id: 'ponisha_$id',
                title: title,
                companyOrClient: '',
                source: JobSource.ponisha,
                salaryOrBudget: budget,
                city: 'سراسر ایران (آنلاین)',
                workMode: WorkMode.remote,
                contractType: 'پروژه‌ای / فریلنسری',
                description: description,
                skills: skillsList.isNotEmpty
                    ? skillsList.take(5).toList()
                    : _detectSkills('$title $description'),
                publishedTimeText: _relativeTimeFa(publishedAt),
                publishedAt: publishedAt,
                originalUrl: originalUrl,
                proposalsCountText: bidsText,
                isUrgent: (raw['promotions'] is List) &&
                    (raw['promotions'] as List).isNotEmpty,
              ),
            );
          }
        }
      }
    } catch (_) {}
    return items;
  }

  // ===========================================================================
  // ۲. کارلنسر (Karlancer.com)
  // ===========================================================================
  Future<(List<JobModel>, SourceScrapeStatusEntity)> _scrapeKarlancer({
    String? customQuery,
  }) async {
    final scraped = <JobModel>[];
    final queries = <String>[
      if (customQuery != null && customQuery.trim().isNotEmpty)
        customQuery.trim(),
      'flutter',
      'اندروید',
    ];

    try {
      final responses = await Future.wait(
        queries.take(2).map((q) {
          final url =
              'https://www.karlancer.com/search?q=${Uri.encodeComponent(q)}';
          return _client
              .get(Uri.parse(url), headers: _browserHeaders)
              .timeout(const Duration(seconds: 20));
        }),
      );

      for (final response in responses) {
        if (response.statusCode == 200) {
          final htmlStr = utf8.decode(response.bodyBytes, allowMalformed: true);
          final document = html_parser.parse(htmlStr);
          final ngStateEl = document.querySelector('script#ng-state');

          if (ngStateEl != null && ngStateEl.text.isNotEmpty) {
            final parsed = _parseKarlancerNgState(ngStateEl.text);
            for (final item in parsed) {
              if (!scraped.any((e) => e.id == item.id)) {
                scraped.add(item);
              }
            }
          }
        }
      }
    } catch (_) {}

    if (scraped.isNotEmpty) {
      return (
        scraped,
        SourceScrapeStatusEntity(
          source: JobSource.karlancer,
          isLiveScraped: true,
          count: scraped.length,
          statusMessage: 'زنده از کارلنسر (${scraped.length} پروژه واقعی)',
        ),
      );
    }

    return (
      const <JobModel>[],
      const SourceScrapeStatusEntity(
        source: JobSource.karlancer,
        isLiveScraped: false,
        count: 0,
        statusMessage: 'خطا در اتصال به کارلنسر',
      ),
    );
  }

  List<JobModel> _parseKarlancerNgState(String jsonText) {
    final items = <JobModel>[];
    try {
      final decoded = jsonDecode(jsonText) as Map<String, dynamic>;

      for (final entry in decoded.entries) {
        if (entry.key == '__nghData__') continue;
        final val = entry.value;
        if (val is! Map<String, dynamic>) continue;

        final projectsObj = val['b']?['data']?['projects'];
        if (projectsObj is Map<String, dynamic> &&
            projectsObj['data'] is List) {
          final projectList = projectsObj['data'] as List<dynamic>;

          for (final raw in projectList) {
            if (raw is! Map<String, dynamic>) continue;
            if (raw['is_expired'] == true) continue;

            final id = (raw['id'] ?? '').toString();
            final title = _cleanText((raw['title'] ?? '').toString());
            final description =
                _cleanText((raw['description'] ?? title).toString());
            if (id.isEmpty || title.isEmpty) continue;

            final minB = raw['min_budget'];
            final maxB = raw['max_budget'];
            String budget = 'توافقی';
            if (minB is num && maxB is num && maxB > 0) {
              budget = '${_formatMoney(minB)} تا ${_formatMoney(maxB)} تومان';
            }

            final city = (raw['country'] ?? 'سراسر ایران').toString().trim();
            final isOnsite = raw['is_onsite'] == true;
            final isFulltime = raw['is_fulltime'] == true;
            final workMode = isOnsite ? WorkMode.onSite : WorkMode.remote;

            final skillsList = <String>[];
            if (raw['skills'] is List) {
              for (final s in (raw['skills'] as List)) {
                if (s is Map && s['name'] != null) {
                  skillsList.add(s['name'].toString());
                }
              }
            }

            final pastTime = (raw['past_time'] ?? 'جدید').toString();
            final ladderAt =
                DateTime.tryParse((raw['ladder_at'] ?? '').toString()) ??
                    DateTime.now();

            final slugUrl = (raw['url'] ?? '').toString();
            final originalUrl = slugUrl.isNotEmpty
                ? 'https://www.karlancer.com/projects/${Uri.encodeComponent(slugUrl)}'
                : 'https://www.karlancer.com/search?q=flutter';

            items.add(
              JobModel(
                id: 'karlancer_$id',
                title: title,
                companyOrClient: '',
                source: JobSource.karlancer,
                salaryOrBudget: budget,
                city: city.isNotEmpty ? city : 'سراسر ایران',
                workMode: workMode,
                contractType:
                    isFulltime ? 'پروژه‌ای / تمام‌وقت' : 'پروژه‌ای / فریلنسری',
                description: description,
                skills: skillsList.isNotEmpty
                    ? skillsList.take(5).toList()
                    : _detectSkills('$title $description'),
                publishedTimeText: pastTime,
                publishedAt: ladderAt,
                originalUrl: originalUrl,
                proposalsCountText: raw['job_duration'] != null
                    ? 'مهلت انجام: ${raw['job_duration']} روز'
                    : null,
                isUrgent: raw['is_urgent'] == true || raw['is_highlight'] == true,
              ),
            );
          }
        }
      }
    } catch (_) {}
    return items;
  }

  // ===========================================================================
  // ۳. جابینجا (Jobinja.ir)
  // ===========================================================================
  Future<(List<JobModel>, SourceScrapeStatusEntity)> _scrapeJobinja({
    String? customQuery,
  }) async {
    final scraped = <JobModel>[];
    final keywords = <String>[
      if (customQuery != null && customQuery.trim().isNotEmpty)
        customQuery.trim(),
      'flutter',
      'android',
      'فلاتر',
    ];

    try {
      for (final kw in keywords.take(3)) {
        final url =
            'https://jobinja.ir/jobs?filters%5Bkeywords%5D%5B0%5D=${Uri.encodeComponent(kw)}&sort_by=published_at_desc';
        final response = await _client
            .get(Uri.parse(url), headers: _browserHeaders)
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final htmlStr = utf8.decode(response.bodyBytes, allowMalformed: true);
          final document = html_parser.parse(htmlStr);
          final jobItems = document.querySelectorAll(
            '.o-listView__item, .c-jobListView__item',
          );

          for (final item in jobItems) {
            final titleLink = item.querySelector('a.c-jobListView__titleLink');
            if (titleLink == null) continue;

            final rawTitle = _cleanText(titleLink.text);
            final passedTime = _cleanText(
              item.querySelector('.c-jobListView__passedDays')?.text ?? 'امروز',
            );
            final title = rawTitle.replaceAll(passedTime, '').trim();
            final href = titleLink.attributes['href'] ?? '';
            if (title.isEmpty || href.isEmpty) continue;

            final metaItems = item
                .querySelectorAll('.c-jobListView__metaItem')
                .map((dom.Element e) => _cleanText(e.text))
                .where((s) => s.isNotEmpty)
                .toList();

            final company = metaItems.isNotEmpty ? metaItems[0] : 'شرکت معتبر';
            final city = metaItems.length > 1 ? metaItems[1] : 'تهران';
            final contractRaw =
                metaItems.length > 2 ? metaItems[2] : 'تمام‌وقت';

            final workMode = _detectWorkMode('$title $city $contractRaw');
            final salary = _extractSalaryFromJobinja(contractRaw);
            final cleanHref = href.split('?').first;
            final id = 'jobinja_${cleanHref.hashCode.abs()}';
            final cleanPassed =
                passedTime.replaceAll('(', '').replaceAll(')', '').trim();

            if (!scraped.any((e) => e.id == id)) {
              scraped.add(
                JobModel(
                  id: id,
                  title: title,
                  companyOrClient: company,
                  source: JobSource.jobinja,
                  salaryOrBudget: salary,
                  city: city,
                  workMode: workMode,
                  contractType: _extractContractType(contractRaw),
                  description:
                      'آگهی استخدام «$title» در شرکت «$company» واقع در $city.\nجزئیات قرارداد و حقوق: $contractRaw\nبرای مشاهده شرح کامل وظایف و ارسال مستقیم رزومه، دکمه مشاهده در جابینجا را لمس کنید.',
                  skills: _detectSkills('$title $contractRaw'),
                  publishedTimeText: cleanPassed,
                  publishedAt: _parsePersianRelativeDate(
                    cleanPassed,
                    indexOffset: scraped.length,
                  ),
                  originalUrl:
                      href.startsWith('http') ? href : 'https://jobinja.ir$href',
                  isUrgent: item.text.contains('فوری'),
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    if (scraped.isNotEmpty) {
      return (
        scraped,
        SourceScrapeStatusEntity(
          source: JobSource.jobinja,
          isLiveScraped: true,
          count: scraped.length,
          statusMessage: 'زنده از جابینجا (${scraped.length} آگهی واقعی)',
        ),
      );
    }

    return (
      const <JobModel>[],
      const SourceScrapeStatusEntity(
        source: JobSource.jobinja,
        isLiveScraped: false,
        count: 0,
        statusMessage: 'خطا در اتصال به جابینجا',
      ),
    );
  }

  // ===========================================================================
  // ۴. جاب‌ویژن (JobVision.ir)
  // ===========================================================================
  Future<(List<JobModel>, SourceScrapeStatusEntity)> _scrapeJobVision({
    String? customQuery,
  }) async {
    final scraped = <JobModel>[];
    final keywords = <String>[
      if (customQuery != null && customQuery.trim().isNotEmpty)
        customQuery.trim(),
      'flutter',
      'اندروید',
      'android',
    ];

    try {
      for (final kw in keywords.take(3)) {
        final response = await _client
            .post(
              Uri.parse('https://candidateapi.jobvision.ir/api/v1/JobPost/List'),
              headers: {
                ..._browserHeaders,
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Origin': 'https://jobvision.ir',
                'Referer': 'https://jobvision.ir/',
              },
              body: jsonEncode({
                'page': 1,
                'pageSize': 30,
                'keyword': kw,
                'sortBy': 0,
              }),
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final jsonStr = utf8.decode(response.bodyBytes, allowMalformed: true);
          final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
          final jobPosts = decoded['data']?['jobPosts'] as List<dynamic>?;

          if (jobPosts != null) {
            for (final raw in jobPosts) {
              if (raw is! Map<String, dynamic>) continue;

              final id = (raw['id'] ?? '').toString();
              final title = _cleanText((raw['title'] ?? '').toString());
              if (id.isEmpty || title.isEmpty) continue;

              if (customQuery == null && !_isMobileOrAppTitle(title)) {
                continue;
              }

              final companyObj = raw['company'];
              final company = (companyObj is Map
                      ? (companyObj['nameFa'] ?? companyObj['nameEn'])
                      : null)
                  ?.toString() ??
                  'شرکت معتبر در جاب‌ویژن';

              final locObj = raw['location'];
              String cityFa = 'تهران';
              String? regionFa;
              if (locObj is Map) {
                final cityMap = locObj['city'];
                final provMap = locObj['province'];
                final regMap = locObj['region'];
                if (cityMap is Map && cityMap['titleFa'] != null) {
                  cityFa = cityMap['titleFa'].toString();
                } else if (provMap is Map && provMap['titleFa'] != null) {
                  cityFa = provMap['titleFa'].toString();
                }
                if (regMap is Map && regMap['titleFa'] != null) {
                  regionFa = regMap['titleFa'].toString();
                }
              }
              final fullCity = (regionFa != null && regionFa.isNotEmpty)
                  ? '$cityFa ($regionFa)'
                  : cityFa;

              final props = raw['properties'];
              final isRemote = props is Map && props['isRemote'] == true;
              final isUrgent = props is Map && props['isUrgent'] == true;
              final expYears =
                  props is Map ? props['requiredRelatedExperienceYears'] : null;

              final workTypeObj = raw['workType'];
              final workTypeFa = (workTypeObj is Map
                      ? workTypeObj['titleFa']
                      : null)
                  ?.toString() ??
                  'تمام‌وقت';

              final seniorityObj = raw['seniorityLevel'];
              final seniorityFa = (seniorityObj is Map
                      ? seniorityObj['titleFa']
                      : null)
                  ?.toString() ??
                  '';

              String salaryText = 'توافقی';
              final salaryObj = raw['salary'];
              if (salaryObj is Map && salaryObj['titleFa'] != null) {
                salaryText = salaryObj['titleFa'].toString();
              } else if (salaryObj is String && salaryObj.isNotEmpty) {
                salaryText = salaryObj;
              }

              final workMode = isRemote
                  ? WorkMode.remote
                  : _detectWorkMode('$title $workTypeFa');

              final activationObj = raw['activationTime'];
              final beautifyTime = (activationObj is Map
                      ? activationObj['beautifyFa']
                      : null)
                  ?.toString() ??
                  'جدید';
              final publishedAt = (activationObj is Map &&
                      activationObj['date'] != null)
                  ? (DateTime.tryParse(activationObj['date'].toString()) ??
                      DateTime.now())
                  : DateTime.now();

              final industryObj = raw['industry'];
              final industryFa = (industryObj is Map
                      ? industryObj['titleFa']
                      : null)
                  ?.toString() ??
                  'فناوری اطلاعات و نرم‌افزار';

              final descBuffer = StringBuffer()
                ..writeln('استخدام $title در «$company»')
                ..writeln(
                    '• سطح ارشدیت: ${seniorityFa.isNotEmpty ? seniorityFa : "کارشناس"}')
                ..writeln(
                    '• نوع همکاری: $workTypeFa ${isRemote ? "(امکان دورکاری)" : ""}')
                ..writeln('• حوزه فعالیت شرکت: $industryFa');
              if (expYears is num && expYears > 0) {
                descBuffer
                    .writeln('• سابقه کار مرتبط مورد نیاز: حداقل $expYears سال');
              }

              final jobId = 'jobvision_$id';
              if (!scraped.any((e) => e.id == jobId)) {
                scraped.add(
                  JobModel(
                    id: jobId,
                    title: title,
                    companyOrClient: company,
                    source: JobSource.jobvision,
                    salaryOrBudget: salaryText,
                    city: fullCity,
                    workMode: workMode,
                    contractType: seniorityFa.isNotEmpty
                        ? '$workTypeFa ($seniorityFa)'
                        : workTypeFa,
                    description: descBuffer.toString().trim(),
                    skills: _detectSkills('$title $seniorityFa'),
                    publishedTimeText: beautifyTime,
                    publishedAt: publishedAt,
                    originalUrl: 'https://jobvision.ir/jobs/$id',
                    isUrgent: isUrgent,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (_) {}

    if (scraped.isNotEmpty) {
      return (
        scraped,
        SourceScrapeStatusEntity(
          source: JobSource.jobvision,
          isLiveScraped: true,
          count: scraped.length,
          statusMessage: 'زنده از جاب‌ویژن (${scraped.length} آگهی واقعی)',
        ),
      );
    }

    return (
      const <JobModel>[],
      const SourceScrapeStatusEntity(
        source: JobSource.jobvision,
        isLiveScraped: false,
        count: 0,
        statusMessage: 'خطا در اتصال به جاب‌ویژن',
      ),
    );
  }

  bool _isMobileOrAppTitle(String title) {
    final lower = title.toLowerCase();
    return _mobileKeywords.any((kw) => lower.contains(kw));
  }

  DateTime _parsePersianRelativeDate(String text, {int indexOffset = 0}) {
    final normalized = text
        .replaceAll('۰', '0')
        .replaceAll('۱', '1')
        .replaceAll('۲', '2')
        .replaceAll('۳', '3')
        .replaceAll('۴', '4')
        .replaceAll('۵', '5')
        .replaceAll('۶', '6')
        .replaceAll('۷', '7')
        .replaceAll('۸', '8')
        .replaceAll('۹', '9');
    if (normalized.contains('امروز')) {
      return DateTime.now()
          .subtract(Duration(hours: 1, minutes: indexOffset * 4));
    }
    if (normalized.contains('دیروز')) {
      return DateTime.now()
          .subtract(Duration(days: 1, minutes: indexOffset * 4));
    }
    final hoursMatch = RegExp(r'(\d+)\s*ساعت').firstMatch(normalized);
    if (hoursMatch != null) {
      final h = int.tryParse(hoursMatch.group(1)!) ?? 2;
      return DateTime.now().subtract(Duration(hours: h, minutes: indexOffset));
    }
    final minsMatch = RegExp(r'(\d+)\s*دقیقه').firstMatch(normalized);
    if (minsMatch != null) {
      final m = int.tryParse(minsMatch.group(1)!) ?? 10;
      return DateTime.now().subtract(Duration(minutes: m));
    }
    final daysMatch = RegExp(r'(\d+)\s*روز').firstMatch(normalized);
    if (daysMatch != null) {
      final d = int.tryParse(daysMatch.group(1)!) ?? 2;
      return DateTime.now()
          .subtract(Duration(days: d, minutes: indexOffset * 4));
    }
    return DateTime.now().subtract(Duration(hours: 6 + indexOffset));
  }

  String _cleanText(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _formatMoney(num amount) {
    return _numberFormat.format(amount);
  }

  String _relativeTimeFa(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes.clamp(1, 59);
      return '$mins دقیقه پیش';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} ساعت پیش';
    }
    return '${diff.inDays} روز پیش';
  }

  WorkMode _detectWorkMode(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('هیبرید') ||
        lower.contains('نیمه حضوری') ||
        lower.contains('نیمه‌حضوری') ||
        lower.contains('hybrid')) {
      return WorkMode.hybrid;
    }
    if (lower.contains('دورکار') ||
        lower.contains('دورکاری') ||
        lower.contains('remote') ||
        lower.contains('غیرحضوری') ||
        lower.contains('آنلاین')) {
      return WorkMode.remote;
    }
    return WorkMode.onSite;
  }

  String _extractSalaryFromJobinja(String contractRaw) {
    final parenMatch = RegExp(r'\((.*?)\)').firstMatch(contractRaw);
    if (parenMatch != null) {
      final inside = parenMatch.group(1)!.trim();
      if (inside.isNotEmpty) return inside;
    }
    return 'توافقی';
  }

  String _extractContractType(String raw) {
    if (raw.contains('پاره وقت') || raw.contains('پاره‌وقت')) {
      return 'پاره‌وقت';
    }
    if (raw.contains('دورکاری')) {
      return 'دورکاری';
    }
    if (raw.contains('پروژه') || raw.contains('پیمانکاری')) {
      return 'پروژه‌ای';
    }
    if (raw.contains('کارآموزی')) {
      return 'کارآموزی';
    }
    return 'تمام‌وقت';
  }

  List<String> _detectSkills(String text) {
    final lower = text.toLowerCase();
    final detected = <String>[];

    final map = <String, List<String>>{
      'Flutter': ['flutter', 'فلاتر'],
      'Dart': ['dart', 'دارت'],
      'Android': ['android', 'اندروید'],
      'Kotlin': ['kotlin', 'کاتلین'],
      'Java': ['java', 'جاوا'],
      'iOS': ['ios', 'آی او اس', 'آی‌اواس'],
      'React Native': ['react native', 'ری اکت نیتیو'],
      'Firebase': ['firebase', 'فایربیس', 'فایر بیس'],
      'REST API': ['api', 'rest', 'وب سرویس', 'وب‌سرویس'],
      'Senior': ['senior', 'ارشد'],
    };

    map.forEach((label, keys) {
      if (keys.any((k) => lower.contains(k))) {
        detected.add(label);
      }
    });

    if (detected.isEmpty) {
      detected.addAll(['توسعه موبایل', 'اپلیکیشن']);
    }
    return detected.take(5).toList();
  }
}
