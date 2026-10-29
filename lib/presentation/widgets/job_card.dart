import 'package:flutter/material.dart';
import '../../core/di/injection_container.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/deep_link_service.dart';
import '../../domain/entities/job_entity.dart';

class JobCard extends StatelessWidget {
  final JobEntity job;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;
  final VoidCallback onTapDetails;

  const JobCard({
    super.key,
    required this.job,
    required this.isBookmarked,
    required this.onToggleBookmark,
    required this.onTapDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    final subtitleParts = <String>[
      if (job.hasDisplayableCompanyOrClient) job.companyOrClient.trim(),
      job.city,
      s.workModeText(job.workMode),
    ];

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Material(
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: theme.colorScheme.outline, width: 1),
          ),
          child: InkWell(
            onTap: onTapDetails,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ردیف اول: نقطه کوچک منبع + نام سایت + زمان انتشار + نشان‌کردن
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: job.source.brandColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.sourceName(job.source),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '·',
                        style: TextStyle(color: mutedColor, fontSize: 12),
                      ),
                    ),
                    Text(
                      job.publishedTimeText,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: mutedColor,
                      ),
                    ),
                    if (job.isUrgent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          s.isFa ? 'فوری' : 'Urgent',
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    InkWell(
                      onTap: onToggleBookmark,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isBookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 18,
                          color: isBookmarked
                              ? theme.colorScheme.onSurface
                              : mutedColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // عنوان موقعیت شغلی
                Text(
                  job.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),

                // نام شرکت (در صورت وجود) + شهر + وضعیت دورکاری در یک خط تمیز
                Text(
                  subtitleParts.join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 9),

                // خلاصه کوتاه توضیحات
                Text(
                  job.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: mutedColor.withValues(alpha: 0.9),
                  ),
                ),

                if (job.skills.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: job.skills.take(4).map((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: theme.colorScheme.outline,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          skill,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // فوتر کارت: میزان حقوق/بودجه + دکمه باز کردن در سایت اصلی
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            job.salaryOrBudget,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (job.proposalsCountText != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              job.proposalsCountText!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: mutedColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        sl<DeepLinkService>().openOriginalJobUrl(
                          job.originalUrl,
                          context: context,
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              s.viewInSource,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.surface,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.north_east_rounded,
                              size: 13,
                              color: theme.colorScheme.surface,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
