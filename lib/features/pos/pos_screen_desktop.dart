import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import 'dart:math' as Math;
import '../../services/notification_service.dart';

class PosScreenDesktop extends ConsumerStatefulWidget {
  const PosScreenDesktop({super.key});

  @override
  ConsumerState<PosScreenDesktop> createState() => _PosScreenDesktopState();
}

class _PosScreenDesktopState extends ConsumerState<PosScreenDesktop> {
  final _searchController = TextEditingController();
  final _amountController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isProcessing = false;

  Customer? _selectedCustomer;
  bool _isCredit = false;

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final shop = await ref.read(currentShopProvider.future);
      if (shop == null) return;

      final results = await ref.read(productServiceProvider).searchForSale(shop.id, query);
      setState(() => _searchResults = results);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _addToCart(Map<String, dynamic> item) {
    final cartNotifier = ref.read(cartProvider.notifier);
final unitCost = (item['unit_cost'] as num?)?.toDouble();
final costPrice = (item['cost_price'] as num?)?.toDouble() ?? 0;
final stockQty = (item['stock_quantity'] as num?)?.toDouble() ?? 0;

final resolvedUnitCost = unitCost ??
    (stockQty > 0 ? costPrice / stockQty : 0.0);

final cartItem = CartItem(
  productId: item['product_id'] as String,
  variantId: item['variant_id'] as String,
  productName: item['product_name'] as String,
  variantName: item['variant_name'] as String,
  unitPrice: (item['selling_price'] as num).toDouble(),
  costPrice: resolvedUnitCost,
  quantity: 1,
  availableStock: stockQty,
);
    // Prevent adding the same batch twice
    final exists = ref.read(cartProvider).any((c) => c.variantId == cartItem.variantId);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This batch is already in the cart')),
      );
      return;
    }

    cartNotifier.addItem(cartItem);
    _searchController.clear();
    setState(() => _searchResults = []);
  }

  Future<void> _completeSale() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    final amountReceived = double.tryParse(_amountController.text) ?? 0;
    final total = ref.read(cartTotalProvider);

    if (amountReceived <= 0 && !_isCredit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter amount received')),
      );
      return;
    }

    if (amountReceived < total && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a customer for credit (Deni) sale')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final shop = await ref.read(currentShopProvider.future);
      if (shop == null) throw Exception('No shop found');

      final salesService = ref.read(salesServiceProvider);

      final invoice = await salesService.completeSale(
        shopId: shop.id,
        cartItems: cart,
        customerId: _selectedCustomer?.id,
        amountReceived: amountReceived,
        paymentMethod: 'cash',
      );

      // Clear cart
      ref.read(cartProvider.notifier).clear();
      _amountController.clear();
      setState(() {
        _selectedCustomer = null;
        _isCredit = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sale completed • ${invoice.invoiceNumber}'),
            backgroundColor: AppColors.success,
          ),
        );
        await NotificationService.instance.checkLowStock(shop.id);
        ref.invalidate(productVariantsProvider(shop.id));
        ref.invalidate(productsProvider(shop.id));

        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(topSellingProvider(shop.id));
        ref.invalidate(lowStockProvider(shop.id));
        ref.invalidate(nearExpiryProvider(shop.id));
        if (mounted) {
          Navigator.pop(context);
        }
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


  /// Desktop version: shows a dialog (full‑width on narrow screens) for
  /// picking or adding a customer.
  Future<void> _showCustomerPickerDialog() async {
    final shop = await ref.read(currentShopProvider.future);
    if (shop == null) return;

    final searchCtrl = TextEditingController();
    final nameCtrl   = TextEditingController();
    final phoneCtrl  = TextEditingController();
    final emailCtrl  = TextEditingController();

    String _searchQuery = '';
    bool _isSearching   = false;
    List<Customer> _allCustomers = [];
    List<Customer> _filtered = [];

    void _loadCustomers() async {
      final List<Customer> loaded =
          await ref.read(customerServiceProvider).getAll(shop.id);
      setState(() {
        _allCustomers = loaded;
        _filtered     = loaded;
      });
    }

    void _runSearch(String query) {
      setState(() {
        _isSearching = true;
        _searchQuery = query.toLowerCase();
        if (_searchQuery.isEmpty) {
          _filtered = List.from(_allCustomers);
        } else {
          _filtered = _allCustomers
              .where((c) =>
                  c.name.toLowerCase().contains(_searchQuery) ||
                  (c.phone ?? '').toLowerCase().contains(_searchQuery))
              .toList();
        }
        _isSearching = false;
      });
    }

    _loadCustomers();

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext dialogContext, StateSetter setState) {
          return AlertDialog(
            title: const Text('Select Customer for Deni Sale'),
            content: SizedBox(
              width: Math.min(420, MediaQuery.of(context).size.width * 0.9),
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search by name or phone',
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      onChanged: (value) => _runSearch(value),
                    ),
                    const SizedBox(height: 16),

                    // Customer list
                    _isSearching
                        ? const Center(child: CircularProgressIndicator())
                        : _filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No customers found',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              )
                            : SizedBox(
                                height: 300,
                                child: ListView.separated(
                                  padding: EdgeInsets.zero,
                                  itemCount: _filtered.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (_, index) {
                                    final cust = _filtered[index];
                                    return ListTile(
                                      leading: const Icon(Icons.person_rounded,
                                          color: AppColors.primary),
                                      title: Text(cust.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                          '${cust.phone ?? 'No phone'}  •  '
                                          'Debt: ${Formatters.currency(cust.totalDebt)}',
                                          style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12)),
                                      onTap: () {
                                        setState(() {
                                          _selectedCustomer = cust;
                                        });
                                        Navigator.of(ctx).pop();
                                      },
                                    );
                                  },
                                ),
                              ),

                    const SizedBox(height: 24),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 16),

                    // Quick‑Add
                    const Text(
                      'Or add a new customer',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone (optional)',
                        prefixIcon: Icon(Icons.phone_android_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (optional)',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Name is required'),
                                  backgroundColor: AppColors.danger),
                            );
                            return;
                          }
                          final service = ref.read(customerServiceProvider);
                          
                           final newCust = await service.createCustomer(
                          shopId: shop.id,
                          name: name,
                          phone: phoneCtrl.text.trim().isEmpty
                              ? null
                              : phoneCtrl.text.trim(),
                          email: emailCtrl.text.trim().isEmpty
                              ? null
                              : emailCtrl.text.trim(),
                          
                        
              
                        );
                          
                          /*
                          Customer(
                            id: DatabaseHelper.generateId(),
                            shopId: shop.id,
                            name: name,
                            phone: phoneCtrl.text.trim().isEmpty
                                ? null
                                : phoneCtrl.text.trim(),
                            email: emailCtrl.text.trim().isEmpty
                                ? null
                                : emailCtrl.text.trim(),
                            totalDebt: 0,
                            isActive: true,
                            createdAt: DatabaseHelper.now(),
                            updatedAt: DatabaseHelper.now(),
                          );
                          await ref
                              .read(customerServiceProvider)
                              .createCustomer(newCust);*/
                          setState(() {
                            _selectedCustomer = newCust;
                          });
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('SAVE CUSTOMER'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
    // After dialog closes, rebuild UI to show selected

  

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final amountReceived = double.tryParse(_amountController.text) ?? 0;
    final balance = total - amountReceived;
    final isCredit = balance > 0.01;

    // Keep local state in sync
    if (isCredit != _isCredit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _isCredit = isCredit);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (cart.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(cartProvider.notifier).clear(),
              child: const Text('Clear', style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left panel: Search + Search Results
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Search
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _search,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search product or variant...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 24),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),

                // Search Results
                if (_searchResults.isNotEmpty)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return ListTile(
                            title: Text(
                              '${item['product_name']} — ${item['variant_name']}',
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                            ),
                            subtitle: Text(
                              'Stock: ${item['stock_quantity']}  •  ${Formatters.currency(item['selling_price'])}',
                            ),
                            trailing: const Icon(Icons.add_circle_outline_rounded, size: 28, color: AppColors.primary),
                            onTap: () {
                              _addToCart(item);
                              FocusScope.of(context).unfocus();
                            },
                          );
                        },
                      ),
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // Vertical divider
          Container(
            width: 1,
            color: AppColors.border,
          ),

          // Right panel: Cart + Checkout
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Cart
                Expanded(
                  child: cart.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Cart is empty\nSearch and add products',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: cart.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = cart[index];
                            return _CartItemTileDesktop(item: item);
                          },
                        ),
                ),

                // Checkout Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontSize: 18)),
                            Text(
                              Formatters.currency(total),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Amount Received
                        TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 16),
                          decoration: const InputDecoration(
                            labelText: 'Amount Received',
                            prefixIcon: Icon(Icons.payments_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Balance / Deni info
                        if (total > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isCredit ? 'Deni (Credit)' : 'Change',
                                style: TextStyle(
                                  color: isCredit ? AppColors.danger : AppColors.success,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                Formatters.currency(isCredit ? balance : amountReceived - total),
                                style: TextStyle(
                                  color: isCredit ? AppColors.danger : AppColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),

                        if (isCredit) ...[
                          const SizedBox(height: 12),
                          // Simple customer selector (temporary)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_rounded, color: AppColors.primary),
                            title: Text(
                              _selectedCustomer?.name ?? 'Select Customer for Deni',
                              style: TextStyle(
                                color: _selectedCustomer == null ? AppColors.textMuted : AppColors.textPrimary,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              _showCustomerPickerDialog();
                              
                            },
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Complete Sale Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _completeSale,
                            style: ElevatedButton.styleFrom(
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            child: _isProcessing
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : Text(isCredit ? 'COMPLETE DENI SALE' : 'COMPLETE SALE'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemTileDesktop extends ConsumerWidget {
  final CartItem item;

  const _CartItemTileDesktop({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.currency(item.unitPrice),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 28),
                onPressed: () {
                  ref.read(cartProvider.notifier).updateQuantity(
                        item.variantId,
                        item.quantity - 1,
                      );
                },
              ),
              Text(
                item.quantity.toStringAsFixed(0),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
                onPressed: () {
                  if (item.quantity + 1 > item.availableStock) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Only ${item.availableStock.toStringAsFixed(0)} left in this batch'),
                        backgroundColor: AppColors.danger,
                      ),
                    );
                    return;
                  }
                  ref.read(cartProvider.notifier).updateQuantity(
                        item.variantId,
                        item.quantity + 1,
                      );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
