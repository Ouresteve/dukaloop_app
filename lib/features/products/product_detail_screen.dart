import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import 'widgets/add_variant_sheet.dart';
import 'widgets/edit_variant_sheet.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Fresh variants every time this screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(productVariantsProvider(widget.product.id));
    });
  }

  Future<void> _openAddVariant() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddVariantSheet(product: widget.product),
    );
    // Refresh after sheet closes
    ref.invalidate(productVariantsProvider(widget.product.id));
    final shop = await ref.read(currentShopProvider.future);
    if (shop != null) {
      ref.invalidate(productsProvider(shop.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final variantsAsync = ref.watch(productVariantsProvider(product.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                _editProductName(context);
              } else if (value == 'delete') {
                _confirmDeleteProduct(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Product Name')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Product', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Variant / Restock',
            onPressed: _openAddVariant,
          ),
        ],
      ),
      body: variantsAsync.when(
        data: (variants) {
          if (variants.isEmpty) {
            return _buildEmptyVariants();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: variants.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final variant = variants[index];
              return _VariantCard(
                variant: variant,
                product: product,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildEmptyVariants() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.layers_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text(
            'No batches yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add sizes like 1kg, 500ml, pcs...',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openAddVariant,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add First Batch'),
          ),
        ],
      ),
    );
  }

  Future<void> _editProductName(BuildContext context) async {
    final product = widget.product;
    final controller = TextEditingController(text: product.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Product Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Product Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != product.name) {
      final service = ref.read(productServiceProvider);
      await service.updateProduct(product.copyWith(name: newName));

      final shop = await ref.read(currentShopProvider.future);
      if (shop != null) {
        ref.invalidate(productsProvider(shop.id));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product name updated'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _confirmDeleteProduct(BuildContext context) async {
    final product = widget.product;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text(
          'This will delete "${product.name}" and all its batches.\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(productServiceProvider);
      await service.deleteProduct(product.id);

      final shop = await ref.read(currentShopProvider.future);
      if (shop != null) {
        ref.invalidate(productsProvider(shop.id));
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted'), backgroundColor: AppColors.success),
        );
      }
    }
  }
}

class _VariantCard extends ConsumerWidget {
  final ProductVariant variant;
  final Product product;

  const _VariantCard({required this.variant, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  variant.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => EditVariantSheet(variant: variant, product: product),
                    );
                    ref.invalidate(productVariantsProvider(product.id));
                  } else if (value == 'delete') {
                    _confirmDeleteVariant(context, ref);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Stock: ${Formatters.number(variant.stockQuantity)}   •   Sell: ${Formatters.currency(variant.sellingPrice)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Total Cost: ${Formatters.currency(variant.costPrice)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (variant.expiryDate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Expires: ${variant.expiryDate}',
              style: const TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDeleteVariant(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Batch?'),
        content: Text('Delete batch "${variant.name}"?\nStock will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(productServiceProvider);
      await service.deleteVariant(variant.id);

      ref.invalidate(productVariantsProvider(product.id));
      final shop = await ref.read(currentShopProvider.future);
      if (shop != null) {
        ref.invalidate(productsProvider(shop.id));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Batch deleted'), backgroundColor: AppColors.success),
        );
      }
    }
  }
}