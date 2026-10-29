import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/di/injection_container.dart';
import 'core/router/app_router.dart';
import 'core/services/background_worker_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/bloc/jobs_bloc.dart';
import 'presentation/bloc/jobs_event.dart';
import 'presentation/bloc/locale_cubit.dart';
import 'presentation/bloc/theme_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();

  // اجرای فوری UI بدون معطل کردن اسپلش اسکرین برای فایربیس یا ورک‌منیجر
  runApp(const JobRadarApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_bootstrapServicesAfterFirstFrame());
  });
}

Future<void> _bootstrapServicesAfterFirstFrame() async {
  final appRouter = sl<AppRouter>();

  // بلافاصله لود آگهی‌های کش‌شده و اسکرپ در ایزوله جداگانه آغاز شود
  sl<JobsBloc>().add(const JobsInitializedEvent());

  await Future.wait([
    sl<DeepLinkService>().initIncomingLinks(
      onDeepLinkReceived: appRouter.handleIncomingDeepLink,
    ),
    sl<NotificationService>().initialize(
      onNotificationTap: appRouter.handleIncomingDeepLink,
    ),
    sl<BackgroundWorkerService>().initializeAndSchedule(),
  ]);
}

class JobRadarApp extends StatelessWidget {
  const JobRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<JobsBloc>.value(value: sl<JobsBloc>()),
        BlocProvider<ThemeCubit>.value(value: sl<ThemeCubit>()),
        BlocProvider<LocaleCubit>.value(value: sl<LocaleCubit>()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return BlocBuilder<LocaleCubit, Locale>(
            builder: (context, locale) {
              return MaterialApp.router(
                title: 'DevScout',
                debugShowCheckedModeBanner: false,
                locale: locale,
                supportedLocales: const [
                  Locale('fa', 'IR'),
                  Locale('en', 'US'),
                ],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                themeMode: themeMode,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                routerConfig: sl<AppRouter>().router,
              );
            },
          );
        },
      ),
    );
  }
}
