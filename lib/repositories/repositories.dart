// lib/repositories/repositories.dart

import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class ShopRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Shop?> getShop() async {
    final db = await _dbHelper.database;
    final maps = await db.query('shops', limit: 1);
    if (maps.isEmpty) return null;
    return Shop.fromMap(maps.first);
  }

  Future<void> createShop(Shop shop) async {
    final db = await _dbHelper.database;
    await db.insert('shops', shop.toMap());
  }

  Future<void> updateShop(Shop shop) async {
    final db = await _dbHelper.database;
    await db.update(
      'shops',
      shop.toMap(),
      where: 'id = ?',
      whereArgs: [shop.id],
    );
  }
}

class CategoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Category>> getAll(String shopId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'categories',
      where: 'shop_id = ?',
      whereArgs: [shopId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<void> create(Category category) async {
    final db = await _dbHelper.database;
    await db.insert('categories', category.toMap());
  }

  Future<void> update(Category category) async {
    final db = await _dbHelper.database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}

class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Returns products with calculated totals (stock, cost, expected return)
  Future<List<Product>> getAll(String shopId) async {
    final db = await _dbHelper.database;

    final maps = await db.rawQuery('''
      SELECT 
        p.*,
        COALESCE(SUM(v.stock_quantity), 0) as total_stock,
        COALESCE(SUM(v.cost_price), 0) as total_cost,
        COALESCE(SUM(v.selling_price * v.stock_quantity), 0) as expected_return
      FROM products p
      LEFT JOIN product_variants v ON v.product_id = p.id AND v.is_active = 1
      WHERE p.shop_id = ? AND p.is_active = 1
      GROUP BY p.id
      ORDER BY p.name ASC
    ''', [shopId]);

    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<Product?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<void> create(Product product) async {
    final db = await _dbHelper.database;
    await db.insert('products', product.toMap());
  }

  Future<void> update(Product product) async {
    final db = await _dbHelper.database;
    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> softDelete(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'products',
      {'is_active': 0, 'updated_at': DatabaseHelper.now()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== VARIANTS ==========

  Future<List<ProductVariant>> getVariants(String productId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'product_variants',
      where: 'product_id = ? AND is_active = 1',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => ProductVariant.fromMap(m)).toList();
  }

  Future<ProductVariant?> getVariantById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'product_variants',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return ProductVariant.fromMap(maps.first);
  }

  Future<void> createVariant(ProductVariant variant) async {
    final db = await _dbHelper.database;
    await db.insert('product_variants', variant.toMap());
  }

  Future<void> updateVariant(ProductVariant variant) async {
    final db = await _dbHelper.database;
    await db.update(
      'product_variants',
      variant.toMap(),
      where: 'id = ?',
      whereArgs: [variant.id],
    );
  }

  Future<void> softDeleteVariant(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'product_variants',
      {'is_active': 0, 'updated_at': DatabaseHelper.now()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

 /// Search products + variants for POS (FIFO - oldest batch first)
Future<List<Map<String, dynamic>>> searchForSale(String shopId, String query) async {
  final db = await _dbHelper.database;
  final term = '%${query.toLowerCase()}%';

  return await db.rawQuery('''
    SELECT 
      v.id as variant_id,
      v.name as variant_name,
      v.selling_price,
      v.cost_price,
      v.unit_cost,
      v.stock_quantity,
      v.expiry_date,
      v.created_at as restocked_at,
      p.id as product_id,
      p.name as product_name
    FROM product_variants v
    INNER JOIN products p ON p.id = v.product_id
    WHERE p.shop_id = ? 
      AND p.is_active = 1 
      AND v.is_active = 1
      AND v.stock_quantity > 0
      AND (LOWER(p.name) LIKE ? OR LOWER(v.name) LIKE ?)
    ORDER BY v.created_at ASC
    LIMIT 40
  ''', [shopId, term, term]);
}
}

class CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Customer>> getAll(String shopId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'customers',
      where: 'shop_id = ? AND is_active = 1',
      whereArgs: [shopId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<Customer?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<void> create(Customer customer) async {
    final db = await _dbHelper.database;
    await db.insert('customers', customer.toMap());
  }

  Future<void> update(Customer customer) async {
    final db = await _dbHelper.database;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<void> softDelete(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'customers',
      {'is_active': 0, 'updated_at': DatabaseHelper.now()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateDebt(String customerId, double newDebt) async {
    final db = await _dbHelper.database;
    await db.update(
      'customers',
      {
        'total_debt': newDebt,
        'updated_at': DatabaseHelper.now(),
      },
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }
}

class InvoiceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Invoice>> getAll(String shopId, {String? status, DateTime? from, DateTime? to}) async {
    final db = await _dbHelper.database;

    String where = 'shop_id = ?';
    List<dynamic> args = [shopId];

    if (status != null) {
      where += ' AND status = ?';
      args.add(status);
    }

    if (from != null) {
      where += ' AND created_at >= ?';
      args.add(from.toUtc().toIso8601String());
    }

    if (to != null) {
      where += ' AND created_at <= ?';
      args.add(to.toUtc().toIso8601String());
    }

    final maps = await db.query(
      'invoices',
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
    );

    return maps.map((m) => Invoice.fromMap(m)).toList();
  }

  Future<Invoice?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Invoice.fromMap(maps.first);
  }

  Future<List<InvoiceItem>> getItems(String invoiceId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
    return maps.map((m) => InvoiceItem.fromMap(m)).toList();
  }

  /// Full sale transaction (atomic)
  Future<String> createSale({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required List<Payment> payments,
    Debt? debt,
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Insert invoice
      await txn.insert('invoices', invoice.toMap());

      // 2. Insert items + reduce stock + record stock movement
      for (final item in items) {
        await txn.insert('invoice_items', item.toMap());

        // Reduce stock
        await txn.rawUpdate('''
          UPDATE product_variants 
          SET stock_quantity = stock_quantity - ?, 
              updated_at = ?
          WHERE id = ?
        ''', [item.quantity, DatabaseHelper.now(), item.variantId]);

        // Stock movement
        await txn.insert('stock_movements', {
          'id': DatabaseHelper.generateId(),
          'variant_id': item.variantId,
          'type': 'sale',
          'quantity': -item.quantity,
          'reference_id': invoice.id,
          'notes': 'Sale',
          'created_at': DatabaseHelper.now(),
        });
      }

      // 3. Payments
      for (final payment in payments) {
        await txn.insert('payments', payment.toMap());
      }

      // 4. Debt (if any)
      if (debt != null) {
        await txn.insert('debts', debt.toMap());

        // Update customer total debt
        await txn.rawUpdate('''
          UPDATE customers 
          SET total_debt = total_debt + ?, 
              updated_at = ?
          WHERE id = ?
        ''', [debt.balance, DatabaseHelper.now(), debt.customerId]);
      }
    });

    return invoice.id;
  }

  Future<void> reverseInvoice(String invoiceId, {String? reason}) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final invoiceMaps = await txn.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
      if (invoiceMaps.isEmpty) return;

      final invoice = Invoice.fromMap(invoiceMaps.first);
      final items = await txn.query('invoice_items', where: 'invoice_id = ?', whereArgs: [invoiceId]);

      // Restore stock
      for (final itemMap in items) {
        final item = InvoiceItem.fromMap(itemMap);

        await txn.rawUpdate('''
          UPDATE product_variants 
          SET stock_quantity = stock_quantity + ?, 
              updated_at = ?
          WHERE id = ?
        ''', [item.quantity, DatabaseHelper.now(), item.variantId]);

        // Stock movement
        await txn.insert('stock_movements', {
          'id': DatabaseHelper.generateId(),
          'variant_id': item.variantId,
          'type': 'reversal',
          'quantity': item.quantity,
          'reference_id': invoiceId,
          'notes': reason ?? 'Invoice reversal',
          'created_at': DatabaseHelper.now(),
        });
      }

      // Mark invoice as reversed
      await txn.update(
        'invoices',
        {
          'status': 'reversed',
          'updated_at': DatabaseHelper.now(),
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      // If it was a debt, reduce customer debt
      if (invoice.balance > 0 && invoice.customerId != null) {
        await txn.rawUpdate('''
          UPDATE customers 
          SET total_debt = MAX(0, total_debt - ?), 
              updated_at = ?
          WHERE id = ?
        ''', [invoice.balance, DatabaseHelper.now(), invoice.customerId]);

        await txn.update(
          'debts',
          {
            'status': 'written_off',
            'updated_at': DatabaseHelper.now(),
          },
          where: 'invoice_id = ?',
          whereArgs: [invoiceId],
        );
      }
    });
  }
}

class DebtRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Debt>> getOpenDebts(String shopId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'debts',
      where: 'shop_id = ? AND status IN (?, ?)',
      whereArgs: [shopId, 'open', 'partial'],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Debt.fromMap(m)).toList();
  }

  Future<List<Debt>> getByCustomer(String customerId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'debts',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Debt.fromMap(m)).toList();
  }
}



class AnalyticsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Map<String, dynamic>> getDashboardStats(
    String shopId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _dbHelper.database;

    String dateFilter = '';
    List<dynamic> args = [shopId];

   if (from != null) {
    dateFilter += ' AND i.created_at >= ?';
    args.add(from.toUtc().toIso8601String());
  }
  if (to != null) {
    dateFilter += ' AND i.created_at <= ?';
    args.add(to.toUtc().toIso8601String());
  }
    // Revenue + Sales count
    final sales = await db.rawQuery('''
  SELECT 
    COUNT(DISTINCT i.id) as total_sales,
    COALESCE(SUM(i.total_amount), 0) as total_revenue,
    COALESCE(SUM( (ii.unit_price - ii.cost_price) * ii.quantity ), 0) as total_profit
  FROM invoices i
  LEFT JOIN invoice_items ii ON ii.invoice_id = i.id
  WHERE i.shop_id = ? 
    AND i.status IN ('paid', 'deni', 'partial')
    $dateFilter
''', args);
    final row = sales.first;

    // Open Deni (always current outstanding)
    final debtResult = await db.rawQuery('''
      SELECT COALESCE(SUM(balance), 0) as open_deni
      FROM debts
      WHERE shop_id = ? AND status IN ('open', 'partial')
    ''', [shopId]);

    // Losses (units) in period
    String lossFilter = '';
    List<dynamic> lossArgs = [];
    if (from != null) {
      lossFilter += ' AND created_at >= ?';
      lossArgs.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      lossFilter += ' AND created_at <= ?';
      lossArgs.add(to.toUtc().toIso8601String());
    }

    final lossResult = await db.rawQuery('''
      SELECT COALESCE(SUM(ABS(quantity)), 0) as loss_qty
      FROM stock_movements
      WHERE type = 'damage' $lossFilter
    ''', lossArgs);

    return {
      'total_sales': row['total_sales'] as int? ?? 0,
      'total_profit': (row['total_profit'] as num?)?.toDouble() ?? 0.0,
      'total_revenue': (row['total_revenue'] as num?)?.toDouble() ?? 0.0,
      'open_deni': (debtResult.first['open_deni'] as num?)?.toDouble() ?? 0.0,
      'loss_qty': (lossResult.first['loss_qty'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<List<Map<String, dynamic>>> getTopSelling(String shopId, {int limit = 6}) async {
    final db = await _dbHelper.database;

    return await db.rawQuery('''
      SELECT 
        ii.product_name,
        ii.variant_name,
        SUM(ii.quantity) as total_qty,
        SUM(ii.line_total) as total_revenue
      FROM invoice_items ii
      INNER JOIN invoices i ON i.id = ii.invoice_id
      WHERE i.shop_id = ?
        AND i.status IN ('paid', 'deni', 'partial')
      GROUP BY ii.product_id, ii.variant_id, ii.product_name, ii.variant_name
      ORDER BY total_qty DESC
      LIMIT ?
    ''', [shopId, limit]);
  }

  Future<List<Map<String, dynamic>>> getLowStock(String shopId, {double threshold = 5}) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        p.name as product_name,
        v.name as variant_name,
        v.stock_quantity,
        v.id as variant_id
      FROM product_variants v
      INNER JOIN products p ON p.id = v.product_id
      WHERE p.shop_id = ? 
        AND p.is_active = 1 
        AND v.is_active = 1
        AND v.stock_quantity > 0
        AND v.stock_quantity <= ?
      ORDER BY v.stock_quantity ASC
      LIMIT 8
    ''', [shopId, threshold]);
  }

  Future<List<Map<String, dynamic>>> getNearExpiry(String shopId, {int days = 30}) async {
  final db = await _dbHelper.database;
  final limitDate = DateTime.now().add(Duration(days: days)).toIso8601String().split('T').first;

  return await db.rawQuery('''
    SELECT 
      p.name as product_name,
      v.name as variant_name,
      v.stock_quantity,
      v.expiry_date,
      v.id as variant_id
    FROM product_variants v
    INNER JOIN products p ON p.id = v.product_id
    WHERE p.shop_id = ? 
      AND p.is_active = 1 
      AND v.is_active = 1
      AND v.stock_quantity > 0
      AND v.expiry_date IS NOT NULL
      AND v.expiry_date <= ?
    ORDER BY v.expiry_date ASC
    LIMIT 8
  ''', [shopId, limitDate]);
}

}