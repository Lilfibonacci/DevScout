import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_radar/core/localization/app_strings.dart';
import 'package:job_radar/core/theme/app_theme.dart';
import 'package:job_radar/domain/entities/job_entity.dart';
import 'package:job_radar/presentation/pages/job_detail_page.dart';
import 'package:job_radar/presentation/widgets/job_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:job_radar/core/di/injection_container.dart';

Future<void> _loadFonts() async {
  // 1. Morabba Fonts
  final morabbaLoader = FontLoader('Morabba');
  final regularBytes = File('assets/fonts/Morabba-Regular.ttf').readAsBytesSync();
  final mediumBytes = File('assets/fonts/Morabba-Medium.ttf').readAsBytesSync();
  final boldBytes = File('assets/fonts/Morabba-Bold.ttf').readAsBytesSync();
  morabbaLoader.addFont(Future.value(ByteData.view(regularBytes.buffer)));
  morabbaLoader.addFont(Future.value(ByteData.view(mediumBytes.buffer)));
  morabbaLoader.addFont(Future.value(ByteData.view(boldBytes.buffer)));
  await morabbaLoader.load();

  // 2. MaterialIcons Font
  final iconsFile = File('/home/towhid/flutter/flutter_linux_3.47.6-stable/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (iconsFile.existsSync()) {
    final iconsLoader = FontLoader('MaterialIcons');
    final iconBytes = iconsFile.readAsBytesSync();
    iconsLoader.addFont(Future.value(ByteData.view(iconBytes.buffer)));
    await iconsLoader.load();
  }
}

List<JobEntity> _createSampleJobs() {
  return [
    JobEntity(
      id: 'ponisha_762611',
      title: 'طراحی و پیاده‌سازی اپلیکیشن فروشگاهی با فلاتر (iOS و اندروید)',
      companyOrClient: 'کارفرما در پونیشا',
      source: JobSource.ponisha,
      salaryOrBudget: '۲۵,۰۰۰,۰۰۰ تا ۴۵,۰۰۰,۰۰۰ تومان',
      city: 'سراسر ایران (آنلاین)',
      workMode: WorkMode.remote,
      contractType: 'پروژه‌ای / فریلنسری',
      description: 'نیازمند توسعه‌دهنده مسلط به فلاتر و BLoC جهت پیاده‌سازی کامل UI اپلیکیشن فروشگاهی و اتصال به REST API ووکامرس. سورس‌کد تمیز و Clean Code اولویت اول ماست.',
      skills: ['Flutter', 'Dart', 'Bloc', 'REST API', 'Figma'],
      publishedTimeText: '۱۲ دقیقه پیش',
      publishedAt: DateTime.now().subtract(const Duration(minutes: 12)),
      originalUrl: 'https://ponisha.ir/project/762611',
      proposalsCountText: '۴ پیشنهاد ثبت شده',
      isUrgent: true,
    ),
    JobEntity(
      id: 'karlancer_337085',
      title: 'توسعه ماژول نقشه و رهگیری آنلاین پیک موتوری در اپلیکیشن فلاتر',
      companyOrClient: 'کارفرما در کارلنسر',
      source: JobSource.karlancer,
      salaryOrBudget: '۱۸,۰۰۰,۰۰۰ تا ۳۰,۰۰۰,۰۰۰ تومان',
      city: 'سراسر ایران',
      workMode: WorkMode.remote,
      contractType: 'پروژه‌ای / فریلنسری',
      description: 'پروژه شامل پیاده‌سازی نقشه بر پایه Mapbox/نشان و ارسال موقعیت مکانی راننده با WebSocket به سرور بک‌اند می‌باشد. پروژه دارای مستندات کامل فیگما است.',
      skills: ['Flutter', 'WebSocket', 'Mapbox', 'Clean Architecture'],
      publishedTimeText: '۳۴ دقیقه پیش',
      publishedAt: DateTime.now().subtract(const Duration(minutes: 34)),
      originalUrl: 'https://www.karlancer.com/projects/337085',
      proposalsCountText: 'مهلت انجام: ۱۵ روز',
      isUrgent: false,
    ),
    JobEntity(
      id: 'jobinja_tpHI',
      title: 'برنامه‌نویس Senior Flutter Developer',
      companyOrClient: 'هوش مصنوعی نیک سام | Niksam AI',
      source: JobSource.jobinja,
      salaryOrBudget: '۵۰,۰۰۰,۰۰۰ تا ۷۰,۰۰۰,۰۰۰ تومان',
      city: 'تهران (امکان دورکاری)',
      workMode: WorkMode.remote,
      contractType: 'تمام‌وقت',
      description: 'شرکت دانش‌بنیان نیک‌سام جهت تکمیل تیم محصولی خود نیازمند سنیور دولوپر فلاتر مسلط به معماری‌های مدرن، CI/CD، تست‌نویسی Unit/Widget و بهینه‌سازی عملکرد است.',
      skills: ['Flutter', 'Dart', 'CI/CD', 'Unit Testing', 'Git'],
      publishedTimeText: '۱ ساعت پیش',
      publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
      originalUrl: 'https://jobinja.ir/companies/niksam/jobs/tpHI',
      isUrgent: true,
    ),
    JobEntity(
      id: 'jobvision_1583303',
      title: 'توسعه‌دهنده ارشد اندروید (Senior Android Developer)',
      companyOrClient: 'گروه صنعتی انتخاب | Entekhab Group',
      source: JobSource.jobvision,
      salaryOrBudget: '۶۰ - ۸۵ میلیون تومان',
      city: 'اصفهان / تهران',
      workMode: WorkMode.hybrid,
      contractType: 'تمام‌وقت (ارشد)',
      description: 'همکاری تمام‌وقت جهت توسعه اپلیکیشن سوپراپ سازمانی. تسلط عمیق به Kotlin، Jetpack Compose، Coroutines/Flow، Coroutines و Clean Architecture الزامی است.',
      skills: ['Kotlin', 'Android SDK', 'Jetpack Compose', 'Flow', 'Coroutines'],
      publishedTimeText: 'امروز',
      publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
      originalUrl: 'https://jobvision.ir/jobs/1583303',
      isUrgent: false,
    ),
    JobEntity(
      id: 'jobinja_tM5G',
      title: 'برنامه‌نویس Flutter (موبایل و وب)',
      companyOrClient: 'ایران هتل آنلاین | Iran Hotel Online',
      source: JobSource.jobinja,
      salaryOrBudget: 'توافقی',
      city: 'مشهد، خراسان رضوی',
      workMode: WorkMode.onSite,
      contractType: 'تمام‌وقت',
      description: 'استخدام توسعه‌دهنده متعهد فلاتر جهت توسعه و نگهداری سیستم‌های رزرواسیون هتل. مزایا: بیمه تکمیلی، پاداش عملکرد، محیط کاری پویا و امکان پیشرفت شغلی.',
      skills: ['Flutter', 'Dart', 'REST API', 'Git'],
      publishedTimeText: 'دیروز',
      publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      originalUrl: 'https://jobinja.ir/companies/iran-hotel-online/jobs/tM5G',
      isUrgent: false,
    ),
  ];
}

