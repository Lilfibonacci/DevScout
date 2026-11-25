import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/job_local_data_source.dart';
import '../../data/models/job_model.dart';
import '../../domain/entities/job_entity.dart';
import 'notification_tap_payload.dart';

/// هندلر پیام‌های پس‌زمینه فایربیس (زمانی که اپ بسته یا در پس‌زمینه است)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    final prefs = await SharedPreferences.getInstance();
    final notificationService = NotificationService(sharedPreferences: prefs);
    await notificationService.initForBackgroundIsolate();

    final payload = NotificationTapPayload.fromRemoteMessage(message);
    final alreadyNotified =
        await notificationService.isJobAlreadyNotified(payload.jobId);
    await notificationService.markJobNotifiedAndKnown(payload.jobId);

    if (payload.job != null) {
      await notificationService.cacheJobFromPush(payload.job!);
    }

    // اگر پیام data-only باشد (بدون شیء notification)، اعلان محلی را فقط در صورت عدم تکرار نمایش بده
    if (message.notification == null && !alreadyNotified) {
      final data = message.data;
      final title = data['title'] ?? 'آگهی جدید فلاتر / اندروید';
      final body = data['body'] ??
          'یک موقعیت شغلی جدید منتشر شد. برای مشاهده ضربه بزنید.';

      await notificationService.showInstantNotification(
        title: title.toString(),
        body: body.toString(),
        jobId: payload.jobId,
        targetUrl: payload.targetUrl,
        job: payload.job,
      );
    }
  } catch (e) {
    debugPrint('FCM Background handler error: $e');
  }
}

class NotificationService {
  final SharedPreferences sharedPreferences;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const MethodChannel _nativeChannel =
      MethodChannel('ir.devradar.job_radar/native_settings');

  static const String _notifiedIdsKey = 'notified_job_ids';
  static const String _knownIdsKey = 'known_job_ids';
  static const String fcmPushActiveKey = 'fcm_push_active';
  static const int _maxTrackedIds = 2000;
  static const int _trimTrackedIds = 1500;

  bool isFirebaseInitialized = false;
  String? fcmToken;
  String firebaseStatusMessage = 'در حال بررسی اتصال فایربیس...';

  final Set<String> _sessionNotifiedIds = <String>{};
  NotificationTapPayload? _pendingTapPayload;
  void Function(NotificationTapPayload payload)? _onNotificationTap;
  void Function(JobModel job)? _onForegroundJobReceived;
  bool _localInitialized = false;
  bool _listenersRegistered = false;

  NotificationService({required this.sharedPreferences});

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'job_radar_high_importance_channel',
    'اعلان فوری آگهی‌های فلاتر و اندروید',
    description:
        'اطلاع‌رسانی آنی به محض انتشار آگهی جدید در پونیشا، کارلنسر، جابینجا و جاب‌ویژن',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// شناسه قطعی و یکتا برای نوتیفیکیشن اندروید (ثابت در تمام ایزوله‌ها و اجراهای بعدی)
  static int stableNotificationId(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash % 100000;
  }

  /// تگ یکتا برای جایگزینی نوتیفیکیشن هم‌شناسه در نوار اعلان اندروید
  static String? sanitizeTag(String? jobId) {
    if (jobId == null || jobId.trim().isEmpty) return null;
    final cleaned = jobId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    return cleaned.length > 64 ? cleaned.substring(0, 64) : cleaned;
  }

  Future<void> _reloadPrefsSafely() async {
    try {
      await sharedPreferences.reload();
    } catch (_) {}
  }

