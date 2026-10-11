import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class EditVariantSheet extends ConsumerStatefulWidget {
  final ProductVariant variant;
  final Product product;

  const EditVariantSheet({
    super.key,
    required this.variant,
    required this.product,
  });

  @override
  ConsumerState<EditVariantSheet> createState() => _EditVariantSheetState();
}

class _EditVariantSheetState extends ConsumerState<EditVariantSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _sellingController;
  late final TextEditingController _costController;
  late final TextEditingController _qtyController;
  late final TextEditingController _expiryController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.variant.name);
    _sellingController = TextEditingController(text: widget.variant.sellingPrice.toString());
    _costController = TextEditingController(text: widget.variant.costPrice.toString());
    _qtyController = TextEditingController(text: widget.variant.stockQuantity.toString());
    _expiryController = TextEditingController(text: widget.variant.expiryDate ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sellingController.dispose();
    _costController.dispose();
    _qtyController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(productServiceProvider);

      final updated = widget.variant.copyWith(
        name: _nameController.text.trim(),
        sellingPrice: double.parse(_sellingController.text),
        costPrice: double.parse(_costController.text),
        stockQuantity: double.parse(_qtyController.text),
        expiryDate: _expiryController.text.isEmpty ? null : _expiryController.text,
      );

      await service.updateVariant(updated);

      ref.invalidate(productVariantsProvider(widget.product.id));
      final shop = await ref.read(currentShopProvider.future);
      if (shop != null) {
        ref.invalidate(productsProvider(shop.id));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Batch updated'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
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
              const SizedBox(height: 20),
              const Text(
                'Edit Batch',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Variant Name',
                  prefixIcon: Icon(Icons.straighten_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sellingController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Selling Price',
                        prefixIcon: Icon(Icons.sell_rounded),
                      ),
                      validator: (v) => v == null || double.tryParse(v) == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Buying Price',
                        prefixIcon: Icon(Icons.shopping_cart_rounded),
                      ),
                      validator: (v) => v == null || double.tryParse(v) == null ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stock Quantity',
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
                validator: (v) => v == null || double.tryParse(v) == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _expiryController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Expiry Date (Optional)',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (date != null) {
                    _expiryController.text = date.toIso8601String().split('T').first;
                  }
                },
              ),
              const SizedBox(height: 28),

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('SAVE CHANGES'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}