import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../providers/providers.dart';

class AddVariantSheet extends ConsumerStatefulWidget {
  final Product product;

  const AddVariantSheet({super.key, required this.product});

  @override
  ConsumerState<AddVariantSheet> createState() => _AddVariantSheetState();
}

class _AddVariantSheetState extends ConsumerState<AddVariantSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _sellingController = TextEditingController();
  final _costController = TextEditingController();
  final _qtyController = TextEditingController();
  final _expiryController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _sellingController.dispose();
    _costController.dispose();
    _qtyController.dispose();
    _expiryController.dispose();
    super.dispose();
  }


String _buyingPriceLabel() {
  final qty = double.tryParse(_qtyController.text.trim());
  final name = _nameController.text.trim();

  if (qty != null && qty > 0 && name.isNotEmpty) {
    return 'Total buying price of $qty $name';
  }
  if (qty != null && qty > 0) {
    return 'Total buying price of ${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)} units';
  }
  return 'Total buying price of this stock';
}

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(productServiceProvider);

      await service.restock(
        productId: widget.product.id,
        variantName: _nameController.text.trim(),
        sellingPrice: double.parse(_sellingController.text),
        costPrice: double.parse(_costController.text),
        quantity: double.parse(_qtyController.text),
        expiryDate: _expiryController.text.isEmpty ? null : _expiryController.text,
      );

      // Refresh data
      ref.invalidate(productVariantsProvider(widget.product.id));
      final shop = await ref.read(currentShopProvider.future);
      if (shop != null) {
        ref.invalidate(productsProvider(shop.id));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Variant saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      print ('Error saving variant: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
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
              // Handle bar
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

              Text(
                'Restock • ${widget.product.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add a new size or restock existing one',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Variant Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Variant (e.g. 1kg, 500ml, pcs)',
                  prefixIcon: Icon(Icons.straighten_rounded),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Selling price (per unit)
              TextFormField(
                controller: _sellingController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Selling price per unit',
                    prefixIcon: Icon(Icons.sell_rounded),
                ),
                validator: (v) =>
                v == null || double.tryParse(v) == null ? 'Required' : null,
              ),
const SizedBox(height: 16),

// Quantity first
TextFormField(
  controller: _qtyController,
  keyboardType: TextInputType.number,
  onChanged: (_) => setState(() {}), // refresh buying-price label
  decoration: const InputDecoration(
    labelText: 'Quantity (how many units)',
    hintText: 'e.g. 20',
    prefixIcon: Icon(Icons.numbers_rounded),
  ),
  validator: (v) =>
      v == null || double.tryParse(v) == null ? 'Required' : null,
),
const SizedBox(height: 16),

// Total buying price — full width, dynamic label
TextFormField(
  controller: _costController,
  keyboardType: TextInputType.number,
  decoration: InputDecoration(
    labelText: _buyingPriceLabel(),
    hintText: 'What you paid for this whole stock',
    prefixIcon: const Icon(Icons.shopping_cart_rounded),
  ),
  validator: (v) =>
      v == null || double.tryParse(v) == null ? 'Required' : null,
),
              const SizedBox(height: 16),

              // Expiry Date
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
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (date != null) {
                    _expiryController.text =
                        date.toIso8601String().split('T').first;
                  }
                },
              ),
              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('SAVE VARIANT'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}