import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/providers.dart';
import '../../../services/services.dart';
import '../../../services/analytics_service.dart' as fa;

class RecordLossSheet extends ConsumerStatefulWidget {
  const RecordLossSheet({super.key});

  @override
  ConsumerState<RecordLossSheet> createState() => _RecordLossSheetState();
}

class _RecordLossSheetState extends ConsumerState<RecordLossSheet> {
  final _searchController = TextEditingController();
  final _qtyController = TextEditingController();
  final _reasonController = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selected;
  bool _isSearching = false;
  bool _isProcessing = false;

  @override
  void dispose() {
    _searchController.dispose();
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final shop = await ref.read(currentShopProvider.future);
      if (shop == null) return;

      final results = await ref.read(productServiceProvider).searchForSale(shop.id, query);
      setState(() => _results = results);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _submit() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an item first')),
      );
      return;
    }

    final qty = double.tryParse(_qtyController.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }

    final available = (_selected!['stock_quantity'] as num).toDouble();
    if (qty > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only ${available.toStringAsFixed(0)} available')),
      );
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final service = ref.read(salesServiceProvider);
      await service.recordLoss(
        variantId: _selected!['variant_id'] as String,
        quantity: qty,
        reason: reason,
      );
      await fa.AnalyticsService.instance.logLossRecorded(quantity: qty);
      // Refresh
      final shop = await ref.read(currentShopProvider.future);
      if (shop != null) {
        ref.invalidate(productsProvider(shop.id));
        ref.invalidate(dashboardStatsProvider);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loss recorded successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Record Loss / Damage',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Search
            TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search product or variant...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),

            // Results
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    final isSelected = _selected?['variant_id'] == item['variant_id'];

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: AppColors.primary.withOpacity(0.1),
                      title: Text(
                        '${item['product_name']} — ${item['variant_name']}',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                      subtitle: Text('Stock: ${item['stock_quantity']}'),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selected = item;
                          _results = [];
                          _searchController.text =
                              '${item['product_name']} — ${item['variant_name']}';
                        });
                      },
                    );
                  },
                ),
              ),
            ],

            if (_selected != null) ...[
              const SizedBox(height: 16),
              Text(
                'Selected: ${_selected!['product_name']} — ${_selected!['variant_name']}',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity Lost',
                  prefixIcon: const Icon(Icons.numbers_rounded),
                  helperText: 'Available: ${_selected!['stock_quantity']}',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason (e.g. damaged, expired, stolen)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('RECORD LOSS'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}