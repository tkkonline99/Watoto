import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/desktop_export_stub.dart'
    if (dart.library.io) '../../core/offline/desktop_export_io.dart';
import '../../core/offline/offline_providers.dart';
import '../../core/theme/watoto_theme.dart';
import '../../core/widgets/mascot_widget.dart';
import '../../core/widgets/watoto_button.dart';
import '../../l10n/gen/app_localizations.dart';
import 'rewards.dart';

/// Simple on-device certificate, saveable as an image so it can leave the app.
class CertificateScreen extends ConsumerStatefulWidget {
  const CertificateScreen({super.key});

  @override
  ConsumerState<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends ConsumerState<CertificateScreen> {
  final _boundaryKey = GlobalKey();
  bool _saving = false;

  /// Renders the certificate card to a PNG and puts it somewhere the family
  /// can reach. Falls back to copying a text summary where there is no
  /// writable folder (web, and mobile without a share sheet).
  Future<void> _save(String childName, String summary) async {
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    String message = l10n.certificateSaveFailed;
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        // 3x so the saved image is crisp enough to print.
        final image = await boundary.toImage(pixelRatio: 3);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data != null) {
          final png = data.buffer.asUint8List();
          final path = await writeCertificateImage(png, childName);
          if (path != null) {
            message = l10n.certificateSaved(path);
          } else {
            await Clipboard.setData(ClipboardData(text: summary));
            message = l10n.certificateCopied;
          }
        }
      }
    } catch (_) {
      // Fall through to the failure message below.
    }
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final child = ref.watch(activeChildProvider);
    final store = ref.watch(offlineStoreProvider);
    if (child == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.certificateTitle)),
        body: Center(child: Text(l10n.certificateNeedChild)),
      );
    }
    final xp = store.xpFor(child.id);
    final level = levelForXp(xp);
    final lessons = store.completedLessonCount(child.id);
    final stars = store.totalStars(child.id);
    final date = DateTime.now();
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: WatotoColors.cloud,
      appBar: AppBar(
        title: Text(l10n.certificateTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: RepaintBoundary(
              key: _boundaryKey,
              child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: WatotoColors.sun, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: WatotoColors.deep.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const MascotWidget(mood: MascotMood.cheer, size: 80),
                  const SizedBox(height: 12),
                  Text(
                    l10n.certificateHeading,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: WatotoColors.sky,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    child.nickname,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Baloo2',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: WatotoColors.deep,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.certificateBody(level, lessons, stars),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: WatotoColors.deep.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Watoto',
                    style: TextStyle(
                      fontFamily: 'Baloo2',
                      fontWeight: FontWeight.w800,
                      color: WatotoColors.mango.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
      // Outside the RepaintBoundary: the buttons must not appear in the saved
      // image.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              WatotoButton(
                label: _saving ? l10n.certificateSaving : l10n.certificateSave,
                onPressed: _saving
                    ? null
                    : () => _save(
                          child.nickname,
                          '${child.nickname} — '
                          '${l10n.certificateBody(level, lessons, stars)} '
                          '($dateStr)',
                        ),
              ),
              WatotoButton(
                label: l10n.done,
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
