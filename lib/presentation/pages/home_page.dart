import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection_container.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/background_worker_service.dart';
import '../../domain/entities/job_entity.dart';
import '../bloc/jobs_bloc.dart';
import '../bloc/jobs_event.dart';
import '../bloc/jobs_state.dart';
import '../widgets/app_drawer.dart';
import '../widgets/job_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _autoScrapeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final bloc = context.read<JobsBloc>();
      if (bloc.state.selectedSourceFilter != null) {
        bloc.add(const JobsSourceFilterChangedEvent(null));
      }
    });

    _autoScrapeTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) {
        context.read<JobsBloc>().add(
          const JobsRefreshRequestedEvent(showFeedback: false),
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      sl<BackgroundWorkerService>().scheduleCheckOnAppExit();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoScrapeTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    return BlocConsumer<JobsBloc, JobsState>(
      listenWhen: (previous, current) =>
          previous.feedbackVersion != current.feedbackVersion &&
          current.feedbackMessage != null,
      listener: (context, state) {
        final msg = state.feedbackMessage;
        if (msg != null && msg.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      builder: (context, state) {
        final freelanceJobs = state.freelanceJobs;
        final employmentJobs = state.employmentJobs;
        final isLoading = state.status == JobsStatus.loading;

        return Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(
            titleSpacing: 4,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/branding/app_icon.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  s.appName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: isLoading
                    ? null
                    : () => context.read<JobsBloc>().add(
                        const JobsRefreshRequestedEvent(),
                      ),
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outline,
                      width: 1,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 2,
                  labelColor: theme.colorScheme.onSurface,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  tabs: [
                    Tab(
                      height: 42,
                      text: '${s.freelanceTab} (${freelanceJobs.length})',
                    ),
                    Tab(
                      height: 42,
                      text: '${s.employmentTab} (${employmentJobs.length})',
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              _buildSearchAndFiltersBar(context, theme, state, s),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildJobListTab(
                      context: context,
                      state: state,
                      s: s,
                      jobs: freelanceJobs,
                      sources: const [JobSource.ponisha, JobSource.karlancer],
                    ),
                    _buildJobListTab(
                      context: context,
                      state: state,
                      s: s,
                      jobs: employmentJobs,
                      sources: const [JobSource.jobinja, JobSource.jobvision],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFiltersBar(
    BuildContext context,
    ThemeData theme,
    JobsState state,
    AppStrings s,
  ) {
    final bloc = context.read<JobsBloc>();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 38,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => bloc.add(JobsSearchQueryChangedEvent(val)),
              onSubmitted: (_) => bloc.add(const JobsRefreshRequestedEvent()),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: s.searchHint,
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                suffixIcon: state.searchQuery.isNotEmpty
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _searchController.clear();
                          bloc.add(const JobsSearchQueryChangedEvent(''));
                        },
                        icon: const Icon(Icons.close_rounded, size: 16),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.onSurface,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...JobRoleFilter.values.map((roleFilter) {
                  final selected = state.selectedRoleFilter == roleFilter;
                  final roleCount = state.roleCounts[roleFilter] ?? 0;
                  final baseTitle = s.roleFilterTitle(roleFilter);
                  final label = roleCount > 0
                      ? '$baseTitle ($roleCount)'
                      : baseTitle;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6, right: 2),
                    child: _FilterPill(
                      label: label,
                      dotColor: roleFilter.dotColor,
                      selected: selected,
                      onTap: () =>
                          bloc.add(JobsRoleFilterChangedEvent(roleFilter)),
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(left: 6, right: 2),
                  child: _FilterPill(
                    label: s.remoteOnly,
                    dotColor: const Color(0xFF059669),
                    selected: state.onlyRemote,
                    onTap: () =>
                        bloc.add(JobsRemoteOnlyToggledEvent(!state.onlyRemote)),
                  ),
                ),
                if (state.bookmarkedIds.isNotEmpty || state.onlyBookmarked)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, right: 2),
                    child: _FilterPill(
                      label:
                          '${s.bookmarkedOnly} (${state.bookmarkedIds.length})',
                      dotColor: const Color(0xFFD97706),
                      selected: state.onlyBookmarked,
                      onTap: () => bloc.add(
                        JobsBookmarkedOnlyToggledEvent(!state.onlyBookmarked),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobListTab({
    required BuildContext context,
    required JobsState state,
    required AppStrings s,
    required List<JobEntity> jobs,
    required List<JobSource> sources,
  }) {
    final theme = Theme.of(context);
    final bloc = context.read<JobsBloc>();
    final isLoading = state.status == JobsStatus.loading;

    return RefreshIndicator(
      onRefresh: () async {
        bloc.add(const JobsRefreshRequestedEvent());
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                      label: s.allSources,
                      selected:
                          state.selectedSourceFilter == null ||
                          !sources.contains(state.selectedSourceFilter),
                      onTap: () =>
                          bloc.add(const JobsSourceFilterChangedEvent(null)),
                    ),
                    const SizedBox(width: 6),
                    ...sources.map((src) {
                      final isSelected = state.selectedSourceFilter == src;
                      final status = state.sourceStatuses[src];
                      final label = status != null
                          ? '${s.sourceName(src)} (${status.count})'
                          : s.sourceName(src);
                      return Padding(
                        padding: const EdgeInsets.only(left: 6, right: 2),
                        child: _FilterPill(
                          label: label,
                          dotColor: src.brandColor,
                          selected: isSelected,
                          onTap: () => bloc.add(
                            JobsSourceFilterChangedEvent(
                              isSelected ? null : src,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          if (isLoading && jobs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.loadingJobs,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (jobs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.noResults,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          _searchController.clear();
                          bloc.add(const JobsClearFiltersEvent());
                        },
                        child: Text(s.clearFilters),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 4, bottom: 28),
              sliver: SliverList.builder(
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  return JobCard(
                    key: ValueKey(job.id),
                    job: job,
                    isBookmarked: state.bookmarkedIds.contains(job.id),
                    onToggleBookmark: () =>
                        bloc.add(JobBookmarkToggledEvent(job.id)),
                    onTapDetails: () => context.push(
                      '/job/${Uri.encodeComponent(job.id)}',
                      extra: job,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? dotColor;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.onSurface
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.outline,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? theme.colorScheme.surface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
