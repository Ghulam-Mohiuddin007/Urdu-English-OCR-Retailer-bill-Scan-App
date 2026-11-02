import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_storage_service.dart';

class SupabaseState {
  final bool isConfigured;
  final bool isConnected;
  final bool isTestingConnection;
  final String url;
  final String anonKey;
  final String? statusMessage;

  const SupabaseState({
    this.isConfigured = false,
    this.isConnected = false,
    this.isTestingConnection = false,
    this.url = '',
    this.anonKey = '',
    this.statusMessage,
  });

  SupabaseState copyWith({
    bool? isConfigured,
    bool? isConnected,
    bool? isTestingConnection,
    String? url,
    String? anonKey,
    String? statusMessage,
  }) {
    return SupabaseState(
      isConfigured: isConfigured ?? this.isConfigured,
      isConnected: isConnected ?? this.isConnected,
      isTestingConnection: isTestingConnection ?? this.isTestingConnection,
      url: url ?? this.url,
      anonKey: anonKey ?? this.anonKey,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

final supabaseControllerProvider =
    NotifierProvider<SupabaseController, SupabaseState>(SupabaseController.new);

class SupabaseController extends Notifier<SupabaseState> {
  @override
  SupabaseState build() {
    Future.microtask(loadConfig);
    return const SupabaseState();
  }

  Future<void> loadConfig() async {
    final creds = await SupabaseStorageService.getCredentials();
    final configured = SupabaseStorageService.isConfigured;
    state = state.copyWith(
      isConfigured: configured,
      url: creds['url'] ?? '',
      anonKey: creds['anon_key'] ?? '',
    );
    if (configured) {
      testConnection();
    }
  }

  Future<bool> saveCredentials(String url, String key) async {
    state = state.copyWith(isTestingConnection: true);
    final success = await SupabaseStorageService.saveCredentials(url: url, anonKey: key);
    if (success) {
      final connected = await SupabaseStorageService.testConnection();
      state = state.copyWith(
        isConfigured: SupabaseStorageService.isConfigured,
        isConnected: connected,
        isTestingConnection: false,
        url: url,
        anonKey: key,
        statusMessage: connected ? 'کامیابی سے منسلک ہو گیا (Connected)' : 'منسلک نہیں ہو سکا (Unreachable)',
      );
      return connected;
    } else {
      state = state.copyWith(
        isTestingConnection: false,
        statusMessage: 'کریڈینشلز محفوظ نہ ہو سکے (Failed to save)',
      );
      return false;
    }
  }

  Future<void> testConnection() async {
    state = state.copyWith(isTestingConnection: true);
    final connected = await SupabaseStorageService.testConnection();
    state = state.copyWith(
      isConfigured: SupabaseStorageService.isConfigured,
      isConnected: connected,
      isTestingConnection: false,
      statusMessage: connected ? 'کلاؤڈ آن لائن ہے (Cloud Online)' : 'کلاؤڈ آف لائن ہے (Cloud Offline)',
    );
  }
}

