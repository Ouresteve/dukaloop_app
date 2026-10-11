// lib/providers/providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

// ====================== SERVICES ======================

final shopServiceProvider = Provider<ShopService>((ref) {
  return ShopService();
});

final productServiceProvider = Provider<ProductService>((ref) {
  return ProductService();
});

final customerServiceProvider = Provider<CustomerService>((ref) {
  return CustomerService();
});

final salesServiceProvider = Provider<SalesService>((ref) {
  return SalesService();
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

// ====================== SHOP ======================

final currentShopProvider = FutureProvider<Shop?>((ref) async {
  final service = ref.watch(shopServiceProvider);
  return service.getCurrentShop();
});

// ====================== PRODUCTS ======================

final productsProvider = FutureProvider.family<List<Product>, String>((ref, shopId) async {
  final service = ref.watch(productServiceProvider);
  return service.getAllProducts(shopId);
});

final productVariantsProvider = FutureProvider.family<List<ProductVariant>, String>((ref, productId) async {
  final service = ref.watch(productServiceProvider);
  return service.getVariants(productId);
});

// ====================== CUSTOMERS ======================

final customersProvider = FutureProvider.family<List<Customer>, String>((ref, shopId) async {
  final service = ref.watch(customerServiceProvider);
  return service.getAll(shopId);
});

// ====================== INVOICES / SALES ======================

class InvoiceFilter {
  final String shopId;
  final String period; // all | today | week | month | deni

  const InvoiceFilter({
    required this.shopId,
    required this.period,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceFilter &&
          runtimeType == other.runtimeType &&
          shopId == other.shopId &&
          period == other.period;

  @override
  int get hashCode => Object.hash(shopId, period);
}

final invoiceItemsProvider = FutureProvider.family<List<InvoiceItem>, String>((ref, invoiceId) {
  return ref.watch(salesServiceProvider).getInvoiceItems(invoiceId);
});

final invoicesProvider = FutureProvider.family<List<Invoice>, InvoiceFilter>((ref, filter) async {
  final service = ref.watch(salesServiceProvider);

  final now = DateTime.now();
  DateTime? from;
  String? status;

  switch (filter.period) {
    case 'today':
      from = DateTime(now.year, now.month, now.day);
      break;
    case 'week':
      from = now.subtract(Duration(days: now.weekday - 1));
      from = DateTime(from.year, from.month, from.day);
      break;
    case 'month':
      from = DateTime(now.year, now.month, 1);
      break;
    case 'deni':
      status = 'deni';
      from = null;
      break;
    case 'all':
    default:
      from = null;
  }

  return service.getInvoices(
    filter.shopId,
    status: status,
    from: from,
    to: now,
  );
});
// ====================== CART (POS) ======================

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(CartItem item) {
    final index = state.indexWhere((e) => e.variantId == item.variantId);

    if (index >= 0) {
      // Item already in cart → increase quantity
      final existing = state[index];
      final updated = existing.copyWith(quantity: existing.quantity + item.quantity);
      state = [...state]..[index] = updated;
    } else {
      state = [...state, item];
    }
  }

  void updateQuantity(String variantId, double quantity) {
    if (quantity <= 0) {
      removeItem(variantId);
      return;
    }

    state = [
      for (final item in state)
        if (item.variantId == variantId) item.copyWith(quantity: quantity) else item
    ];
  }

  void removeItem(String variantId) {
    state = state.where((item) => item.variantId != variantId).toList();
  }

  void clear() {
    state = [];
  }

  double get total => state.fold(0, (sum, item) => sum + item.lineTotal);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.lineTotal);
});

// ====================== ANALYTICS ======================

class DashboardFilter {
  final String shopId;
  final String period; // 'today' | 'week' | 'month' | 'all'

  const DashboardFilter({
    required this.shopId,
    required this.period,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DashboardFilter &&
          runtimeType == other.runtimeType &&
          shopId == other.shopId &&
          period == other.period;

  @override
  int get hashCode => Object.hash(shopId, period);
}
final dashboardStatsProvider = FutureProvider.family<Map<String, dynamic>, DashboardFilter>((ref, filter) async {
  final service = ref.watch(analyticsServiceProvider);

  DateTime? from;
  final now = DateTime.now();

  switch (filter.period) {
    case 'today':
      from = DateTime(now.year, now.month, now.day);
      break;
    case 'week':
      from = now.subtract(Duration(days: now.weekday - 1));
      from = DateTime(from.year, from.month, from.day);
      break;
    case 'month':
      from = DateTime(now.year, now.month, 1);
      break;
    case 'all':
    default:
      from = null;
  }

  return service.getDashboard(shopId: filter.shopId, from: from, to: now);
});

final topSellingProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, shopId) {
  return ref.watch(analyticsServiceProvider).getTopSelling(shopId);
});

final lowStockProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, shopId) {
  return ref.watch(analyticsServiceProvider).getLowStock(shopId);
});

final nearExpiryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, shopId) {
  return ref.watch(analyticsServiceProvider).getNearExpiry(shopId);
});
