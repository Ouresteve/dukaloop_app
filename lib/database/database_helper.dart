import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for desktop
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final path = join(await getDatabasesPath(), 'dukaloop.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Initialize the database and create the necessary tables.
  Future<void> _onCreate(Database db, int version) async {
    // ==================== SHOPS ====================
    // Supports future multi-shop / multi-device ownership
    await db.execute('''
      CREATE TABLE shops (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        owner_name TEXT NOT NULL,
        phone TEXT,
        location TEXT,
        logo_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ==================== CATEGORIES ====================
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (shop_id) REFERENCES shops (id) ON DELETE CASCADE
      )
    ''');

    // ==================== PRODUCTS ====================
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        category_id TEXT,
        name TEXT NOT NULL,
        description TEXT,
        photo_path TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (shop_id) REFERENCES shops (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // ==================== PRODUCT VARIANTS ====================
    // This is the actual stock unit (e.g. 1kg, 500ml, pcs)
    await db.execute('''
      CREATE TABLE product_variants (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        name TEXT NOT NULL,                    -- e.g. "1kg", "500ml", "pcs"
        sku TEXT,                               -- optional barcode / sku
        unit_cost REAL NOT NULL DEFAULT 0,      -- cost per unit (cost_price / stock_quantity)
        cost_price REAL NOT NULL DEFAULT 0,     -- total wholesale cost of this batch
        selling_price REAL NOT NULL DEFAULT 0,  -- price per unit
        stock_quantity REAL NOT NULL DEFAULT 0, -- supports decimal for weight items
        low_stock_threshold REAL DEFAULT 5,
        expiry_date TEXT,                       -- ISO date or null
        batch_number TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');

    // ==================== CUSTOMERS ====================
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        total_debt REAL NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (shop_id) REFERENCES shops (id) ON DELETE CASCADE
      )
    ''');

    // ==================== INVOICES ====================
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        customer_id TEXT,                       -- null = walk-in / cash sale
        invoice_number TEXT NOT NULL,           -- human friendly number
        total_amount REAL NOT NULL DEFAULT 0,
        amount_paid REAL NOT NULL DEFAULT 0,
        balance REAL NOT NULL DEFAULT 0,        -- positive = debt (deni)
        status TEXT NOT NULL DEFAULT 'paid',    -- paid | deni | partial | reversed | cancelled
        payment_method TEXT,                    -- cash | mpesa | card | mixed
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (shop_id) REFERENCES shops (id) ON DELETE CASCADE,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
      )
    ''');

    // ==================== INVOICE ITEMS ====================
    await db.execute('''
      CREATE TABLE invoice_items (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        variant_id TEXT NOT NULL,
        product_name TEXT NOT NULL,             -- snapshot at time of sale
        variant_name TEXT NOT NULL,             -- snapshot
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,                -- selling price at time of sale
        cost_price REAL NOT NULL DEFAULT 0,     -- for profit calculation
        line_total REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT,
        FOREIGN KEY (variant_id) REFERENCES product_variants (id) ON DELETE RESTRICT
      )
    ''');

    // ==================== PAYMENTS ====================
    // Supports multiple payments against one invoice (partial payments)
    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY,
        invoice_id TEXT NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL,                    -- cash | mpesa | card | bank
        reference TEXT,                         -- M-Pesa code, etc.
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
      )
    ''');

    // ==================== DEBTS / CREDITORS ====================
    // Explicit debt tracking (cleaner than only using invoice.balance)
    await db.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        shop_id TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        invoice_id TEXT,                        -- linked invoice (optional)
        amount REAL NOT NULL,
        amount_paid REAL NOT NULL DEFAULT 0,
        balance REAL NOT NULL,
        due_date TEXT,
        status TEXT NOT NULL DEFAULT 'open',    -- open | partial | settled | written_off
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (shop_id) REFERENCES shops (id) ON DELETE CASCADE,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
        FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE SET NULL
      )
    ''');

    // ==================== STOCK MOVEMENTS ====================
    // Full audit trail of every stock change (sales, restocks, adjustments, reversals)
    await db.execute('''
      CREATE TABLE stock_movements (
        id TEXT PRIMARY KEY,
        variant_id TEXT NOT NULL,
        type TEXT NOT NULL,                     -- restock | sale | reversal | adjustment | damage
        quantity REAL NOT NULL,                 -- positive = in, negative = out
        reference_id TEXT,                      -- invoice_id or restock batch id
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (variant_id) REFERENCES product_variants (id) ON DELETE CASCADE
      )
    ''');

    // ==================== CHANGELOG (for future sync) ====================
    await db.execute('''
      CREATE TABLE changelog (
        id TEXT PRIMARY KEY,
        entity TEXT NOT NULL,                   -- product | variant | invoice | customer | etc.
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,                   -- create | update | delete
        payload TEXT,                           -- JSON snapshot (optional)
        device_id TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // ==================== APP SETTINGS ====================
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // ==================== INDEXES ====================
    await db.execute('CREATE INDEX idx_products_shop ON products(shop_id)');
    await db.execute('CREATE INDEX idx_variants_product ON product_variants(product_id)');
    await db.execute('CREATE INDEX idx_variants_expiry ON product_variants(expiry_date)');
    await db.execute('CREATE INDEX idx_customers_shop ON customers(shop_id)');
    await db.execute('CREATE INDEX idx_invoices_shop ON invoices(shop_id)');
    await db.execute('CREATE INDEX idx_invoices_customer ON invoices(customer_id)');
    await db.execute('CREATE INDEX idx_invoices_created ON invoices(created_at)');
    await db.execute('CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id)');
    await db.execute('CREATE INDEX idx_debts_customer ON debts(customer_id)');
    await db.execute('CREATE INDEX idx_stock_movements_variant ON stock_movements(variant_id)');
    await db.execute('CREATE INDEX idx_changelog_synced ON changelog(synced)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
    // Example:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT');
    // }
  }

  // ==================== HELPERS ====================

  /// Generate a new UUID v4
  static String generateId() => const Uuid().v4();

  /// Current timestamp in ISO-8601
  static String now() => DateTime.now().toUtc().toIso8601String();

  /// Close the database (useful for tests or clean shutdown)
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}