Widget _buildHeaderBar(BuildContext context, ThemeData theme, AppStrings s, {required bool isDark}) {
  return Container(
    color: theme.appBarTheme.backgroundColor,
    padding: const EdgeInsets.only(left: 14, right: 14, top: 40, bottom: 8),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File('assets/branding/app_icon.png'),
            width: 28,
            height: 28,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          s.appName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF10B981), width: 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF10B981)),
              SizedBox(width: 3),
              Text(
                'رادار زنده ۲۴/۷',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.notifications_active_outlined, size: 22, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Icon(Icons.menu_rounded, size: 24, color: theme.colorScheme.onSurface),
      ],
    ),
  );
}

Widget _buildTabBar(ThemeData theme, AppStrings s, {required bool isFreelanceActive, required int freelanceCount, required int employmentCount}) {
  return Container(
    decoration: BoxDecoration(
      color: theme.appBarTheme.backgroundColor,
      border: Border(bottom: BorderSide(color: theme.colorScheme.outline, width: 1)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isFreelanceActive ? theme.colorScheme.onSurface : Colors.transparent,
                  width: 2.2,
                ),
              ),
            ),
            child: Center(
              child: Text(
                '${s.freelanceTab} ($freelanceCount)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isFreelanceActive ? FontWeight.w800 : FontWeight.w500,
                  color: isFreelanceActive ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: !isFreelanceActive ? theme.colorScheme.onSurface : Colors.transparent,
                  width: 2.2,
                ),
              ),
            ),
            child: Center(
              child: Text(
                '${s.employmentTab} ($employmentCount)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: !isFreelanceActive ? FontWeight.w800 : FontWeight.w500,
                  color: !isFreelanceActive ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildFilterPills(ThemeData theme, AppStrings s, {JobSource? selectedSource, List<JobSource> sources = const []}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
    color: theme.scaffoldBackgroundColor,
    child: Column(
      children: [
        // Search bar
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 19, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                s.searchHint,
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Icon(Icons.tune_rounded, size: 17, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Role Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _pill(theme, 'همه تخصص‌ها (۷۳)', true, null),
              const SizedBox(width: 6),
              _pill(theme, 'فلاتر (Flutter) (۴۴)', false, const Color(0xFF0284C7)),
              const SizedBox(width: 6),
              _pill(theme, 'اندروید (۲۹)', false, const Color(0xFF16A34A)),
              const SizedBox(width: 6),
              _pill(theme, 'فقط دورکاری', false, const Color(0xFF059669)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Source Pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _pill(theme, s.allSources, selectedSource == null, null),
              const SizedBox(width: 6),
              ...sources.map((src) {
                final isSel = selectedSource == src;
                final count = src == JobSource.ponisha ? 12 : (src == JobSource.karlancer ? 36 : (src == JobSource.jobinja ? 30 : 19));
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _pill(theme, '${s.sourceName(src)} ($count)', isSel, src.brandColor),
                );
              }),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _pill(ThemeData theme, String label, bool selected, Color? dot) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: selected ? theme.colorScheme.onSurface : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(
        color: selected ? theme.colorScheme.onSurface : theme.colorScheme.outline,
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot != null) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? theme.colorScheme.surface : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initDependencies();
    await _loadFonts();
  });

  testWidgets('Render all showcase screenshots', (tester) async {
    final allJobs = _createSampleJobs();
    final freelanceJobs = allJobs.where((j) => j.tabCategory == JobTabCategory.freelance).toList();
    final employmentJobs = allJobs.where((j) => j.tabCategory == JobTabCategory.employment).toList();

    // 1. SCREENSHOT 1: Freelance Feed (Light Mode)
    await _captureScreen(
      tester: tester,
      outputPath: 'docs/screenshots/01_freelance_feed.png',
      isDark: false,
      builder: (context, theme, s) => Column(
        children: [
          _buildHeaderBar(context, theme, s, isDark: false),
          _buildTabBar(theme, s, isFreelanceActive: true, freelanceCount: 24, employmentCount: 49),
          _buildFilterPills(theme, s, sources: const [JobSource.ponisha, JobSource.karlancer]),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 20),
              children: freelanceJobs.map((j) => JobCard(
                job: j,
                isBookmarked: j.id == 'ponisha_762611',
                onToggleBookmark: () {},
                onTapDetails: () {},
              )).toList(),
            ),
          ),
        ],
      ),
    );

    // 2. SCREENSHOT 2: Employment Feed (Light Mode)
    await _captureScreen(
      tester: tester,
      outputPath: 'docs/screenshots/02_employment_feed.png',
      isDark: false,
      builder: (context, theme, s) => Column(
        children: [
          _buildHeaderBar(context, theme, s, isDark: false),
          _buildTabBar(theme, s, isFreelanceActive: false, freelanceCount: 24, employmentCount: 49),
          _buildFilterPills(theme, s, sources: const [JobSource.jobinja, JobSource.jobvision]),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 20),
              children: employmentJobs.map((j) => JobCard(
                job: j,
                isBookmarked: j.id == 'jobinja_tpHI',
                onToggleBookmark: () {},
                onTapDetails: () {},
              )).toList(),
            ),
          ),
        ],
      ),
    );

    // 3. SCREENSHOT 3: Job Detail View (Light Mode)
    await _captureScreen(
      tester: tester,
      outputPath: 'docs/screenshots/03_job_detail.png',
      isDark: false,
      builder: (context, theme, s) {
        final job = allJobs[0];
        return JobDetailPage(
          jobId: job.id,
          initialJob: job,
        );
      },
    );

    // 4. SCREENSHOT 4: Dark Mode Feed
    await _captureScreen(
      tester: tester,
      outputPath: 'docs/screenshots/04_dark_mode.png',
      isDark: true,
      builder: (context, theme, s) => Column(
        children: [
          _buildHeaderBar(context, theme, s, isDark: true),
          _buildTabBar(theme, s, isFreelanceActive: true, freelanceCount: 24, employmentCount: 49),
          _buildFilterPills(theme, s, sources: const [JobSource.ponisha, JobSource.karlancer]),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 20),
              children: [allJobs[0], allJobs[2], allJobs[1]].map((j) => JobCard(
                job: j,
                isBookmarked: true,
                onToggleBookmark: () {},
                onTapDetails: () {},
              )).toList(),
            ),
          ),
        ],
      ),
    );
  });
}

Future<void> _captureScreen({
  required WidgetTester tester,
  required String outputPath,
  required bool isDark,
  required Widget Function(BuildContext context, ThemeData theme, AppStrings s) builder,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;

  final repaintKey = GlobalKey();
  final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(
          key: repaintKey,
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Builder(
              builder: (ctx) => builder(ctx, theme, AppStrings.of(ctx)),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();

  final boundary = repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  File(outputPath).writeAsBytesSync(byteData!.buffer.asUint8List());
  print('Generated screenshot: $outputPath (${File(outputPath).lengthSync()} bytes)');
}
