import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final Invoice invoice;

  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  ConsumerState<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _isReversing = false;

  Future<void> _reverseSale() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reverse this sale?'),
        content: const Text(
          'This will restore the stock and mark the invoice as reversed.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reverse'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isReversing = true);

    try {
      final service = ref.read(salesServiceProvider);
      await service.reverseSale(widget.invoice.id);

      // Refresh related data
      final shop = await ref.read(currentShopProvider.future);
      if (shop != null) {
        ref.invalidate(invoicesProvider(InvoiceFilter(shopId: shop.id, period: 'all')));
        ref.invalidate(productsProvider(shop.id));
        ref.invalidate(dashboardStatsProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale reversed successfully. Stock restored.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reverse: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReversing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final isDeni = invoice.status == 'deni' || invoice.balance > 0;
    final isReversed = invoice.status == 'reversed';

   final itemsAsync = ref.watch(invoiceItemsProvider(invoice.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(invoice.invoiceNumber),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _infoRow('Date', Formatters.dateTime(DateTime.parse(invoice.createdAt))),
                const Divider(height: 20),
                _infoRow(
                  'Status',
                  isReversed
                      ? 'Reversed'
                      : isDeni
                          ? 'Deni'
                          : 'Paid',
                  valueColor: isReversed
                      ? AppColors.textMuted
                      : isDeni
                          ? AppColors.danger
                          : AppColors.success,
                ),
                const Divider(height: 20),
                _infoRow('Total', Formatters.currency(invoice.totalAmount), isBold: true),
                if (isDeni && !isReversed) ...[
                  const Divider(height: 20),
                  _infoRow(
                    'Balance Owed',
                    Formatters.currency(invoice.balance),
                    valueColor: AppColors.danger,
                    isBold: true,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Items',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // Items
          itemsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No items found',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }

              return Column(
                children: items.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.productName} — ${item.variantName}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.quantity} × ${Formatters.currency(item.unitPrice)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          Formatters.currency(item.lineTotal),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error loading items: $e'),
          ),

          const SizedBox(height: 32),

          // Reverse button (only if not already reversed)
          if (!isReversed)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _isReversing ? null : _reverseSale,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                icon: _isReversing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.undo_rounded),
                label: Text(_isReversing ? 'Reversing...' : 'Reverse Sale'),
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}