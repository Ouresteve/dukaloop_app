// lib/services/services.dart

import '../database/database_helper.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';

class ShopService {
  final ShopRepository _repo = ShopRepository();

  Future<Shop?> getCurrentShop() => _repo.getShop();

  Future<Shop> createShop({
    required String name,
    required String ownerName,
    String? phone,
    String? location,
  }) async {
    final now = DatabaseHelper.now();
    final shop = Shop(
      id: DatabaseHelper.generateId(),
      name: name.trim(),
      ownerName: ownerName.trim(),
      phone: phone?.trim(),
      location: location?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _repo.createShop(shop);
    return shop;
  }

  Future<void> updateShop(Shop shop) async {
    final updated = shop.copyWith(updatedAt: DatabaseHelper.now());
    await _repo.updateShop(updated);
  }
}

class ProductService {
  final ProductRepository _repo = ProductRepository();

  Future<List<Product>> getAllProducts(String shopId) {
    return _repo.getAll(shopId);
  }

  Future<Product> createProduct({
    required String shopId,
    required String name,
    String? categoryId,
    String? description,
  }) async {
    final now = DatabaseHelper.now();
    final product = Product(
      id: DatabaseHelper.generateId(),
      shopId: shopId,
      categoryId: categoryId,
      name: name.trim(),
      description: description?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _repo.create(product);
    return product;
  }

  Future<void> updateProduct(Product product) async {
    final updated = product.copyWith(updatedAt: DatabaseHelper.now());
    await _repo.update(updated);
  }

  Future<void> deleteProduct(String productId) async {
    await _repo.softDelete(productId);
  }

  // ========== VARIANTS / RESTOCK ==========

  Future<List<ProductVariant>> getVariants(String productId) {
    return _repo.getVariants(productId);
  }

  Future<ProductVariant> restock({
    required String productId,
    required String variantName,
    required double costPrice,
    required double sellingPrice,
    required double quantity,
    
    String? expiryDate,
    String? batchNumber,
    String? sku,
  }) async  {
    final now = DatabaseHelper.now();

    // Check if a variant with the same name already exists
    /*final existing = await _repo.getVariants(productId);
    final match = existing.where((v) => v.name.toLowerCase() == variantName.toLowerCase()).toList();

    if (match.isNotEmpty) {
      // Update existing variant (add stock)
      final variant = match.first;
      final updated = variant.copyWith(
        stockQuantity: variant.stockQuantity + quantity,
        costPrice:  variant.costPrice + costPrice, // latest total cost added to the variant initial total cost
        sellingPrice: sellingPrice,
        expiryDate: expiryDate ?? variant.expiryDate,
        batchNumber: batchNumber ?? variant.batchNumber,
        updatedAt: now,
      );
      await _repo.updateVariant(updated);

      // Record stock movement
      await _recordStockMovement(
        variantId: variant.id,
        type: 'restock',
        quantity: quantity,
        notes: 'Restock',
      );

     return updated; 
    } else{*/
      // Create new variant
      final unitCost = quantity > 0 ? costPrice / quantity : 0.0;
      final variant = ProductVariant(
        id: DatabaseHelper.generateId(),
        productId: productId,
        name: variantName.trim(),
        sku: sku?.trim(),
        unitCost: unitCost,
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        stockQuantity: quantity,
        expiryDate: expiryDate,
        batchNumber: batchNumber,
        createdAt: now,
        updatedAt: now,
      );
      await _repo.createVariant(variant);

      await _recordStockMovement(
        variantId: variant.id,
        type: 'restock',
        quantity: quantity,
        notes: 'Initial stock',
      );

      return variant;
   // }
  }

  Future<void> updateVariant(ProductVariant variant) async {
    final updated = variant.copyWith(updatedAt: DatabaseHelper.now());
    await _repo.updateVariant(updated);
  }

  Future<void> deleteVariant(String variantId) async {
    await _repo.softDeleteVariant(variantId);
  }

  Future<List<Map<String, dynamic>>> searchForSale(String shopId, String query) {
    return _repo.searchForSale(shopId, query);
  }

  Future<void> _recordStockMovement({
    required String variantId,
    required String type,
    required double quantity,
    String? referenceId,
    String? notes,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('stock_movements', {
      'id': DatabaseHelper.generateId(),
      'variant_id': variantId,
      'type': type,
      'quantity': quantity,
      'reference_id': referenceId,
      'notes': notes,
      'created_at': DatabaseHelper.now(),
    });
  }
}

class CustomerService {
  final CustomerRepository _repo = CustomerRepository();

  Future<List<Customer>> getAll(String shopId) => _repo.getAll(shopId);

  Future<Customer> createCustomer({
    required String shopId,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  
  }) async {
    final now = DatabaseHelper.now();
    final customer = Customer(
      id: DatabaseHelper.generateId(),
      shopId: shopId,
      name: name.trim(),
      phone: phone?.trim(),
      email: email?.trim(),
      address: address?.trim(),
      notes: notes?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _repo.create(customer);
    return customer;
  }

  Future<void> updateCustomer(Customer customer) async {
    final updated = customer.copyWith(updatedAt: DatabaseHelper.now());
    await _repo.update(updated);
  }

  Future<void> deleteCustomer(String id) async {
    await _repo.softDelete(id);
  }
}

class SalesService {
  final InvoiceRepository _invoiceRepo = InvoiceRepository();
  final ProductRepository _productRepo = ProductRepository();
  final CustomerRepository _customerRepo = CustomerRepository();

  /// Generate next human-friendly invoice number (e.g. INV-2026-0001)
  Future<String> generateInvoiceNumber(String shopId) async {
    final db = await DatabaseHelper.instance.database;
    final year = DateTime.now().year;

    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM invoices 
      WHERE shop_id = ? AND strftime('%Y', created_at) = ?
    ''', [shopId, year.toString()]);

    final count = (result.first['count'] as int? ?? 0) + 1;
    return 'INV-$year-${count.toString().padLeft(4, '0')}';
  }

  /// Main method to complete a sale
  Future<Invoice> completeSale({
    required String shopId,
    required List<CartItem> cartItems,
    String? customerId,
    required double amountReceived,
    String paymentMethod = 'cash',
    bool generateReceipt = true,
    String? notes,
  }) async {
    if (cartItems.isEmpty) {
      throw Exception('Cart is empty');
    }

    final now = DatabaseHelper.now();
    final invoiceId = DatabaseHelper.generateId();
    final invoiceNumber = await generateInvoiceNumber(shopId);

    double totalAmount = 0;
    final List<InvoiceItem> items = [];

    for (final cartItem in cartItems) {
      final lineTotal = cartItem.unitPrice * cartItem.quantity;
      totalAmount += lineTotal;

      items.add(InvoiceItem(
        id: DatabaseHelper.generateId(),
        invoiceId: invoiceId,
        productId: cartItem.productId,
        variantId: cartItem.variantId,
        productName: cartItem.productName,
        variantName: cartItem.variantName,
        quantity: cartItem.quantity,
        unitPrice: cartItem.unitPrice,
        costPrice: cartItem.costPrice,
        lineTotal: lineTotal,
        createdAt: now,
      ));
    }

    final balance = totalAmount - amountReceived;
    final isCredit = balance > 0.01; // allow small floating point tolerance

    if (isCredit && (customerId == null || customerId.isEmpty)) {
      throw Exception('Customer is required for credit (deni) sales');
    }

    final status = isCredit ? 'deni' : 'paid';

    final invoice = Invoice(
      id: invoiceId,
      shopId: shopId,
      customerId: customerId,
      invoiceNumber: invoiceNumber,
      totalAmount: totalAmount,
      amountPaid: amountReceived,
      balance: isCredit ? balance : 0,
      status: status,
      paymentMethod: paymentMethod,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );

    final payments = <Payment>[];
    if (amountReceived > 0) {
      payments.add(Payment(
        id: DatabaseHelper.generateId(),
        invoiceId: invoiceId,
        amount: amountReceived,
        method: paymentMethod,
        createdAt: now,
      ));
    }

    Debt? debt;
    if (isCredit) {
      debt = Debt(
        id: DatabaseHelper.generateId(),
        shopId: shopId,
        customerId: customerId!,
        invoiceId: invoiceId,
        amount: balance,
        amountPaid: 0,
        balance: balance,
        status: 'open',
        createdAt: now,
        updatedAt: now,
      );
    }

    await _invoiceRepo.createSale(
      invoice: invoice,
      items: items,
      payments: payments,
      debt: debt,
    );

    return invoice;
  }

  Future<void> reverseSale(String invoiceId, {String? reason}) async {
    await _invoiceRepo.reverseInvoice(invoiceId, reason: reason);
  }

  Future<List<Invoice>> getInvoices(
    String shopId, {
    String? status,
    DateTime? from,
    DateTime? to,
  }) {
    return _invoiceRepo.getAll(shopId, status: status, from: from, to: to);
  }

  Future<Invoice?> getInvoice(String id) => _invoiceRepo.getById(id);

  Future<List<InvoiceItem>> getInvoiceItems(String invoiceId) {
    return _invoiceRepo.getItems(invoiceId);
  }


/// Record a debt repayment
Future<void> recordDebtPayment({
  required String debtId,
  required String customerId,
  required double amount,
  String method = 'cash',
  String? notes,
}) async {
  final db = await DatabaseHelper.instance.database;
  final now = DatabaseHelper.now();

  await db.transaction((txn) async {
    // Update debt
    final debtMaps = await txn.query('debts', where: 'id = ?', whereArgs: [debtId]);
    if (debtMaps.isEmpty) throw Exception('Debt not found');

    final debt = Debt.fromMap(debtMaps.first);
    final newPaid = debt.amountPaid + amount;
    final newBalance = debt.amount - newPaid;
    final newStatus = newBalance <= 0 ? 'settled' : 'partial';

    await txn.update(
      'debts',
      {
        'amount_paid': newPaid,
        'balance': newBalance < 0 ? 0 : newBalance,
        'status': newStatus,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [debtId],
    );

    // Reduce customer total debt
    await txn.rawUpdate('''
      UPDATE customers 
      SET total_debt = MAX(0, total_debt - ?), updated_at = ?
      WHERE id = ?
    ''', [amount, now, customerId]);

    // Optional: record as payment
    await txn.insert('payments', {
      'id': DatabaseHelper.generateId(),
      'invoice_id': debt.invoiceId ?? '',
      'amount': amount,
      'method': method,
      'notes': notes ?? 'Debt repayment',
      'created_at': now,
    });
  });
}

/// Record stock loss / damage
Future<void> recordLoss({
  required String variantId,
  required double quantity,
  required String reason,
}) async {
  final db = await DatabaseHelper.instance.database;
  final now = DatabaseHelper.now();

  await db.transaction((txn) async {
    // Reduce stock
    await txn.rawUpdate('''
      UPDATE product_variants 
      SET stock_quantity = stock_quantity - ?, updated_at = ?
      WHERE id = ?
    ''', [quantity, now, variantId]);

    // Record movement
    await txn.insert('stock_movements', {
      'id': DatabaseHelper.generateId(),
      'variant_id': variantId,
      'type': 'damage',
      'quantity': -quantity,
      'notes': reason,
      'created_at': now,
    });
  });
}

}
class CartItem {
  final String productId;
  final String variantId;
  final String productName;
  final String variantName;
  final double unitPrice;
  final double costPrice;
  final double quantity;
  final double availableStock; // ← new field

  const CartItem({
    required this.productId,
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.unitPrice,
    required this.costPrice,
    required this.quantity,
    required this.availableStock,
  });

  double get lineTotal => unitPrice * quantity;

  CartItem copyWith({double? quantity}) {
    return CartItem(
      productId: productId,
      variantId: variantId,
      productName: productName,
      variantName: variantName,
      unitPrice: unitPrice,
      costPrice: costPrice,
      quantity: quantity ?? this.quantity,
      availableStock: availableStock,
    );
  }
}

class AnalyticsService {
  final AnalyticsRepository _repo = AnalyticsRepository();

  Future<Map<String, dynamic>> getDashboard({
    required String shopId,
    DateTime? from,
    DateTime? to,
  }) {
    return _repo.getDashboardStats(shopId, from: from, to: to);
  }

  Future<List<Map<String, dynamic>>> getTopSelling(String shopId) {
    return _repo.getTopSelling(shopId);
  }

  Future<List<Map<String, dynamic>>> getLowStock(String shopId) {
    return _repo.getLowStock(shopId);
  }

  Future<List<Map<String, dynamic>>> getNearExpiry(String shopId) {
    return _repo.getNearExpiry(shopId); 
  }
}