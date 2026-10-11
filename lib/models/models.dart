// lib/models/models.dart

class Shop {
  final String id;
  final String name;
  final String ownerName;
  final String? phone;
  final String? location;
  final String? logoPath;
  final String createdAt;
  final String updatedAt;

  const Shop({
    required this.id,
    required this.name,
    required this.ownerName,
    this.phone,
    this.location,
    this.logoPath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Shop.fromMap(Map<String, dynamic> map) {
    return Shop(
      id: map['id'] as String,
      name: map['name'] as String,
      ownerName: map['owner_name'] as String,
      phone: map['phone'] as String?,
      location: map['location'] as String?,
      logoPath: map['logo_path'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'owner_name': ownerName,
      'phone': phone,
      'location': location,
      'logo_path': logoPath,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Shop copyWith({
    String? id,
    String? name,
    String? ownerName,
    String? phone,
    String? location,
    String? logoPath,
    String? createdAt,
    String? updatedAt,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      logoPath: logoPath ?? this.logoPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Category {
  final String id;
  final String shopId;
  final String name;
  final String? description;
  final String createdAt;
  final String updatedAt;

  const Category({
    required this.id,
    required this.shopId,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'name': name,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class Product {
  final String id;
  final String shopId;
  final String? categoryId;
  final String name;
  final String? description;
  final String? photoPath;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  // Computed / joined fields (not stored in products table)
  final double? totalStock;
  final double? totalCost;
  final double? expectedReturn;

  const Product({
    required this.id,
    required this.shopId,
    this.categoryId,
    required this.name,
    this.description,
    this.photoPath,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.totalStock,
    this.totalCost,
    this.expectedReturn,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      categoryId: map['category_id'] as String?,
      name: map['name'] as String,
      description: map['description'] as String?,
      photoPath: map['photo_path'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      totalStock: (map['total_stock'] as num?)?.toDouble(),
      totalCost: (map['total_cost'] as num?)?.toDouble(),
      expectedReturn: (map['expected_return'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'photo_path': photoPath,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Product copyWith({
    String? id,
    String? shopId,
    String? categoryId,
    String? name,
    String? description,
    String? photoPath,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    double? totalStock,
    double? totalCost,
    double? expectedReturn,
  }) {
    return Product(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      photoPath: photoPath ?? this.photoPath,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalStock: totalStock ?? this.totalStock,
      totalCost: totalCost ?? this.totalCost,
      expectedReturn: expectedReturn ?? this.expectedReturn,
    );
  }
}

class ProductVariant {
  final String id;
  final String productId;
  final String name;
  final String? sku;
  final double costPrice;
  final double sellingPrice;
  final double stockQuantity;
  final double lowStockThreshold;
  final String? expiryDate;
  final String? batchNumber;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final double unitCost;

  const ProductVariant({
    required this.id,
    required this.productId,
    required this.name,
    this.sku,
    this.unitCost = 0,
    required this.costPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    this.lowStockThreshold = 5,
    this.expiryDate,
    this.batchNumber,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      name: map['name'] as String,
      sku: map['sku'] as String?,
      unitCost:(map['unit_cost']as num?)?.toDouble() ?? 0,
      costPrice: (map['cost_price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      stockQuantity: (map['stock_quantity'] as num).toDouble(),
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toDouble() ?? 5,
      expiryDate: map['expiry_date'] as String?,
      batchNumber: map['batch_number'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'name': name,
      'sku': sku,
      'unit_cost': unitCost,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'stock_quantity': stockQuantity,
      'low_stock_threshold': lowStockThreshold,
      'expiry_date': expiryDate,
      'batch_number': batchNumber,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  ProductVariant copyWith({
    String? id,
    String? productId,
    String? name,
    String? sku,
    double? unitCost,
    double? costPrice,
    double? sellingPrice,
    double? stockQuantity,
    double? lowStockThreshold,
    String? expiryDate,
    String? batchNumber,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      expiryDate: expiryDate ?? this.expiryDate,
      batchNumber: batchNumber ?? this.batchNumber,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Customer {
  final String id;
  final String shopId;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final double totalDebt;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const Customer({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.totalDebt = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      totalDebt: (map['total_debt'] as num?)?.toDouble() ?? 0,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
      'total_debt': totalDebt,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Customer copyWith({
    String? id,
    String? shopId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    double? totalDebt,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      totalDebt: totalDebt ?? this.totalDebt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Invoice {
  final String id;
  final String shopId;
  final String? customerId;
  final String invoiceNumber;
  final double totalAmount;
  final double amountPaid;
  final double balance;
  final String status; // paid | deni | partial | reversed | cancelled
  final String? paymentMethod;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  const Invoice({
    required this.id,
    required this.shopId,
    this.customerId,
    required this.invoiceNumber,
    required this.totalAmount,
    this.amountPaid = 0,
    this.balance = 0,
    this.status = 'paid',
    this.paymentMethod,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      customerId: map['customer_id'] as String?,
      invoiceNumber: map['invoice_number'] as String,
      totalAmount: (map['total_amount'] as num).toDouble(),
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'paid',
      paymentMethod: map['payment_method'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'customer_id': customerId,
      'invoice_number': invoiceNumber,
      'total_amount': totalAmount,
      'amount_paid': amountPaid,
      'balance': balance,
      'status': status,
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class InvoiceItem {
  final String id;
  final String invoiceId;
  final String productId;
  final String variantId;
  final String productName;
  final String variantName;
  final double quantity;
  final double unitPrice;
  final double costPrice;
  final double lineTotal;
  final String createdAt;

  const InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.productId,
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.quantity,
    required this.unitPrice,
    this.costPrice = 0,
    required this.lineTotal,
    required this.createdAt,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'] as String,
      invoiceId: map['invoice_id'] as String,
      productId: map['product_id'] as String,
      variantId: map['variant_id'] as String,
      productName: map['product_name'] as String,
      variantName: map['variant_name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0,
      lineTotal: (map['line_total'] as num).toDouble(),
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'product_id': productId,
      'variant_id': variantId,
      'product_name': productName,
      'variant_name': variantName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'cost_price': costPrice,
      'line_total': lineTotal,
      'created_at': createdAt,
    };
  }
}

class Payment {
  final String id;
  final String invoiceId;
  final double amount;
  final String method;
  final String? reference;
  final String? notes;
  final String createdAt;

  const Payment({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.method,
    this.reference,
    this.notes,
    required this.createdAt,
  });

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as String,
      invoiceId: map['invoice_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      method: map['method'] as String,
      reference: map['reference'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'amount': amount,
      'method': method,
      'reference': reference,
      'notes': notes,
      'created_at': createdAt,
    };
  }
}

class Debt {
  final String id;
  final String shopId;
  final String customerId;
  final String? invoiceId;
  final double amount;
  final double amountPaid;
  final double balance;
  final String? dueDate;
  final String status; // open | partial | settled | written_off
  final String? notes;
  final String createdAt;
  final String updatedAt;

  const Debt({
    required this.id,
    required this.shopId,
    required this.customerId,
    this.invoiceId,
    required this.amount,
    this.amountPaid = 0,
    required this.balance,
    this.dueDate,
    this.status = 'open',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      customerId: map['customer_id'] as String,
      invoiceId: map['invoice_id'] as String?,
      amount: (map['amount'] as num).toDouble(),
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0,
      balance: (map['balance'] as num).toDouble(),
      dueDate: map['due_date'] as String?,
      status: map['status'] as String? ?? 'open',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shop_id': shopId,
      'customer_id': customerId,
      'invoice_id': invoiceId,
      'amount': amount,
      'amount_paid': amountPaid,
      'balance': balance,
      'due_date': dueDate,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class StockMovement {
  final String id;
  final String variantId;
  final String type; // restock | sale | reversal | adjustment | damage
  final double quantity;
  final String? referenceId;
  final String? notes;
  final String createdAt;

  const StockMovement({
    required this.id,
    required this.variantId,
    required this.type,
    required this.quantity,
    this.referenceId,
    this.notes,
    required this.createdAt,
  });

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as String,
      variantId: map['variant_id'] as String,
      type: map['type'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      referenceId: map['reference_id'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'variant_id': variantId,
      'type': type,
      'quantity': quantity,
      'reference_id': referenceId,
      'notes': notes,
      'created_at': createdAt,
    };
  }
}