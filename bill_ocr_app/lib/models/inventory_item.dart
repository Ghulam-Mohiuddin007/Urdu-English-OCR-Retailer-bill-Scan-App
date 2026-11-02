class InventoryItem {
  final String id;
  final String commodityName;
  final String englishName;
  final double stockWeightKg;
  final double lastPurchaseRate; // Rs per 40kg
  final double totalStockValue; // Rs
  final String lastBillerDate;
  final String lastBillNo;
  final String lastSupplier;
  final DateTime lastUpdated;
  final int totalBillsCount;

  const InventoryItem({
    required this.id,
    required this.commodityName,
    this.englishName = '',
    required this.stockWeightKg,
    required this.lastPurchaseRate,
    required this.totalStockValue,
    required this.lastBillerDate,
    required this.lastBillNo,
    required this.lastSupplier,
    required this.lastUpdated,
    this.totalBillsCount = 1,
  });

  /// Stock in Pakistani Mandi Maunds (40 kg = 1 Maund / من)
  double get stockMaunds => stockWeightKg / 40.0;

  InventoryItem copyWith({
    String? id,
    String? commodityName,
    String? englishName,
    double? stockWeightKg,
    double? lastPurchaseRate,
    double? totalStockValue,
    String? lastBillerDate,
    String? lastBillNo,
    String? lastSupplier,
    DateTime? lastUpdated,
    int? totalBillsCount,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      commodityName: commodityName ?? this.commodityName,
      englishName: englishName ?? this.englishName,
      stockWeightKg: stockWeightKg ?? this.stockWeightKg,
      lastPurchaseRate: lastPurchaseRate ?? this.lastPurchaseRate,
      totalStockValue: totalStockValue ?? this.totalStockValue,
      lastBillerDate: lastBillerDate ?? this.lastBillerDate,
      lastBillNo: lastBillNo ?? this.lastBillNo,
      lastSupplier: lastSupplier ?? this.lastSupplier,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      totalBillsCount: totalBillsCount ?? this.totalBillsCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'commodity_name': commodityName,
      'english_name': englishName,
      'stock_weight_kg': stockWeightKg,
      'last_purchase_rate': lastPurchaseRate,
      'total_stock_value': totalStockValue,
      'last_biller_date': lastBillerDate,
      'last_bill_no': lastBillNo,
      'last_supplier': lastSupplier,
      'last_updated': lastUpdated.toIso8601String(),
      'total_bills_count': totalBillsCount,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id']?.toString() ?? 'inv_${DateTime.now().millisecondsSinceEpoch}',
      commodityName: map['commodity_name']?.toString() ?? '',
      englishName: map['english_name']?.toString() ?? '',
      stockWeightKg: (map['stock_weight_kg'] as num?)?.toDouble() ?? 0.0,
      lastPurchaseRate: (map['last_purchase_rate'] as num?)?.toDouble() ?? 0.0,
      totalStockValue: (map['total_stock_value'] as num?)?.toDouble() ?? 0.0,
      lastBillerDate: map['last_biller_date']?.toString() ?? '',
      lastBillNo: map['last_bill_no']?.toString() ?? '',
      lastSupplier: map['last_supplier']?.toString() ?? '',
      lastUpdated: DateTime.tryParse(map['last_updated']?.toString() ?? '') ?? DateTime.now(),
      totalBillsCount: (map['total_bills_count'] as num?)?.toInt() ?? 1,
    );
  }
}

