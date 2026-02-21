import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/locale_service.dart';
import '../services/iap_service.dart';
import '../services/currency_service.dart';
import '../services/ad_service.dart';
import '../services/remote_config_service.dart';
import '../app/theme.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Подключаем начисление наград
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(iapServiceProvider.notifier).onReward = (productId, rewards) {
        final currency = ref.read(currencyServiceProvider.notifier);
        if (rewards.containsKey('diamonds')) {
          currency.addDiamonds(rewards['diamonds']!);
        }
        if (rewards.containsKey('tickets')) {
          currency.addTickets(rewards['tickets']!);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_rewardText(rewards)),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        }
      };
    });
  }

  String _rewardText(Map<String, int> rewards) {
    final parts = <String>[];
    if (rewards.containsKey('diamonds')) parts.add('+${rewards['diamonds']} 💎');
    if (rewards.containsKey('tickets')) parts.add('+${rewards['tickets']} ⚡');
    return parts.join(' ');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyServiceProvider);
    final iap = ref.watch(iapServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: title + currency
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text('Магазин',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  _CurrencyBadge(icon: '💎', value: currency.diamonds),
                  _CurrencyBadge(icon: '⚡', value: currency.tickets),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Inner tab bar
            TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 3,
              labelColor: Theme.of(context).colorScheme.onSurface,
              unselectedLabelColor: AppTheme.textMuted(context),
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 14),
              dividerHeight: 0,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: '💎 Алмазы'),
                Tab(text: '⚡ Билеты'),
                Tab(text: '👑 VIP'),
                Tab(text: '🎁 Акции'),
              ],
            ),
            // Tab content
            Expanded(
              child: iap.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // 💎 Алмазы
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _AdRewardCard(ref: ref),
                            const SizedBox(height: 12),
                            ..._buildDiamondCards(iap),
                          ],
                        ),
                        // ⚡ Билеты
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _ProductCard(
                              icon: '⚡',
                              title: ref.tr('tickets_n').replaceAll('{n}', '${ref.watch(remoteConfigProvider).iap.getReward(ProductIds.tickets5)['tickets'] ?? 5}'),
                              subtitle: ref.tr('read_no_wait'),
                              product: iap.products
                                  .where((p) => p.id == ProductIds.tickets5)
                                  .firstOrNull,
                              color: AppTheme.cyan,
                              onBuy: _buy,
                            ),
                          ],
                        ),
                        // 👑 VIP
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _VipCard(iap: iap, onBuy: _buy),
                          ],
                        ),
                        // 🎁 Акции
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (!iap.starterBundlePurchased) ...[
                              _StarterBundle(iap: iap, onBuy: _buy),
                              const SizedBox(height: 16),
                            ],
                            Center(
                              child: TextButton(
                                onPressed: () =>
                                    ref.read(iapServiceProvider.notifier).restorePurchases(),
                                child: Text(
                                  ref.tr('restore_purchases'),
                                  style: TextStyle(color: AppTheme.textMuted(context), fontSize: 12),
                                ),
                              ),
                            ),
                            if (iap.error != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                iap.error!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDiamondCards(IapState iap) {
    final configIap = ref.watch(remoteConfigProvider).iap;
    final items = <(String id, String icon, int amount, String? badge, Color color)>[
      (ProductIds.diamonds20, '💎', configIap.getReward(ProductIds.diamonds20)['diamonds'] ?? 20, null, const Color(0xFF9C27B0)),
      (ProductIds.diamonds60, '💎', configIap.getReward(ProductIds.diamonds60)['diamonds'] ?? 60, ref.tr('popular'), const Color(0xFFE91E63)),
      (ProductIds.diamonds150, '💎', configIap.getReward(ProductIds.diamonds150)['diamonds'] ?? 150, ref.tr('best_value'), const Color(0xFFFF5722)),
      (ProductIds.diamonds500, '💎', configIap.getReward(ProductIds.diamonds500)['diamonds'] ?? 500, ref.tr('best_price'), const Color(0xFFFF9800)),
    ];

    return items.map((item) {
      final product = iap.products.where((p) => p.id == item.$1).firstOrNull;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _ProductCard(
          icon: item.$2,
          title: ref.tr('diamonds_n').replaceAll('{n}', '${item.$3}'),
          subtitle: item.$4 ?? '',
          product: product,
          color: item.$5,
          onBuy: _buy,
        ),
      );
    }).toList();
  }

  void _buy(dynamic product) {
    if (product != null) {
      ref.read(iapServiceProvider.notifier).purchase(product as ProductDetails);
    }
  }
}

