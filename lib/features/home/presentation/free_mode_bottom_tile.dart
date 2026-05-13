import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/constants/internal_constants.dart';
import '../../../core/data/di/service_locator.dart';
import '../../../core/data/services/purchases_service.dart';
import 'tabs/Settings/entitlement_page.dart';

class FreeModeBottomTile extends StatelessWidget {
  const FreeModeBottomTile({
    super.key,
    required this.tier,
    this.isWebOverride,
    this.adsSupportedOverride,
    this.bannerAdUnitIdOverride,
    this.canRequestAdsListenable,
    this.bannerContentBuilder,
    this.onUpgradeTap,
  });

  final EntitlementTier tier;
  final bool? isWebOverride;
  final bool? adsSupportedOverride;
  final String? bannerAdUnitIdOverride;
  final ValueListenable<bool>? canRequestAdsListenable;
  final WidgetBuilder? bannerContentBuilder;
  final VoidCallback? onUpgradeTap;

  @override
  Widget build(BuildContext context) {
    if (tier == EntitlementTier.pro) {
      return const SizedBox.shrink();
    }

    final isWebBuild = isWebOverride ?? kIsWeb;
    final adsConsent = ServiceLocator.adsConsentService;
    final bannerAdUnitId =
        bannerAdUnitIdOverride ?? _bannerAdUnitIdForCurrentPlatform();
    final adsSupported = adsSupportedOverride ?? adsConsent.isSupported;
    final canRequestAdsValue =
        canRequestAdsListenable ?? adsConsent.canRequestAdsListenable;

    if (isWebBuild || !adsSupported || bannerAdUnitId.isEmpty) {
      return _PromoUpgradeTile(
        onUpgradeTap: onUpgradeTap,
        isUpgradeEnabled: !isWebBuild,
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: canRequestAdsValue,
      builder: (context, canRequestAds, _) {
        if (!canRequestAds) {
          return _PromoUpgradeTile(
            onUpgradeTap: onUpgradeTap,
            isUpgradeEnabled: !isWebBuild,
          );
        }

        return _BannerAdTile(
          adUnitId: bannerAdUnitId,
          bannerContentBuilder: bannerContentBuilder,
        );
      },
    );
  }

  static String _bannerAdUnitIdForCurrentPlatform() {
    if (kIsWeb) {
      return '';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return IConst.adMobAndroidBannerId;
      case TargetPlatform.iOS:
        return IConst.adMobIosBannerId;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return '';
    }
  }
}

class _BannerAdTile extends StatefulWidget {
  const _BannerAdTile({required this.adUnitId, this.bannerContentBuilder});

  final String adUnitId;
  final WidgetBuilder? bannerContentBuilder;

  @override
  State<_BannerAdTile> createState() => _BannerAdTileState();
}

class _BannerAdTileState extends State<_BannerAdTile> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  _BannerLoadFailure? _lastLoadFailure;

  @override
  void initState() {
    super.initState();
    if (widget.bannerContentBuilder == null) {
      _loadBannerAd();
    }
  }

  @override
  void didUpdateWidget(covariant _BannerAdTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bannerContentBuilder != oldWidget.bannerContentBuilder) {
      if (widget.bannerContentBuilder != null) {
        _disposeBannerAd();
      } else {
        _loadBannerAd();
      }
      return;
    }

