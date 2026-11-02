import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inventory_item.dart';
import '../models/scan_history_entry.dart';

class SupabaseSyncResult {
  final bool success;
  final String message;
  final String? imageUrl;
  final int syncedItemsCount;

  const SupabaseSyncResult({
    required this.success,
    required this.message,
    this.imageUrl,
    this.syncedItemsCount = 0,
  });
}

class SupabaseStorageService {
  static const String _prefUrlKey = 'supabase_project_url';
  static const String _prefAnonKey = 'supabase_anon_key';
  static const String _bucketName = 'receipts';

  // Default placeholder credentials
  static const String defaultUrl = 'https://xyzcompany.supabase.co';
  static const String defaultAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy_key';

  static bool _isInitialized = false;
  static String? _cachedUrl;
  static String? _cachedAnonKey;

  /// Returns true if valid custom credentials have been configured
  static bool get isConfigured {
    final url = _cachedUrl ?? '';
    final key = _cachedAnonKey ?? '';
    return url.isNotEmpty &&
        key.isNotEmpty &&
        url.startsWith('https://') &&
        !url.contains('xyzcompany');
  }

  /// Initializes Supabase client from SharedPreferences or defaults
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedUrl = prefs.getString(_prefUrlKey) ?? defaultUrl;
      _cachedAnonKey = prefs.getString(_prefAnonKey) ?? defaultAnonKey;