class _CurrencyBadge extends StatelessWidget {
  final String icon;
  final int value;
  const _CurrencyBadge({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text('$value',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StarterBundle extends ConsumerWidget {
  final IapState iap;
  final void Function(dynamic) onBuy;
  const _StarterBundle({required this.iap, required this.onBuy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configIap = ref.watch(remoteConfigProvider).iap;
    final starterRewards = configIap.getReward(ProductIds.starterBundle);
    final diamonds = starterRewards['diamonds'] ?? 100;
    final tickets = starterRewards['tickets'] ?? 10;
    final product =
        iap.products.where((p) => p.id == ProductIds.starterBundle).firstOrNull;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ref.tr('starter_kit'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Text('$diamonds 💎 + $tickets ⚡ — ${ref.tr('value_x').replaceAll('{n}', '10')}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              Text(
                ref.tr('starter_kit_once'),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: product != null ? () => onBuy(product) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFE91E63),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(product?.price ?? '\$0.99',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final dynamic product;
  final Color color;
  final void Function(dynamic) onBuy;

  const _ProductCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.product,
    required this.color,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: product != null ? () => onBuy(product) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              product?.price ?? '—',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _VipCard extends ConsumerStatefulWidget {
  final IapState iap;
  final void Function(dynamic) onBuy;
  const _VipCard({required this.iap, required this.onBuy});

  @override
  ConsumerState<_VipCard> createState() => _VipCardState();
}

class _VipCardState extends ConsumerState<_VipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product =
        widget.iap.products.where((p) => p.id == ProductIds.vipMonthly).firstOrNull;
    final vipConfig = ref.watch(remoteConfigProvider).vip;

    final perks = <Widget>[];
    if (vipConfig.dailyDiamonds > 0) {
      perks.add(_VipPerk(icon: '💎', text: ref.tr('vip_perk_diamonds').replaceAll('{n}', '${vipConfig.dailyDiamonds}')));
    }
    if (vipConfig.unlimitedTickets) {
      perks.add(_VipPerk(icon: '⚡', text: ref.tr('vip_perk_tickets')));
    }
    if (vipConfig.earlyAccess) {
      perks.add(_VipPerk(icon: '🔓', text: ref.tr('vip_perk_early_access')));
    }
    if (vipConfig.exclusiveFrame) {
      perks.add(_VipPerk(icon: '🖼️', text: ref.tr('vip_perk_frame')));
    }
    if (vipConfig.noAds) {
      perks.add(_VipPerk(icon: '🚫', text: ref.tr('vip_perk_no_ads')));
    }

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        final t = _shimmer.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 3.0 * t, -0.5),
              end: Alignment(-1.0 + 3.0 * t + 1.0, 0.5),
              colors: const [
                Color(0xFFFFD700),
                Color(0xFFE91E63),
                Color(0xFF9C27B0),
                Color(0xFFFFD700),
              ],
              tileMode: TileMode.mirror,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(2),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF283593)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Text(ref.tr('vip_subscription'),
                    style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...perks,
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: product != null ? () => widget.onBuy(product) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: const Color(0xFF1A237E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  product != null ? '${product.price} ${ref.tr('per_month')}' : '\$4.99 ${ref.tr('per_month')}',
                  style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VipPerk extends StatelessWidget {
  final String icon;
  final String text;
  const _VipPerk({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

class _AdRewardCard extends StatelessWidget {
  final WidgetRef ref;
  const _AdRewardCard({required this.ref});

  @override
  Widget build(BuildContext context) {
    final adService = ref.read(adServiceProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline,
              color: Color(0xFF00BCD4), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ref.tr('free_diamonds'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                Text(
                  '${ref.tr('watch_ad_reward').replaceAll('{n}', '${adService.diamondReward}')} (${adService.adsRemainingToday} ${ref.tr('remaining')})',
                  style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: adService.canShowAd
                ? () async {
                    final success = await adService.showRewardedAd(
                      rewardType: 'diamonds',
                      onReward: (_, amount) {
                        ref
                            .read(currencyServiceProvider.notifier)
                            .addDiamonds(amount);
                      },
                    );
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('+${adService.diamondReward} 💎!'),
                          backgroundColor: const Color(0xFF4CAF50),
                        ),
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BCD4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text('📺 ${ref.tr('watch_ad')}'),
          ),
        ],
      ),
    );
  }
}
