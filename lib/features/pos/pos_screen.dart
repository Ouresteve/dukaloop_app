import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/services.dart';
import '../../database/database_helper.dart';
import '../../services/notification_service.dart';
import '../../services/analytics_service.dart' as fa;


class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
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
      await fa.AnalyticsService.instance.logSaleCompleted(
        value: total,
        itemCount: cart.length,
        isCredit: _isCredit,
      );

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
        if(mounted){
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


    /// Shows a modal bottom sheet that lets the user:
  ///   • search existing customers
  ///   • pick one for the Deni sale
  ///   • add a new customer on‑the‑fly
  Future<void> _showCustomerPicker() async {
    // We'll read the customer list from the provider each time we need it.
    final shop = await ref.read(currentShopProvider.future);
    if (shop == null) return;

    // Temporary controllers for the search field and the "add customer" form
    final searchCtrl = TextEditingController();
    final nameCtrl   = TextEditingController();
    final phoneCtrl  = TextEditingController();
    final emailCtrl  = TextEditingController();

    String _searchQuery = '';
    bool _isSearching   = false;
    List<Customer> _allCustomers = [];   // cached list
    List<Customer> _filtered = [];

    // Load all customers once (you can change to a debounced search if you prefer)
    void _loadCustomers() async {
      final List<Customer> loaded =
          await ref.read(customerServiceProvider).getAll(shop.id);
      setState(() {
        _allCustomers = loaded;
        _filtered     = loaded;
      });
    }

    // Call it when the sheet opens
    _loadCustomers();

    // Re‑filter whenever the search text changes
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

    // Show the bottom sheet
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ----- Header -----
                  const Center(
                    child: Text(
                      'Select Customer for Deni Sale',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ----- Search field -----
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
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (value) => _runSearch(value),
                  ),
                  const SizedBox(height: 16),

                  // ----- Customer list -----
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
                              height: 300, // fixed height so the sheet doesn’t grow forever
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
                                      // Choose this customer and close the sheet
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

                  // ----- Divider -----
                  const Divider(height: 1, color: AppColors.border),

                  const SizedBox(height: 16),

                  // ----- Quick‑Add Customer section -----
                  const Text(
                    'Or add a new customer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),

                  // Name
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Phone
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                      prefixIcon: Icon(Icons.phone_android_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Email
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
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
                        final newCust = Customer(
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
                           // .createCustomer(newCust);*/
                        // Select the newly created customer
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
          );
        },
      ),
    );

    // When the sheet closes, make sure the UI reflects the chosen customer
    if (_selectedCustomer != null && mounted) {
      setState(() {}); // rebuild to show the selected name
    }
  }

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
      resizeToAvoidBottomInset: true,
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
      body: Column(
  children: [
    // ==================== SEARCH ====================
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
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
    ),

    // ==================== SEARCH RESULTS ====================
    if (_searchResults.isNotEmpty)
      Flexible(
        flex: 0,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 160),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _searchResults.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _searchResults[index];
              return ListTile(
                dense: true,
                title: Text(
                  '${item['product_name']} — ${item['variant_name']}',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                subtitle: Text(
                  'Stock: ${item['stock_quantity']}  •  ${Formatters.currency(item['selling_price'])}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                onTap: () {
                  _addToCart(item);
                  FocusScope.of(context).unfocus();
                },
              );
            },
          ),
        ),
      ),

    const SizedBox(height: 6),

    // ==================== CART ====================
    Expanded(
      child: cart.isEmpty
          ? const Center(
              child: Text(
                'Cart is empty\nSearch and add products',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              itemCount: cart.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _CartItemTile(item: cart[index]);
              },
            ),
    ),

    // ==================== CHECKOUT (fixed bottom) ====================
    Material(
      elevation: 12,
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Total row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 15)),
                  Text(
                    Formatters.currency(total),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Amount Received
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Amount Received',
                  prefixIcon: Icon(Icons.payments_rounded, size: 20),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),

              // Change / Deni
              if (total > 0) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isCredit ? 'Deni (Credit)' : 'Change',
                      style: TextStyle(
                        fontSize: 13,
                        color: isCredit ? AppColors.danger : AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      Formatters.currency(isCredit ? balance : amountReceived - total),
                      style: TextStyle(
                        fontSize: 14,
                        color: isCredit ? AppColors.danger : AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],

              // Customer for Deni
              if (isCredit) ...[
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(Icons.person_rounded, color: AppColors.primary, size: 22),
                  title: Text(
                    _selectedCustomer?.name ?? 'Select Customer for Deni',
                    style: TextStyle(
                      fontSize: 13,
                      color: _selectedCustomer == null
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: _showCustomerPicker,
                ),
              ],

              const SizedBox(height: 10),

              // Complete button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _completeSale,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          isCredit ? 'COMPLETE DENI SALE' : 'COMPLETE SALE',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ],
),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  final CartItem item;

  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
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
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.currency(item.unitPrice),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded),
                onPressed: () {
                  ref.read(cartProvider.notifier).updateQuantity(
                        item.variantId,
                        item.quantity - 1,
                      );
                },
              ),
              Text(
                item.quantity.toStringAsFixed(0),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
  icon: const Icon(Icons.add_circle_outline_rounded),
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