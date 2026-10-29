import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection_container.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/deep_link_service.dart';
import '../../domain/entities/job_entity.dart';
import '../bloc/jobs_bloc.dart';
import '../bloc/jobs_event.dart';
import '../bloc/locale_cubit.dart';
import '../bloc/theme_cubit.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final isDark = context.watch<ThemeCubit>().isDarkMode;
    final isFa = context.watch<LocaleCubit>().isPersian;
    final jobsState = context.watch<JobsBloc>().state;

    return Drawer(
      width: 300,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/branding/app_icon.png',
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        s.appName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.appTagline,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                children: [
                  // ۱. تغییر تم (ذخیره خودکار در SharedPreferences)
                  _SectionLabel(label: s.drawerAppearance),
                  const SizedBox(height: 8),
                  _SegmentedToggle(
                    leftLabel: s.darkMode,
                    leftIcon: Icons.dark_mode_outlined,
                    rightLabel: s.lightMode,
                    rightIcon: Icons.light_mode_outlined,
                    isLeftSelected: isDark,
                    onSelectLeft: () =>
                        context.read<ThemeCubit>().setDarkMode(true),
                    onSelectRight: () =>
                        context.read<ThemeCubit>().setDarkMode(false),
                  ),
                  const SizedBox(height: 20),

                  // ۲. تغییر زبان (ذخیره خودکار در SharedPreferences)
                  _SectionLabel(label: s.drawerLanguage),
                  const SizedBox(height: 8),
                  _SegmentedToggle(
                    leftLabel: 'فارسی',
                    leftIcon: Icons.translate_rounded,
                    rightLabel: 'English',
                    rightIcon: Icons.language_rounded,
                    isLeftSelected: isFa,
                    onSelectLeft: () =>
                        context.read<LocaleCubit>().setLanguage('fa'),
                    onSelectRight: () =>
                        context.read<LocaleCubit>().setLanguage('en'),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),

                  // ۳. تنظیمات نوتیفیکیشن و سرویس پس‌زمینه
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    leading: Icon(
                      Icons.notifications_none_rounded,
                      size: 21,
                      color: theme.colorScheme.onSurface,
                    ),
                    title: Text(
                      s.notificationsMenu,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/settings/notifications');
                    },
                  ),

                  // ۴. فیلتر آگهی‌های ذخیره‌شده
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: Icon(
                      jobsState.onlyBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 21,
                      color: theme.colorScheme.onSurface,
                    ),
                    title: Text(
                      '${s.savedJobsMenu} (${jobsState.bookmarkedIds.length})',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      context.read<JobsBloc>().add(
                        JobsBookmarkedOnlyToggledEvent(
                          !jobsState.onlyBookmarked,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 14),

                  // ۵. میانبرهای مستقیم به سایت‌های مرجع
                  _SectionLabel(label: s.directPortalsHeader),
                  const SizedBox(height: 6),
                  ...JobSource.values.map((source) {
                    final st = jobsState.sourceStatuses[source];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: source.brandColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(
                        s.sourceName(source),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (st != null)
                            Text(
                              '${st.count}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.north_east_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        sl<DeepLinkService>().openSourceLiveSearch(
                          source,
                          context: context,
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  final String leftLabel;
  final IconData leftIcon;
  final String rightLabel;
  final IconData rightIcon;
  final bool isLeftSelected;
  final VoidCallback onSelectLeft;
  final VoidCallback onSelectRight;

  const _SegmentedToggle({
    required this.leftLabel,
    required this.leftIcon,
    required this.rightLabel,
    required this.rightIcon,
    required this.isLeftSelected,
    required this.onSelectLeft,
    required this.onSelectRight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: leftLabel,
              icon: leftIcon,
              selected: isLeftSelected,
              onTap: onSelectLeft,
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: rightLabel,
              icon: rightIcon,
              selected: !isLeftSelected,
              onTap: onSelectRight,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: selected
              ? Border.all(color: theme.colorScheme.outline, width: 0.8)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
