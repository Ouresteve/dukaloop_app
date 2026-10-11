import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/providers.dart';
import 'widgets/debt_payment_sheet.dart';
import 'widgets/record_loss_sheet.dart';
import '../../core/widgets/skeleton.dart';
import '../../services/notification_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _period = 'today';


    @override
  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final shop = await ref.read(currentShopProvider.future);
    if (shop == null) return;

    await NotificationService.instance.checkLowStock(shop.id);

    final f = DashboardFilter(shopId: shop.id, period: _period);
    ref.invalidate(dashboardStatsProvider(f));
    ref.invalidate(topSellingProvider(shop.id));
    ref.invalidate(lowStockProvider(shop.id));
    ref.invalidate(nearExpiryProvider(shop.id));
  });
}

String _greeting(String ownerName) {
  final hour = DateTime.now().hour;
  final time = hour < 12
      ? 'Good morning'
      : hour < 17
          ? 'Good afternoon'
          : 'Good evening';
  return '$time, $ownerName';
}
  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(currentShopProvider);

    return Scaffold(
      body: shopAsync.when(
        data: (shop) {
          if (shop == null) return const Center(child: Text('No shop found'));

          final filter = DashboardFilter(shopId: shop.id, period: _period);
          final statsAsync = ref.watch(dashboardStatsProvider(filter));
          final topSellingAsync = ref.watch(topSellingProvider(shop.id));
          final lowStockAsync = ref.watch(lowStockProvider(shop.id));
          final nearExpiryAsync = ref.watch(nearExpiryProvider(shop.id));

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(dashboardStatsProvider(filter));
              ref.invalidate(topSellingProvider(shop.id));
              ref.invalidate(lowStockProvider(shop.id));
              ref.invalidate(nearExpiryProvider(shop.id));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header
                remainingSliver(
                  SliverAppBar(
                    floating: true,
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(

                              _greeting(shop.ownerName),
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                      ],
                    ),
                  ),
                ),

                // Period chips
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _periodChip('today', 'Today'),
                          const SizedBox(width: 8),
                          _periodChip('week', 'This Week'),
                          const SizedBox(width: 8),
                          _periodChip('month', 'This Month'),
                          const SizedBox(width: 8),
                          _periodChip('all', 'All Time'),
                        ],
                      ),
                    ),
                  ),
                ),

                // Stats
                SliverToBoxAdapter(
                  child: statsAsync.when(
                    data: (stats) => _buildStats(stats),
                    loading: () =>const StatsSkeleton(),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error: $e'),
                    ),
                  ),
                ),

                // Quick Actions
                SliverToBoxAdapter(child: _buildQuickActions()),

                // Most Selling
                SliverToBoxAdapter(
                  child: topSellingAsync.when(
                    data: (items) => _buildMostSelling(items),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),

                // Low Stock
                SliverToBoxAdapter(
                  child: lowStockAsync.when(
                    data: (items) => _buildLowStock(items),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
                // Near Expiry
                SliverToBoxAdapter(
                  child: nearExpiryAsync.when(
                  data: (items) => _buildNearExpiry(items),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
        loading: () =>const StatsSkeleton(),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget remainingSliver(Widget child) => child;

  Widget _periodChip(String value, String label) {
    final isSelected = _period == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _period = value),
      selectedColor: AppColors.primary.withOpacity(0.18),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
      ),
    );
  }

  Widget _buildStats(Map<String, dynamic> stats) {
  final revenue = (stats['total_revenue'] as num?)?.toDouble() ?? 0;
  final profit = (stats['total_profit'] as num?)?.toDouble() ?? 0;
  final sales = stats['total_sales'] as int? ?? 0;
  final deni = (stats['open_deni'] as num?)?.toDouble() ?? 0;
  final losses = (stats['loss_qty'] as num?)?.toDouble() ?? 0;
  final profitColor = profit >= 0 ? AppColors.success : AppColors.danger;

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Column(
      children: [
        // Hero — Profit
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                profitColor.withOpacity(0.18),
                AppColors.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: profitColor.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profit',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                Formatters.currency(profit),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: profitColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Revenue ${Formatters.currency(revenue)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Secondary metrics
        Row(
          children: [
            Expanded(child: _statCard('Sales', sales.toString(), AppColors.info)),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Deni', Formatters.currency(deni), AppColors.danger)),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                'Losses',
                '${Formatters.number(losses)} units',
                AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.payments_rounded,
                  label: 'Debt Payment',
                  color: AppColors.success,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const DebtPaymentSheet(),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionButton(
                  icon: Icons.report_problem_rounded,
                  label: 'Record Loss',
                  color: AppColors.warning,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const RecordLossSheet(),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMostSelling(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    final maxQty = items.map((e) => (e['total_qty'] as num).toDouble()).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Most Selling', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          ...items.map((item) {
            final qty = (item['total_qty'] as num).toDouble();
            final progress = maxQty == 0 ? 0.0 : qty / maxQty;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item['product_name']} — ${item['variant_name']}',
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${Formatters.number(qty)} sold',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceLight,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLowStock(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Low Stock',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.danger),
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item['product_name']} — ${item['variant_name']}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${item['stock_quantity']} left',
                    style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }


  Widget _buildNearExpiry(List<Map<String, dynamic>> items) {
  if (items.isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Near Expiry',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${item['product_name']} — ${item['variant_name']}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  'Exp: ${item['expiry_date']}',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );
}
}