    if (widget.adUnitId != oldWidget.adUnitId &&
        widget.bannerContentBuilder == null) {
      _disposeBannerAd();
      _loadBannerAd();
    }
  }

  @override
  void dispose() {
    _disposeBannerAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannerContent = widget.bannerContentBuilder?.call(context);
    if (bannerContent != null) {
      return _AdShell(child: bannerContent);
    }

    if (!_isLoaded || _bannerAd == null) {
      return _PromoUpgradeTile(
        isUpgradeEnabled: true,
        debugDiagnosticMessage: _debugAdDiagnosticMessage(),
      );
    }

    return _AdShell(
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }

  Future<void> _loadBannerAd() async {
    if (widget.adUnitId.isEmpty) {
      return;
    }

    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          final loadedAd = ad as BannerAd;
          _logBannerLoadSuccess(loadedAd.responseInfo);
          if (!mounted) return;
          setState(() {
            _bannerAd = loadedAd;
            _isLoaded = true;
            _lastLoadFailure = null;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _logBannerLoadFailure(error);
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
            _lastLoadFailure = _classifyBannerLoadFailure(error);
          });
        },
      ),
    );

    _bannerAd = ad;
    unawaited(ad.load());
  }

  void _disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;
    _lastLoadFailure = null;
  }

  String? _debugAdDiagnosticMessage() {
    if (!kDebugMode || _lastLoadFailure == null) {
      return null;
    }

    return switch (_lastLoadFailure!.kind) {
      _BannerLoadFailureKind.noFill =>
        'Ad unavailable now (Google no fill).',
      _BannerLoadFailureKind.appIssue =>
        'Ad unavailable due to app/config issue.',
      _BannerLoadFailureKind.unknown =>
        'Ad unavailable (unknown cause).',
    };
  }

  _BannerLoadFailure _classifyBannerLoadFailure(LoadAdError error) {
    final message = error.message.toLowerCase();
    final domain = error.domain.toLowerCase();

    final isNoFillByCode = error.code == 3;
    final isNoFillByMessage = message.contains('no fill');
    if (isNoFillByCode || isNoFillByMessage) {
      return _BannerLoadFailure(
        kind: _BannerLoadFailureKind.noFill,
        rawError: error,
      );
    }

    final isLikelyAppIssue =
        domain.contains('mobile_ads') ||
        domain.contains('admob') ||
        message.contains('invalid') ||
        message.contains('app id') ||
        message.contains('ad unit') ||
        message.contains('internal');
    if (isLikelyAppIssue) {
      return _BannerLoadFailure(
        kind: _BannerLoadFailureKind.appIssue,
        rawError: error,
      );
    }

    return _BannerLoadFailure(
      kind: _BannerLoadFailureKind.unknown,
      rawError: error,
    );
  }

  void _logBannerLoadSuccess(ResponseInfo? responseInfo) {
    final responseId = responseInfo?.responseId ?? 'n/a';
    debugPrint('[Ads][BANNER][LOADED] responseId=$responseId');
  }

  void _logBannerLoadFailure(LoadAdError error) {
    final failure = _classifyBannerLoadFailure(error);
    final type = switch (failure.kind) {
      _BannerLoadFailureKind.noFill => 'NO_FILL',
      _BannerLoadFailureKind.appIssue => 'APP_ISSUE',
      _BannerLoadFailureKind.unknown => 'UNKNOWN',
    };
    final responseId = error.responseInfo?.responseId ?? 'n/a';
    final msg =
        '[Ads][BANNER][$type] code=${error.code}, domain=${error.domain}, message=${error.message}, responseId=$responseId';
    debugPrint(msg);
    unawaited(ServiceLocator.diagnosticsService.log(msg));
  }
}

enum _BannerLoadFailureKind { noFill, appIssue, unknown }

class _BannerLoadFailure {
  const _BannerLoadFailure({required this.kind, required this.rawError});

  final _BannerLoadFailureKind kind;
  final LoadAdError rawError;
}

class _AdShell extends StatelessWidget {
  const _AdShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: child,
        ),
      ),
    );
  }
}

class _PromoUpgradeTile extends StatelessWidget {
  const _PromoUpgradeTile({
    this.onUpgradeTap,
    required this.isUpgradeEnabled,
    this.debugDiagnosticMessage,
  });

  final VoidCallback? onUpgradeTap;
  final bool isUpgradeEnabled;
  final String? debugDiagnosticMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _AdShell(
      child: Container(
        height: AdSize.banner.height.toDouble(),
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.workspace_premium_outlined,
                size: 18,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Free plan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  Text(
                    debugDiagnosticMessage ??
                        'Upgrade to remove this slot and unlock Pro.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: isUpgradeEnabled
                  ? (onUpgradeTap ?? _defaultUpgradeTap(context))
                  : null,
              child: const Text('Upgrade'),
            ),
          ],
        ),
      ),
    );
  }

  static VoidCallback _defaultUpgradeTap(BuildContext context) {
    return () {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const EntitlementPage()));
    };
  }
}
