import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/di/injection_container.dart';
import '../../core/services/background_worker_service.dart';
import '../../core/services/notification_service.dart';
import '../bloc/jobs_bloc.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with WidgetsBindingObserver {
  final SharedPreferences _prefs = sl<SharedPreferences>();
  final NotificationService _notifService = sl<NotificationService>();
  final BackgroundWorkerService _bgService = sl<BackgroundWorkerService>();

  late bool _notificationsEnabled;
  late bool _backgroundWorkerEnabled;
  late bool _topicFlutter;
  late bool _topicAndroid;
  late bool _topicFreelance;
  late bool _topicEmployment;

  bool _isNotifPermissionGranted = true;
  bool _isBatteryOptIgnored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationsEnabled = _prefs.getBool('notifications_enabled') ?? true;
    _backgroundWorkerEnabled =
        _prefs.getBool('background_worker_enabled') ?? true;
    _topicFlutter = _prefs.getBool('topic_flutter_jobs') ?? true;
    _topicAndroid = _prefs.getBool('topic_android_jobs') ?? true;
    _topicFreelance = _prefs.getBool('topic_freelance_projects') ?? true;
    _topicEmployment = _prefs.getBool('topic_employment_jobs') ?? true;

    _checkNativeStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNativeStatuses();
    }
  }

  Future<void> _checkNativeStatuses() async {
    final notifGranted = await _notifService.areNotificationsEnabled();
    final batteryIgnored = await _notifService.isBatteryOptimizationIgnored();
    if (mounted) {
      setState(() {
        _isNotifPermissionGranted = notifGranted;
        _isBatteryOptIgnored = batteryIgnored;
      });
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    await _prefs.setBool(key, value);
    await _notifService.syncDefaultTopics();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jobsState = context.watch<JobsBloc>().state;
    final sampleJob =
        jobsState.allJobs.isNotEmpty ? jobsState.allJobs.first : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تنظیمات نوتیفیکیشن پس‌زمینه و فایربیس',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          // ۱. کارت وضعیت مجوز نوتیفیکیشن اندروید
          if (!_isNotifPermissionGranted) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFDC2626)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'مجوز اعلان در سیستم‌عامل غیرفعال است!',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'برای دریافت اعلان‌های آگهی در زمان بسته بودن اپ، لطفاً مجوز نوتیفیکیشن را در تنظیمات گوشی فعال کنید.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                    onPressed: () => _notifService.openNotificationSettings(),
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('باز کردن تنظیمات اعلان گوشی'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ۲. کارت بهینه‌سازی باتری اندروید (Doze mode)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isBatteryOptIgnored
                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isBatteryOptIgnored
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isBatteryOptIgnored
                          ? Icons.verified_rounded
                          : Icons.battery_alert_rounded,
                      color: _isBatteryOptIgnored
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isBatteryOptIgnored
                          ? 'فعالیت در پس‌زمینه بدون محدودیت باتری مجاز است ✅'
                          : 'محدودیت بهینه‌سازی باتری اندروید فعال است ⚠️',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _isBatteryOptIgnored
                              ? const Color(0xFF059669)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _isBatteryOptIgnored
                      ? 'اندروید اجازه بررسی دوره‌ای آگهی‌ها در زمان بسته بودن اپ را بدون تاخیر صادر کرده است.'
                      : 'در گوشی‌های شیائومی، سامسونگ و هواوی، اندروید برای ذخیره باتری پس از بستن برنامه، سرویس‌های پس‌زمینه را به خواب می‌برد. برای ارسال تضمینی و بدون تاخیر اعلان‌ها، محدودیت باتری را حذف کنید.',
                  style: const TextStyle(fontSize: 11.5, height: 1.4),
                ),
                if (!_isBatteryOptIgnored) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await _notifService.requestIgnoreBatteryOptimization();
                      await _checkNativeStatuses();
                    },
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: const Text('حذف محدودیت باتری برای DevScout'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ۳. وضعیت فایربیس
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وضعیت فایربیس: ${_notifService.firebaseStatusMessage}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_notifService.fcmToken != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'FCM Token: ${_notifService.fcmToken}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: _notifService.fcmToken!),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('توکن FCM فایربیس کپی شد.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('کپی توکن'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'دریافت نوتیفیکیشن آگهی‌های جدید (بدون تکرار)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            subtitle: const Text(
              'ارسال نوتیفیکیشن فقط برای جدیدترین آگهی‌هایی که قبلاً ارسال نشده‌اند',
              style: TextStyle(fontSize: 11.5),
            ),
            value: _notificationsEnabled,
            onChanged: (val) {
              setState(() => _notificationsEnabled = val);
              _saveBool('notifications_enabled', val);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'بررسی خودکار در زمان بسته بودن اپ (بدون نیاز به سرور)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            subtitle: const Text(
              'اسکرپ دوره‌ای ۴ سایت مرجع در پس‌زمینه اندروید حتی زمانی که اپ کاملاً بسته است',
              style: TextStyle(fontSize: 11.5),
            ),
            value: _backgroundWorkerEnabled,
            onChanged: (val) async {
              setState(() => _backgroundWorkerEnabled = val);
              await _saveBool('background_worker_enabled', val);
              if (val) {
                await _bgService.registerPeriodicScrape();
              } else {
                await _bgService.cancelBackgroundScrape();
              }
            },
          ),
          const Divider(),
          const Text(
            'فیلتر دسته‌بندی نوتیفیکیشن‌ها:',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('آگهی‌های فلاتر دولوپر (Flutter & Dart)'),
            value: _topicFlutter,
            onChanged: (val) {
              if (val == null) return;
              setState(() => _topicFlutter = val);
              _saveBool('topic_flutter_jobs', val);
            },
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('آگهی‌های توسعه‌دهنده اندروید (Kotlin / Java)'),
            value: _topicAndroid,
            onChanged: (val) {
              if (val == null) return;
              setState(() => _topicAndroid = val);
              _saveBool('topic_android_jobs', val);
            },
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('پروژه‌های فریلنسری (پونیشا و کارلنسر)'),
            value: _topicFreelance,
            onChanged: (val) {
              if (val == null) return;
              setState(() => _topicFreelance = val);
              _saveBool('topic_freelance_projects', val);
            },
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('آگهی‌های استخدامی (جابینجا و جاب‌ویژن)'),
            value: _topicEmployment,
            onChanged: (val) {
              if (val == null) return;
              setState(() => _topicEmployment = val);
              _saveBool('topic_employment_jobs', val);
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: sampleJob == null
                ? null
                : () async {
                    await _notifService.triggerTestNotification(sampleJob);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'نوتیفیکیشن تستی ارسال شد! روی اعلان بالای صفحه ضربه بزنید تا دیپ‌لینک تست شود.',
                          ),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('تست نوتیفیکیشن همین الان (همراه با دیپ‌لینک)'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await _bgService.triggerDelayedBackgroundTest();
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('تست پس‌زمینه با موفقیت زمان‌بندی شد'),
                    content: const Text(
                      'تسک پس‌زمینه اندروید تنظیم شد!\n\n'
                      '📱 لطفاً همین حالا از برنامه خارج شوید و اپلیکیشن را کاملاً ببندید (Swipe-close کنید).\n\n'
                      'ظرف ۸ الی ۱۵ ثانیه دیگر، اعلان تستی سرویس پس‌زمینه در زمان بسته بودن اپ روی صفحه گوشی شما ظاهر خواهد شد.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('متوجه شدم'),
                      ),
                    ],
                  ),
                );
              }
            },
            icon: const Icon(Icons.timer_outlined),
            label: const Text(
              'تست نوتیفیکیشن پس‌زمینه (۸ ثانیه پس از بستن اپ)',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
