import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/job_entity.dart';

/// هندلر پیام‌های پس‌زمینه فایربیس (زمانی که اپ بسته یا در پس‌زمینه است)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    final prefs = await SharedPreferences.getInstance();
    final notificationService = NotificationService(sharedPreferences: prefs);
    await notificationService.initForBackgroundIsolate();

    final notification = message.notification;
    final data = message.data;

    // اگر پیام شامل شیء notification نباشد (پیام data-only باشد)، سیستم‌عامل خودکار اعلان نمی‌سازد
    // بنابراین در این حالت اعلان را به صورت دستی نمایش می‌دهیم تا هیچ اعلانی از دست نرود
    if (notification == null) {
      final title = data['title'] ?? 'آگهی جدید فلاتر / اندروید';
      final body = data['body'] ??
          'یک موقعیت شغلی جدید منتشر شد. برای مشاهده ضربه بزنید.';
      final targetUrl = data['url'] ?? data['originalUrl'];
      final jobId = data['id'] ?? data['jobId'];

      await notificationService.showInstantNotification(
        title: title.toString(),
        body: body.toString(),
        jobId: jobId?.toString(),
        targetUrl: targetUrl?.toString(),
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

  bool isFirebaseInitialized = false;
  String? fcmToken;
  String firebaseStatusMessage = 'در حال بررسی اتصال فایربیس...';

  void Function(String? jobId, String? targetUrl)? _onNotificationTap;

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

  /// راه‌اندازی کامل نوتیفیکیشن محلی و فایربیس (در ترد اصلی UI)
  Future<void> initialize({
    required void Function(String? jobId, String? targetUrl) onNotificationTap,
  }) async {
    _onNotificationTap = onNotificationTap;
    await _initLocalNotifications(isBackgroundIsolate: false);
    await _initFirebaseMessagingSafely();
  }

  /// راه‌اندازی سبک ویژه ایزوله پس‌زمینه (زمانی که اپ کاملاً بسته است)
  Future<void> initForBackgroundIsolate() async {
    await _initLocalNotifications(isBackgroundIsolate: true);
  }

  Future<void> _initLocalNotifications({
    required bool isBackgroundIsolate,
  }) async {
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

      if (!isBackgroundIsolate) {
        await androidPlugin?.requestNotificationsPermission();

        final launchDetails =
            await _localNotifications.getNotificationAppLaunchDetails();
        if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
          final payload = launchDetails.notificationResponse?.payload;
          if (payload != null && payload.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 600), () {
              _handlePayloadTap(payload);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Local notifications init skipped on this platform: $e');
    }
  }

  Future<void> _initFirebaseMessagingSafely() async {
    try {
      await Firebase.initializeApp();
      isFirebaseInitialized = true;

      final messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final data = message.data;

        final title =
            notification?.title ?? data['title'] ?? 'آگهی جدید فلاتر / اندروید';
        final body = notification?.body ??
            data['body'] ??
            'یک موقعیت شغلی جدید منتشر شد. برای مشاهده ضربه بزنید.';
        final targetUrl = data['url'] ?? data['originalUrl'];
        final jobId = data['id'] ?? data['jobId'];

        showInstantNotification(
          title: title.toString(),
          body: body.toString(),
          jobId: jobId?.toString(),
          targetUrl: targetUrl?.toString(),
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final targetUrl = message.data['url'] ?? message.data['originalUrl'];
        final jobId = message.data['id'] ?? message.data['jobId'];
        _onNotificationTap?.call(jobId?.toString(), targetUrl?.toString());
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        final targetUrl =
            initialMessage.data['url'] ?? initialMessage.data['originalUrl'];
        final jobId =
            initialMessage.data['id'] ?? initialMessage.data['jobId'];
        _onNotificationTap?.call(jobId?.toString(), targetUrl?.toString());
      }
    } catch (e) {
      isFirebaseInitialized = false;
      firebaseStatusMessage =
          'بدون نیاز به سرور فعال است (نوتیفیکیشن پس‌زمینه داخلی فعال)';
      debugPrint('Firebase Safe Init Notice: $e');
    }
  }

  Future<void> syncDefaultTopics() async {
    if (!isFirebaseInitialized) return;
    try {
      final subFlutter =
          sharedPreferences.getBool('topic_flutter_jobs') ?? true;
      final subAndroid =
          sharedPreferences.getBool('topic_android_jobs') ?? true;
      final subFreelance =
          sharedPreferences.getBool('topic_freelance_projects') ?? true;
      final subEmployment =
          sharedPreferences.getBool('topic_employment_jobs') ?? true;

      final messaging = FirebaseMessaging.instance;
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
    } catch (_) {}
  }

  void _handlePayloadTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final jobId = map['jobId']?.toString();
      final targetUrl = map['targetUrl']?.toString();
      _onNotificationTap?.call(jobId, targetUrl);
    } catch (_) {
      if (payload.startsWith('http')) {
        _onNotificationTap?.call(null, payload);
      }
    }
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? jobId,
    String? targetUrl,
  }) async {
    final payload = jsonEncode({
      'jobId': jobId,
      'targetUrl': targetUrl,
    });

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android: androidDetails);
    final notificationId =
        (jobId ?? '$title|$body').hashCode.abs().remainder(100000);

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

  /// بررسی آگهی‌های تازه اسکرپ‌شده و ارسال نوتیفیکیشن فقط برای جدیدترین آگهی‌های غیرتکراری
  Future<int> notifyNewScrapedJobs(
    List<JobEntity> currentJobs, {
    bool isBackgroundCheck = false,
  }) async {
    if (currentJobs.isEmpty) return 0;

    final notificationsEnabled =
        sharedPreferences.getBool('notifications_enabled') ?? true;
    if (!notificationsEnabled) return 0;

    // اولویت‌های انتخابی کاربر
    final subFlutter =
        sharedPreferences.getBool('topic_flutter_jobs') ?? true;
    final subAndroid =
        sharedPreferences.getBool('topic_android_jobs') ?? true;
    final subFreelance =
        sharedPreferences.getBool('topic_freelance_projects') ?? true;
    final subEmployment =
        sharedPreferences.getBool('topic_employment_jobs') ?? true;

    // فیلتر کردن آگهی‌ها بر اساس دسته‌بندی‌های انتخابی کاربر
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

    // مجموعه‌ای از تمام شناسه‌هایی که تا کنون اعلان آن‌ها ارسال شده است (تضمین عدم ارسال تکراری)
    final notifiedIds =
        (sharedPreferences.getStringList('notified_job_ids') ?? <String>[])
            .toSet();
    final knownJobIds =
        (sharedPreferences.getStringList('known_job_ids') ?? <String>[])
            .toSet();

    final isFirstRun = knownJobIds.isEmpty;

    if (isFirstRun) {
      // ثبت آگهی‌های موجود در اولین بار باز شدن برنامه
      knownJobIds.addAll(currentJobs.map((e) => e.id));
      await sharedPreferences.setStringList(
          'known_job_ids', knownJobIds.toList());

      // ارسال نوتیفیکیشن خوش‌آمدگویی/تست اولیه فقط برای ۲ آگهی خیلی جدید
      final initialTargets = matchingJobs
          .where((j) => !notifiedIds.contains(j.id))
          .take(2)
          .toList();

      for (final job in initialTargets) {
        notifiedIds.add(job.id);
        await showInstantNotification(
          title: '🔔 جدیدترین در ${job.source.persianName}: ${job.title}',
          body:
              '💰 ${job.salaryOrBudget} | 📍 ${job.city} (${job.workMode.label})\nبرای مشاهده در سایت اصلی ضربه بزنید.',
          jobId: job.id,
          targetUrl: job.originalUrl,
        );
      }

      await _saveNotifiedIds(notifiedIds);
      return initialTargets.length;
    }

    // آگهی‌های مطابق فیلتر که تاکنون برای آن‌ها اعلان ارسال نشده است
    final unnotifiedJobs = matchingJobs
        .where((job) => !notifiedIds.contains(job.id))
        .toList();

    // اولویت با آگهی‌های کاملاً جدید است که قبلاً ثبت نشده بودند
    var jobsToNotify = unnotifiedJobs
        .where((job) => !knownJobIds.contains(job.id))
        .take(3)
        .toList();

    // در حالت پس‌زمینه اگر آگهی کاملاً جدیدی در این لحظه نیامده، اما آگهی‌های اخیر هنوز نوتیف نشده‌اند:
    if (isBackgroundCheck && jobsToNotify.isEmpty && unnotifiedJobs.isNotEmpty) {
      final recentThreshold =
          DateTime.now().subtract(const Duration(days: 2));
      jobsToNotify = unnotifiedJobs
          .where((j) => j.publishedAt.isAfter(recentThreshold))
          .take(1)
          .toList();
    }

    // به‌روزرسانی شناسه آگهی‌های شناخته‌شده با محدود کردن سقف به ۴۰۰ آیتم
    knownJobIds.addAll(currentJobs.map((e) => e.id));
    if (knownJobIds.length > 500) {
      final list = knownJobIds.toList();
      knownJobIds
        ..clear()
        ..addAll(list.sublist(list.length - 400));
    }
    await sharedPreferences.setStringList(
        'known_job_ids', knownJobIds.toList());

    if (jobsToNotify.isEmpty) {
      return 0;
    }

    for (final job in jobsToNotify) {
      notifiedIds.add(job.id);
      await showInstantNotification(
        title: '🔔 آگهی جدید در ${job.source.persianName}: ${job.title}',
        body:
            '💰 ${job.salaryOrBudget} | 📍 ${job.city} (${job.workMode.label})\nبرای مشاهده در سایت اصلی ضربه بزنید.',
        jobId: job.id,
        targetUrl: job.originalUrl,
      );
    }

    await _saveNotifiedIds(notifiedIds);
    return jobsToNotify.length;
  }

  Future<void> _saveNotifiedIds(Set<String> notifiedIds) async {
    // جلوگیری از رشد بی‌رویه شناسه اعلان‌ها
    var list = notifiedIds.toList();
    if (list.length > 600) {
      list = list.sublist(list.length - 500);
    }
    await sharedPreferences.setStringList('notified_job_ids', list);
  }

  Future<void> triggerTestNotification(JobEntity sampleJob) async {
    await showInstantNotification(
      title: '🔔 آگهی فوری (${sampleJob.source.persianName}): ${sampleJob.title}',
      body:
          'حقوق/بودجه: ${sampleJob.salaryOrBudget} | ${sampleJob.workMode.label} | شهر: ${sampleJob.city}\nضربه بزنید تا مستقیماً باز شود!',
      jobId: sampleJob.id,
      targetUrl: sampleJob.originalUrl,
    );
  }
}
