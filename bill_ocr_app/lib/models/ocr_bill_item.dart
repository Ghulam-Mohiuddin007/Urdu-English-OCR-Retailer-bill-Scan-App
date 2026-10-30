class OcrBillItem {
  final String id;
  final String itemName;
  final double quantity;
  final double weight; // kg
  final double unitPrice; // PKR (per 40kg maund or unit)
  final double totalPrice; // PKR
  final String status; // 'Verified', 'Extracted', 'Edited'

  const OcrBillItem({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.weight,
    required this.unitPrice,
    required this.totalPrice,
    this.status = 'Extracted',
  });

  OcrBillItem copyWith({
    String? id,
    String? itemName,
    double? quantity,
    double? weight,
    double? unitPrice,
    double? totalPrice,
    String? status,
  }) {
    return OcrBillItem(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      weight: weight ?? this.weight,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
    );
  }

  // Recalculates line total based on Pakistani Mandi formula (per 40kg) or direct unit rate
  OcrBillItem recalculate({bool isMandiRate = true}) {
    double calculatedTotal = totalPrice;
    if (isMandiRate && weight > 0 && unitPrice > 0) {
      calculatedTotal = (weight * unitPrice / 40.0).roundToDouble();
    } else if (unitPrice > 0 && quantity > 0) {
      calculatedTotal = (quantity * unitPrice).roundToDouble();
    }

    return copyWith(
      totalPrice: calculatedTotal,
      status: 'Edited',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_name': itemName,
      'quantity': quantity,
      'weight': weight,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'status': status,
    };
  }

  factory OcrBillItem.fromMap(Map<String, dynamic> map, {int index = 0}) {
    final id = map['id']?.toString() ?? 'item_${DateTime.now().millisecondsSinceEpoch}_$index';
    final itemName = map['item_name']?.toString() ??
        map['commodity']?.toString() ??
        map['name']?.toString() ??
        'آئٹم ${index + 1}';
    final quantity = (map['quantity'] as num?)?.toDouble() ?? 1.0;
    final weight = (map['weight'] as num?)?.toDouble() ??
        (map['weight_kg'] as num?)?.toDouble() ??
        0.0;
    final unitPrice = (map['unit_price'] as num?)?.toDouble() ??
        (map['rate'] as num?)?.toDouble() ??
        0.0;
    final totalPrice = (map['total_price'] as num?)?.toDouble() ??
        (map['total'] as num?)?.toDouble() ??
        0.0;
    final status = map['status']?.toString() ?? 'Verified';

    return OcrBillItem(
      id: id,
      itemName: itemName,
      quantity: quantity,
      weight: weight,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      status: status,
    );
  }
}