  List<String> _lruAddAndTrim(
    List<String> existing,
    Iterable<String> additions,
  ) {
    final ordered = LinkedHashSet<String>.from(
      existing.where((e) => e.trim().isNotEmpty),
    );
    for (final raw in additions) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      ordered.remove(id);
      ordered.add(id);
    }
    final list = ordered.toList();
    if (list.length > _maxTrackedIds) {
      return list.sublist(list.length - _trimTrackedIds);
    }
    return list;
  }

  /// بررسی تکراری بودن شناسه اعلان در حافظه نشست و SharedPreferences (با reload بین ایزوله‌ها)
  Future<bool> isJobAlreadyNotified(String? jobId) async {
    final id = jobId?.trim();
    if (id == null || id.isEmpty) return false;
    if (_sessionNotifiedIds.contains(id)) return true;

    await _reloadPrefsSafely();
    final notifiedList =
        sharedPreferences.getStringList(_notifiedIdsKey) ?? const <String>[];
    if (notifiedList.contains(id)) {
      _sessionNotifiedIds.add(id);
      return true;
    }
    return false;
  }

  /// ثبت شناسه آگهی در لیست‌های اعلان‌شده و شناخته‌شده برای جلوگیری از تکرار
  Future<void> markJobNotifiedAndKnown(String? jobId) async {
    final id = jobId?.trim();
    if (id == null || id.isEmpty) return;

    _sessionNotifiedIds.add(id);
    await _reloadPrefsSafely();

    final notified =
        sharedPreferences.getStringList(_notifiedIdsKey) ?? const <String>[];
    final known =
        sharedPreferences.getStringList(_knownIdsKey) ?? const <String>[];

    await Future.wait([
      sharedPreferences.setStringList(
        _notifiedIdsKey,
        _lruAddAndTrim(notified, [id]),
      ),
      sharedPreferences.setStringList(
        _knownIdsKey,
        _lruAddAndTrim(known, [id]),
      ),
    ]);
  }

  /// ذخیره آنی آگهی دریافت‌شده از نوتیفیکیشن در کش محلی بدون جایگزینی نسخه کامل‌تر
  Future<void> cacheJobFromPush(JobModel job) async {
    await _reloadPrefsSafely();
    final raw =
        sharedPreferences.getString(JobLocalDataSourceImpl.cachedJobsKey);
    final List<Map<String, dynamic>> list = <Map<String, dynamic>>[];

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              list.add(Map<String, dynamic>.from(item));
            }
          }
        }
      } catch (_) {}
    }

    final existingIdx = list.indexWhere((e) => e['id']?.toString() == job.id);
    final incomingJson = job.toJson();

    if (existingIdx >= 0) {
      final existingDesc =
          (list[existingIdx]['description'] ?? '').toString().trim();
      if (job.description.trim().length >= existingDesc.length) {
        list[existingIdx] = incomingJson;
      }
    } else {
      list.insert(0, incomingJson);
    }

    await sharedPreferences.setString(
      JobLocalDataSourceImpl.cachedJobsKey,
      jsonEncode(list),
    );
  }

  /// راه‌اندازی سبک ویژه ایزوله پس‌زمینه (زمانی که اپ کاملاً بسته است)
  Future<void> initForBackgroundIsolate() async {
    await _initLocalNotifications(isBackgroundIsolate: true);
  }

  /// خواندن فوری و بدون تاخیر پیام یا نوتیفیکیشنِ بازکننده اپ پیش از render اولین فریم
  Future<NotificationTapPayload?> captureInitialLaunchNotification() async {
    await _initLocalNotifications(isBackgroundIsolate: false);

    NotificationTapPayload? localLaunchPayload;
    try {
      final launchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final parsed = NotificationTapPayload.fromLocalPayload(
          launchDetails.notificationResponse?.payload,
        );
        if (parsed.hasAction) {
          localLaunchPayload = parsed;
        }
      }
    } catch (e) {
      debugPrint('Local launch details read error: $e');
    }

    NotificationTapPayload? fcmLaunchPayload;
    try {
      await Firebase.initializeApp()
          .timeout(const Duration(milliseconds: 1500));
      isFirebaseInitialized = true;

      final messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _registerFirebaseListeners(messaging);

      final initialMessage = await messaging
          .getInitialMessage()
          .timeout(const Duration(milliseconds: 800));
      if (initialMessage != null) {
        final parsed = NotificationTapPayload.fromRemoteMessage(initialMessage);
        if (parsed.hasAction) {
          fcmLaunchPayload = parsed;
        }
      }
    } catch (e) {
      debugPrint('Fast Firebase launch check notice: $e');
    }

    final chosen = fcmLaunchPayload ?? localLaunchPayload;
    if (chosen != null) {
      unawaited(markJobNotifiedAndKnown(chosen.jobId));
      if (chosen.job != null) {
        unawaited(cacheJobFromPush(chosen.job!));
      }
    }
    return chosen;
  }

  /// اتصال کال‌بک‌های مسیر‌یابی و اجرای غیرمسدودکننده تنظیمات شبکه فایربیس پس از رندر UI
  Future<void> completeBackgroundInitialization({
    required void Function(NotificationTapPayload payload) onNotificationTap,
    void Function(JobModel job)? onForegroundJobReceived,
  }) async {
    _onNotificationTap = onNotificationTap;
    _onForegroundJobReceived = onForegroundJobReceived;

    if (_pendingTapPayload != null) {
      final pending = _pendingTapPayload!;
      _pendingTapPayload = null;
      _onNotificationTap?.call(pending);
    }

    await Future.wait([
      _requestLocalNotificationPermission(),
      _initFirebaseNetworkSetupSafely(),
    ]);
  }

  Future<void> _initLocalNotifications({
    required bool isBackgroundIsolate,
  }) async {
    if (_localInitialized) return;
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handlePayloadTap(response.payload);
        },
      );

      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_androidChannel);
      _localInitialized = true;
    } catch (e) {
      if (!isBackgroundIsolate) {
        debugPrint('Local notifications init skipped on this platform: $e');
      }
    }
  }

  Future<void> _requestLocalNotificationPermission() async {
    try {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {}
  }

  void _registerFirebaseListeners(FirebaseMessaging messaging) {
    if (_listenersRegistered) return;
    _listenersRegistered = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _reloadPrefsSafely();
      final notificationsEnabled =
          sharedPreferences.getBool('notifications_enabled') ?? true;
      final payload = NotificationTapPayload.fromRemoteMessage(message);

      if (payload.job != null) {
        _onForegroundJobReceived?.call(payload.job!);
        unawaited(cacheJobFromPush(payload.job!));
      }

      if (!notificationsEnabled) {
        await markJobNotifiedAndKnown(payload.jobId);
        return;
      }

      final alreadyNotified = await isJobAlreadyNotified(payload.jobId);
      if (alreadyNotified) {
        return;
      }

      await markJobNotifiedAndKnown(payload.jobId);

      final notification = message.notification;
      final data = message.data;
      final title =
          notification?.title ?? data['title'] ?? 'آگهی جدید فلاتر / اندروید';
      final body = notification?.body ??
          data['body'] ??
          'یک موقعیت شغلی جدید منتشر شد. برای مشاهده ضربه بزنید.';

      await showInstantNotification(
        title: title.toString(),
        body: body.toString(),
        jobId: payload.jobId,
        targetUrl: payload.targetUrl,
        job: payload.job,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final payload = NotificationTapPayload.fromRemoteMessage(message);
      unawaited(markJobNotifiedAndKnown(payload.jobId));
      if (payload.job != null) {
        unawaited(cacheJobFromPush(payload.job!));
      }
      _dispatchTap(payload);
    });
  }

  Future<void> _initFirebaseNetworkSetupSafely() async {
    try {
      if (!isFirebaseInitialized) {
        await Firebase.initializeApp();
        isFirebaseInitialized = true;
      }

      final messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _registerFirebaseListeners(messaging);

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      fcmToken = await messaging.getToken();
      firebaseStatusMessage = settings.authorizationStatus ==
              AuthorizationStatus.authorized
          ? 'متصل به فایربیس (FCM فعال و آماده دریافت آنی)'
          : 'فایربیس متصل است (مجوز نوتیفیکیشن را فعال کنید)';

      await syncDefaultTopics();
    } catch (e) {
      isFirebaseInitialized = false;
      await sharedPreferences.setBool(fcmPushActiveKey, false);
      firebaseStatusMessage =
          'بدون نیاز به سرور فعال است (نوتیفیکیشن پس‌زمینه داخلی فعال)';
      debugPrint('Firebase Safe Init Notice: $e');
    }
  }

  Future<void> syncDefaultTopics() async {
    if (!isFirebaseInitialized) return;
    try {
      final notificationsEnabled =
          sharedPreferences.getBool('notifications_enabled') ?? true;
      final messaging = FirebaseMessaging.instance;

      if (!notificationsEnabled) {
        await Future.wait([
          messaging.unsubscribeFromTopic('flutter_jobs'),
          messaging.unsubscribeFromTopic('android_jobs'),
          messaging.unsubscribeFromTopic('freelance_projects'),
          messaging.unsubscribeFromTopic('employment_jobs'),
        ]);
        await sharedPreferences.setBool(fcmPushActiveKey, false);
        return;
      }

      final subFlutter =
          sharedPreferences.getBool('topic_flutter_jobs') ?? true;
      final subAndroid =
          sharedPreferences.getBool('topic_android_jobs') ?? true;
      final subFreelance =
          sharedPreferences.getBool('topic_freelance_projects') ?? true;
      final subEmployment =
          sharedPreferences.getBool('topic_employment_jobs') ?? true;

      await Future.wait([
        subFlutter
            ? messaging.subscribeToTopic('flutter_jobs')
            : messaging.unsubscribeFromTopic('flutter_jobs'),
        subAndroid
            ? messaging.subscribeToTopic('android_jobs')
            : messaging.unsubscribeFromTopic('android_jobs'),
        subFreelance
            ? messaging.subscribeToTopic('freelance_projects')
            : messaging.unsubscribeFromTopic('freelance_projects'),
        subEmployment
            ? messaging.subscribeToTopic('employment_jobs')
            : messaging.unsubscribeFromTopic('employment_jobs'),
      ]);
      await sharedPreferences.setBool(fcmPushActiveKey, true);
    } catch (_) {}
  }

  void _handlePayloadTap(String? rawPayload) {
    final parsed = NotificationTapPayload.fromLocalPayload(rawPayload);
    if (!parsed.hasAction) return;
    unawaited(markJobNotifiedAndKnown(parsed.jobId));
    _dispatchTap(parsed);
  }

  void _dispatchTap(NotificationTapPayload payload) {
    if (!payload.hasAction) return;
    if (_onNotificationTap != null) {
      _onNotificationTap!(payload);
    } else {
      _pendingTapPayload = payload;
    }
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? jobId,
    String? targetUrl,
    JobEntity? job,
  }) async {
    final effectiveJobId = jobId ?? job?.id;
    final effectiveTargetUrl = targetUrl ?? job?.originalUrl;

    final payload = jsonEncode({
      'jobId': effectiveJobId,
      'targetUrl': effectiveTargetUrl,
      if (job != null) 'job': JobModel.fromEntity(job).toJson(),
    });

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
      icon: '@mipmap/ic_launcher',
      tag: sanitizeTag(effectiveJobId),
      onlyAlertOnce: true,
    );

    final details = NotificationDetails(android: androidDetails);
    final notificationId =
        stableNotificationId(effectiveJobId ?? '$title|$body');

    try {
      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Local notification display skipped: $e');
    }
  }

  Future<bool> areNotificationsEnabled() async {
    try {
      final res =
          await _nativeChannel.invokeMethod<bool>('areNotificationsEnabled');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await _nativeChannel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final res = await _nativeChannel
          .invokeMethod<bool>('isBatteryOptimizationIgnored');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestIgnoreBatteryOptimization() async {
    try {
      await _nativeChannel.invokeMethod('requestIgnoreBatteryOptimization');
    } catch (_) {}
  }

  /// بررسی آگهی‌های تازه اسکرپ‌شده و ارسال نوتیفیکیشن فقط برای آگهی‌های کاملاً جدید در نبود پوش ابری
  Future<int> notifyNewScrapedJobs(
    List<JobEntity> currentJobs, {
    bool isBackgroundCheck = false,
  }) async {
    if (currentJobs.isEmpty) return 0;

    await _reloadPrefsSafely();

    final existingNotified =
        sharedPreferences.getStringList(_notifiedIdsKey) ?? const <String>[];
    final existingKnown =
        sharedPreferences.getStringList(_knownIdsKey) ?? const <String>[];

    final previousKnown = existingKnown.toSet();
    final isFirstRun = previousKnown.isEmpty;
    final currentIds = currentJobs.map((e) => e.id).toList();
    final newlyDiscoveredCount =
        currentJobs.where((j) => !previousKnown.contains(j.id)).length;

    final updatedKnown = _lruAddAndTrim(existingKnown, currentIds);
    await sharedPreferences.setStringList(_knownIdsKey, updatedKnown);

    // در حالت پیش‌زمینه کاربر خودش در حال مشاهده لیست است؛ فقط شناسه‌ها ثبت می‌شوند تا تکراری ارسال نشود
    if (!isBackgroundCheck) {
      _sessionNotifiedIds.addAll(currentIds);
      final updatedNotified = _lruAddAndTrim(existingNotified, currentIds);
      await sharedPreferences.setStringList(_notifiedIdsKey, updatedNotified);
      return newlyDiscoveredCount;
    }

    if (isFirstRun) {
      _sessionNotifiedIds.addAll(currentIds);
      final updatedNotified = _lruAddAndTrim(existingNotified, currentIds);
      await sharedPreferences.setStringList(_notifiedIdsKey, updatedNotified);
      return 0;
    }

    final notificationsEnabled =
        sharedPreferences.getBool('notifications_enabled') ?? true;
    if (!notificationsEnabled) return 0;

    // اگر پوش ابری فایربیس فعال باشد، ورک‌منیجر فقط کش را بی‌صدا به‌روز می‌کند تا نوتیفیکیشن تکراری ندهد
    final fcmPushActive =
        sharedPreferences.getBool(fcmPushActiveKey) ?? false;
    if (fcmPushActive) {
      _sessionNotifiedIds.addAll(currentIds);
      final updatedNotified = _lruAddAndTrim(existingNotified, currentIds);
      await sharedPreferences.setStringList(_notifiedIdsKey, updatedNotified);
      return 0;
    }

    // اولویت‌های انتخابی کاربر
    final subFlutter =
        sharedPreferences.getBool('topic_flutter_jobs') ?? true;
    final subAndroid =
        sharedPreferences.getBool('topic_android_jobs') ?? true;
    final subFreelance =
        sharedPreferences.getBool('topic_freelance_projects') ?? true;
    final subEmployment =
        sharedPreferences.getBool('topic_employment_jobs') ?? true;

    final matchingJobs = currentJobs.where((job) {
      if (job.tabCategory == JobTabCategory.freelance && !subFreelance) {
        return false;
      }
      if (job.tabCategory == JobTabCategory.employment && !subEmployment) {
        return false;
      }
      final isFlutterJob = job.matchesRoleFilter(JobRoleFilter.flutter);
      final isAndroidJob = job.matchesRoleFilter(JobRoleFilter.android);

      if (isFlutterJob && !subFlutter && !isAndroidJob) return false;
      if (isAndroidJob && !subAndroid && !isFlutterJob) return false;
      if (!isFlutterJob && !isAndroidJob && !subFlutter && !subAndroid) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    if (matchingJobs.isEmpty) return 0;

    final notifiedSet = existingNotified.toSet();
    final jobsToNotify = matchingJobs
        .where(
          (job) =>
              !notifiedSet.contains(job.id) &&
              !previousKnown.contains(job.id) &&
              !_sessionNotifiedIds.contains(job.id),
        )
        .take(3)
        .toList();

    if (jobsToNotify.isEmpty) {
      return 0;
    }

    final newlyNotifiedIds = <String>[];
    for (final job in jobsToNotify) {
      _sessionNotifiedIds.add(job.id);
      newlyNotifiedIds.add(job.id);
      await showInstantNotification(
        title: '🔔 آگهی جدید در ${job.source.persianName}: ${job.title}',
        body:
            '💰 ${job.salaryOrBudget} | 📍 ${job.city} (${job.workMode.label})\nبرای مشاهده در سایت اصلی ضربه بزنید.',
        jobId: job.id,
        targetUrl: job.originalUrl,
        job: job,
      );
    }

    final updatedNotified =
        _lruAddAndTrim(existingNotified, newlyNotifiedIds);
    await sharedPreferences.setStringList(_notifiedIdsKey, updatedNotified);
    return jobsToNotify.length;
  }

  Future<void> triggerTestNotification(JobEntity sampleJob) async {
    await showInstantNotification(
      title: '🔔 آگهی فوری (${sampleJob.source.persianName}): ${sampleJob.title}',
      body:
          'حقوق/بودجه: ${sampleJob.salaryOrBudget} | ${sampleJob.workMode.label} | شهر: ${sampleJob.city}\nضربه بزنید تا مستقیماً باز شود!',
      jobId: sampleJob.id,
      targetUrl: sampleJob.originalUrl,
      job: sampleJob,
    );
  }
}
