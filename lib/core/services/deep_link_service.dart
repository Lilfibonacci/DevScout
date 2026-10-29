import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/entities/job_entity.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  Future<void> initIncomingLinks({
    required void Function(String? jobId, String? targetUrl) onDeepLinkReceived,
  }) async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri, onDeepLinkReceived);
      }

      _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
        _handleUri(uri, onDeepLinkReceived);
      });
    } catch (_) {}
  }

  void _handleUri(
    Uri uri,
    void Function(String? jobId, String? targetUrl) onDeepLinkReceived,
  ) {
    final jobId = uri.queryParameters['id'];
    final targetUrl = uri.queryParameters['url'];
    if (jobId != null || targetUrl != null) {
      onDeepLinkReceived(jobId, targetUrl);
    }
  }

  Future<bool> openOriginalJobUrl(
    String rawUrl, {
    BuildContext? context,
  }) async {
    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('آدرس لینک آگهی معتبر نیست.')),
        );
      }
      return false;
    }

    try {
      final launchedExternal = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launchedExternal) return true;

      return await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
    } catch (_) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در باز کردن لینک: $trimmed')),
        );
      }
      return false;
    }
  }

  Future<void> openSourceLiveSearch(
    JobSource source, {
    String keyword = 'flutter',
    BuildContext? context,
  }) async {
    final encoded = Uri.encodeComponent(keyword);
    String url;
    switch (source) {
      case JobSource.ponisha:
        url = 'https://ponisha.ir/search/projects?query=$encoded';
        break;
      case JobSource.karlancer:
        url = 'https://www.karlancer.com/search?q=$encoded';
        break;
      case JobSource.jobinja:
        url = 'https://jobinja.ir/jobs?filters%5Bkeywords%5D%5B0%5D=$encoded';
        break;
      case JobSource.jobvision:
        url = 'https://jobvision.ir/jobs/keyword/$encoded';
        break;
    }
    await openOriginalJobUrl(url, context: context);
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
