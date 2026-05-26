import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// Self-hosted OTA check. Polls the GitHub Releases API for the latest
/// tag and — if it parses as a higher [Version] than what's baked into the
/// running APK — surfaces a one-tap dialog that opens the release page in
/// the browser for the user to download and install.
///
/// No third-party update service. No in-app downloader. We rely on the OS
/// to handle the .apk after the user taps it in their browser.
class UpdateChecker {
  UpdateChecker._();

  /// owner/repo to poll. Latest release endpoint is
  ///   https://api.github.com/repos/{owner/repo}/releases/latest
  static const _repo = 'kon2raya24/worship-team-hub-mobile';

  /// Skip the network call if the last successful check was less than
  /// this far in the past — GitHub's anonymous API rate-limit is 60/hr.
  static const _throttle = Duration(hours: 12);

  /// SharedPreferences keys.
  static const _kLastCheck = 'updater.lastCheckMillis';
  static const _kSkippedTag = 'updater.skippedTag';

  static Future<void> checkOnLaunch(BuildContext context) async {
    // Wait a beat so the dialog doesn't fight the first-paint sync badge.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!context.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_kLastCheck) ?? 0;
    final since = DateTime.now().millisecondsSinceEpoch - lastMs;
    if (since < _throttle.inMilliseconds) return;

    final release = await _fetchLatestRelease();
    if (release == null) return;
    await prefs.setInt(
      _kLastCheck,
      DateTime.now().millisecondsSinceEpoch,
    );

    final current = await PackageInfo.fromPlatform();
    final currentV = _Version.tryParse(current.version);
    final latestV = _Version.tryParse(release.tag);
    if (currentV == null || latestV == null) return;
    if (!latestV.isNewerThan(currentV)) return;

    // Respect "Skip this version" — user tapped Later last time and we
    // recorded the tag they don't want to be nagged about again. They'll
    // still be prompted when a tag newer than the skipped one ships.
    final skipped = prefs.getString(_kSkippedTag);
    if (skipped != null) {
      final skippedV = _Version.tryParse(skipped);
      if (skippedV != null && !latestV.isNewerThan(skippedV)) return;
    }

    if (!context.mounted) return;
    await _promptUpdate(context, release);
  }

  static Future<_LatestRelease?> _fetchLatestRelease() async {
    try {
      final res = await http
          .get(
            Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = json['tag_name'] as String?;
      final htmlUrl = json['html_url'] as String?;
      final assets = (json['assets'] as List?) ?? const [];
      String? apkUrl;
      for (final a in assets) {
        final name = (a['name'] as String?) ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apkUrl = a['browser_download_url'] as String?;
          break;
        }
      }
      if (tag == null || (htmlUrl == null && apkUrl == null)) return null;
      return _LatestRelease(
        tag: tag,
        releasePageUrl: htmlUrl,
        apkUrl: apkUrl,
        notes: json['body'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _promptUpdate(
    BuildContext context,
    _LatestRelease release,
  ) async {
    final action = await showDialog<_UpdateAction>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Sanctuary.ink2,
        title: Text('Update available · ${release.tag}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A newer version of Worship Hub is ready. Tap "Update" to '
              'download and install — your data stays put.',
              style: TextStyle(color: Sanctuary.muted, fontSize: 13),
            ),
            if (release.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Text(
                    release.notes.trim(),
                    style: const TextStyle(
                      color: Sanctuary.foreground,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_UpdateAction.skip),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_UpdateAction.later),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_UpdateAction.update),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (action == _UpdateAction.skip) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSkippedTag, release.tag);
      return;
    }
    if (action != _UpdateAction.update) return;

    // Prefer the direct APK URL when present — saves the user a tap on
    // the release page. Falls back to the release page if no APK asset.
    final target = release.apkUrl ?? release.releasePageUrl;
    if (target == null) return;
    final uri = Uri.parse(target);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

enum _UpdateAction { update, later, skip }

class _LatestRelease {
  _LatestRelease({
    required this.tag,
    required this.releasePageUrl,
    required this.apkUrl,
    required this.notes,
  });
  final String tag;
  final String? releasePageUrl;
  final String? apkUrl;
  final String notes;
}

/// Bare-minimum semver-ish comparator. Strips a leading `v` (so "v0.2.0"
/// and "0.2.0" both parse) and ignores any pre-release / build suffix
/// (we don't ship those).
class _Version {
  const _Version(this.parts);
  final List<int> parts;

  static _Version? tryParse(String raw) {
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    // Drop +build suffix and -prerelease suffix.
    s = s.split('+').first.split('-').first;
    final pieces = s.split('.');
    final out = <int>[];
    for (final p in pieces) {
      final n = int.tryParse(p);
      if (n == null) return null;
      out.add(n);
    }
    if (out.isEmpty) return null;
    return _Version(out);
  }

  bool isNewerThan(_Version other) {
    final len = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < len; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a > b) return true;
      if (a < b) return false;
    }
    return false;
  }
}
