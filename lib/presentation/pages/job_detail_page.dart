import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/injection_container.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/deep_link_service.dart';
import '../../domain/entities/job_entity.dart';
import '../bloc/jobs_bloc.dart';
import '../bloc/jobs_event.dart';
import '../bloc/jobs_state.dart';

class JobDetailPage extends StatelessWidget {
  final String jobId;
  final JobEntity? initialJob;

  const JobDetailPage({
    super.key,
    required this.jobId,
    this.initialJob,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    return BlocBuilder<JobsBloc, JobsState>(
      builder: (context, state) {
        final job = state.findJobById(jobId) ?? initialJob;
        if (job == null) {
          return Scaffold(
            appBar: AppBar(title: Text(s.jobDetailsTitle)),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.noResults),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('DevScout'),
                  ),
                ],
              ),
            ),
          );
        }

        final isBookmarked = state.bookmarkedIds.contains(job.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              s.jobDetailsTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  context.read<JobsBloc>().add(JobBookmarkToggledEvent(job.id));
                },
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 21,
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(color: theme.colorScheme.outline, height: 1),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: job.source.brandColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${s.sourceName(job.source)} · ${job.source.domain}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    job.publishedTimeText,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                job.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              if (job.hasDisplayableCompanyOrClient) ...[
                const SizedBox(height: 6),
                Text(
                  job.companyOrClient,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Column(
                  children: [
                    _SpecRow(
                      label: s.compensationLabel,
                      value: job.salaryOrBudget,
                    ),
                    const Divider(height: 20),
                    _SpecRow(
                      label: s.locationLabel,
                      value: job.city,
                    ),
                    const Divider(height: 20),
                    _SpecRow(
                      label: s.workModeLabel,
                      value: s.workModeText(job.workMode),
                    ),
                    const Divider(height: 20),
                    _SpecRow(
                      label: s.contractLabel,
                      value: job.contractType,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                s.descriptionHeader,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Text(
                  job.description,
                  style: const TextStyle(
                    fontSize: 13.8,
                    height: 1.7,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                s.skillsHeader,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: job.skills.map((skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Text(
                      skill,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.originalUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: job.originalUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.linkCopied)),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(
                          s.copyLink,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outline),
                ),
              ),
              child: FilledButton.icon(
                onPressed: () {
                  sl<DeepLinkService>().openOriginalJobUrl(
                    job.originalUrl,
                    context: context,
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.onSurface,
                  foregroundColor: theme.colorScheme.surface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.north_east_rounded, size: 17),
                label: Text(
                  '${s.viewInSource} (${s.sourceName(job.source)})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;

  const _SpecRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: muted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