      if (_cachedUrl!.isNotEmpty && _cachedAnonKey!.isNotEmpty) {
        await Supabase.initialize(
          url: _cachedUrl!,
          // ignore: deprecated_member_use
          anonKey: _cachedAnonKey!,
          debug: kDebugMode,
        );
        _isInitialized = true;
        debugPrint('[SupabaseStorageService] Supabase initialized with url: $_cachedUrl');
      }
    } catch (e) {
      debugPrint('[SupabaseStorageService] Supabase initialization warning: $e');
      _isInitialized = false;
    }
  }

  /// Updates Supabase credentials dynamically from settings dialog
  static Future<bool> saveCredentials({
    required String url,
    required String anonKey,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUrlKey, url.trim());
      await prefs.setString(_prefAnonKey, anonKey.trim());
      _cachedUrl = url.trim();
      _cachedAnonKey = anonKey.trim();

      // Re-initialize client
      await Supabase.initialize(
        url: _cachedUrl!,
        // ignore: deprecated_member_use
        anonKey: _cachedAnonKey!,
        debug: kDebugMode,
      );
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('[SupabaseStorageService] Failed to save credentials: $e');
      return false;
    }
  }

  /// Retrieves current configured URL and Key
  static Future<Map<String, String>> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'url': prefs.getString(_prefUrlKey) ?? _cachedUrl ?? '',
      'anon_key': prefs.getString(_prefAnonKey) ?? _cachedAnonKey ?? '',
    };
  }

  /// Tests connectivity to Supabase
  static Future<bool> testConnection() async {
    if (!isConfigured) return false;
    try {
      final client = Supabase.instance.client;
      // Ping database with a simple query
      await client.from('bills').select('id').limit(1);
      return true;
    } catch (e) {
      debugPrint('[SupabaseStorageService] Connection test error: $e');
      // If error is table not found, connection itself still worked
      if (e.toString().contains('relation') || e.toString().contains('404')) {
        return true;
      }
      return false;
    }
  }

  /// Uploads bill photo to Supabase Storage bucket ('receipts')
  static Future<String?> uploadReceiptImage(File imageFile, String billNo) async {
    if (!_isInitialized || !isConfigured) return null;

    try {
      final client = Supabase.instance.client;
      final fileName = 'receipt_${billNo}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await imageFile.readAsBytes();

      // Ensure bucket exists or upload directly
      await client.storage.from(_bucketName).uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final publicUrl = client.storage.from(_bucketName).getPublicUrl(fileName);
      debugPrint('[SupabaseStorageService] Uploaded receipt image: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('[SupabaseStorageService] Image upload error: $e');
      return null;
    }
  }

  /// Syncs an entire bill and its line items to Supabase Database
  static Future<SupabaseSyncResult> syncBillToCloud(
    ScanHistoryEntry bill, {
    File? imageFile,
  }) async {
    if (!_isInitialized || !isConfigured) {
      return const SupabaseSyncResult(
        success: false,
        message: 'Supabase تشکیل نہیں دی گئی (Not configured. Local offline mode active.)',
      );
    }

    try {
      final client = Supabase.instance.client;

      // 1. Upload receipt image to Storage bucket if available
      String? remoteImageUrl = bill.supabaseImageUrl;
      if (imageFile != null && await imageFile.exists()) {
        remoteImageUrl = await uploadReceiptImage(imageFile, bill.billNo);
      } else if (bill.imagePath != null && File(bill.imagePath!).existsSync()) {
        remoteImageUrl = await uploadReceiptImage(File(bill.imagePath!), bill.billNo);
      }

      // 2. Upsert into 'bills' table
      await client.from('bills').upsert({
        'id': bill.id,
        'bill_no': bill.billNo,
        'biller_date': bill.billerDate,
        'customer': bill.customer,
        'total_weight_kg': bill.totalWeight,
        'subtotal_rs': bill.subtotal,
        'commission_rs': bill.commission,
        'grand_total_rs': bill.grandTotal,
        'image_url': remoteImageUrl,
        'status': bill.status,
        'added_to_inventory': bill.addedToInventory,
        'created_at': bill.createdAt.toIso8601String(),
      });

      // 3. Upsert into 'bill_items' table
      int count = 0;
      for (final item in bill.items) {
        await client.from('bill_items').upsert({
          'id': '${bill.id}_${item.id}',
          'bill_id': bill.id,
          'item_name': item.itemName,
          'quantity': item.quantity,
          'weight_kg': item.weight,
          'unit_rate': item.unitPrice,
          'total_price': item.totalPrice,
          'status': item.status,
        });
        count++;
      }

      return SupabaseSyncResult(
        success: true,
        message: 'کامیابی سے کلاؤڈ پر محفوظ ہو گیا (Successfully synced to Supabase)',
        imageUrl: remoteImageUrl,
        syncedItemsCount: count,
      );
    } catch (e) {
      debugPrint('[SupabaseStorageService] Sync error: $e');
      return SupabaseSyncResult(
        success: false,
        message: 'کلاؤڈ سنک میں خرابی: ${e.toString()}',
      );
    }
  }

  /// Syncs local inventory items to Supabase 'inventory' table
  static Future<bool> syncInventoryToCloud(List<InventoryItem> items) async {
    if (!_isInitialized || !isConfigured || items.isEmpty) return false;

    try {
      final client = Supabase.instance.client;
      for (final item in items) {
        await client.from('inventory').upsert({
          'id': item.id,
          'commodity_name': item.commodityName,
          'english_name': item.englishName,
          'stock_weight_kg': item.stockWeightKg,
          'last_purchase_rate': item.lastPurchaseRate,
          'total_stock_value': item.totalStockValue,
          'last_biller_date': item.lastBillerDate,
          'last_bill_no': item.lastBillNo,
          'last_supplier': item.lastSupplier,
          'last_updated': item.lastUpdated.toIso8601String(),
        });
      }
      debugPrint('[SupabaseStorageService] Synced ${items.length} inventory items to Supabase.');
      return true;
    } catch (e) {
      debugPrint('[SupabaseStorageService] Inventory cloud sync warning: $e');
      return false;
    }
  }

  /// SQL script to help user set up Supabase tables with 1 click
  static const String recommendedSqlSchema = '''
-- 1. Create Receipts Storage Bucket
insert into storage.buckets (id, name, public) 
values ('receipts', 'receipts', true)
on conflict (id) do nothing;

-- 2. Bills Table
create table if not exists public.bills (
  id text primary key,
  bill_no text not null,
  biller_date text,
  customer text,
  total_weight_kg numeric,
  subtotal_rs numeric,
  commission_rs numeric,
  grand_total_rs numeric,
  image_url text,
  status text,
  added_to_inventory boolean default false,
  created_at timestamp with time zone default now()
);

-- 3. Bill Items Table
create table if not exists public.bill_items (
  id text primary key,
  bill_id text references public.bills(id) on delete cascade,
  item_name text not null,
  quantity numeric,
  weight_kg numeric,
  unit_rate numeric,
  total_price numeric,
  status text
);

-- 4. Inventory Ledger Table
create table if not exists public.inventory (
  id text primary key,
  commodity_name text not null,
  english_name text,
  stock_weight_kg numeric default 0,
  last_purchase_rate numeric default 0,
  total_stock_value numeric default 0,
  last_biller_date text,
  last_bill_no text,
  last_supplier text,
  last_updated timestamp with time zone default now()
);
''';
}
