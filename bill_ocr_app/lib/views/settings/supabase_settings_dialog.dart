import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/supabase_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../services/supabase_storage_service.dart';

class SupabaseSettingsDialog extends ConsumerStatefulWidget {
  const SupabaseSettingsDialog({super.key});

  @override
  ConsumerState<SupabaseSettingsDialog> createState() => _SupabaseSettingsDialogState();
}

class _SupabaseSettingsDialogState extends ConsumerState<SupabaseSettingsDialog> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _keyCtrl;

  @override
  void initState() {
    super.initState();
    final supaState = ref.read(supabaseControllerProvider);
    _urlCtrl = TextEditingController(text: supaState.url);
    _keyCtrl = TextEditingController(text: supaState.anonKey);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supaState = ref.watch(supabaseControllerProvider);
    final supaCtrl = ref.read(supabaseControllerProvider.notifier);

    return Dialog(
      backgroundColor: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3ECF8E).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_sync_rounded,
                      color: Color(0xFF3ECF8E),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supabase Cloud Storage',
                          style: AppTheme.englishTextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'کلاؤڈ ڈیٹا بیس اور بیک اپ سیٹنگز',
                          style: AppTheme.urduTextStyle(
                            fontSize: 12,
                            color: AppTheme.textDarkMuted,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textDarkMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Connection Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: supaState.isConnected
                      ? AppTheme.accentEmerald.withValues(alpha: 0.15)
                      : (supaState.isConfigured
                          ? AppTheme.accentGold.withValues(alpha: 0.15)
                          : AppTheme.darkSurfaceElevated),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: supaState.isConnected
                        ? AppTheme.accentEmerald.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      supaState.isConnected
                          ? Icons.check_circle_rounded
                          : (supaState.isConfigured
                              ? Icons.sync_problem_rounded
                              : Icons.cloud_off_rounded),
                      size: 18,
                      color: supaState.isConnected
                          ? AppTheme.accentEmerald
                          : (supaState.isConfigured ? AppTheme.accentGold : AppTheme.textDarkMuted),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        supaState.statusMessage ??
                            (supaState.isConnected
                                ? 'منسلک ہے (Cloud Online & Ready)'
                                : 'آف لائن یا غیر تشکیل شدہ (Offline Mode)'),
                        style: AppTheme.englishTextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: supaState.isConnected
                              ? AppTheme.accentEmerald
                              : AppTheme.textDarkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // URL Input
              TextField(
                controller: _urlCtrl,
                style: AppTheme.englishTextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Supabase Project URL',
                  hintText: 'https://xxxxxxxx.supabase.co',
                  labelStyle: AppTheme.englishTextStyle(color: AppTheme.textDarkMuted),
                  filled: true,
                  fillColor: AppTheme.darkSurfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.link_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),

              // Anon Key Input
              TextField(
                controller: _keyCtrl,
                obscureText: true,
                style: AppTheme.englishTextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Supabase Anon Public API Key',
                  hintText: 'eyJhbGciOiJIUzI1NiIsIn...',
                  labelStyle: AppTheme.englishTextStyle(color: AppTheme.textDarkMuted),
                  filled: true,
                  fillColor: AppTheme.darkSurfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // SQL Setup Schema Helper
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.table_chart_outlined, size: 16, color: AppTheme.accentGold),
                        const SizedBox(width: 6),
                        Text(
                          'SQL Tables & Storage Bucket Setup',
                          style: AppTheme.englishTextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentGold,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text('Copy SQL'),
                          onPressed: () {
                            Clipboard.setData(
                              const ClipboardData(
                                text: SupabaseStorageService.recommendedSqlSchema,
                              ),
                            );
                            AppHaptics.light();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('SQL اسکرپٹ کلپ بورڈ پر کاپی ہو گیا'),
                                duration: Duration(milliseconds: 1200),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    Text(
                      'Includes bills, bill_items, inventory tables, and receipts storage bucket.',
                      style: AppTheme.englishTextStyle(
                        fontSize: 11,
                        color: AppTheme.textDarkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.darkBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: supaState.isTestingConnection
                          ? null
                          : () {
                              AppHaptics.selection();
                              supaCtrl.testConnection();
                            },
                      child: supaState.isTestingConnection
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'ٹیسٹ کنکشن (Test)',
                              style: AppTheme.urduTextStyle(
                                fontSize: 12,
                                color: AppTheme.textDarkSecondary,
                                height: 1.2,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3ECF8E),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        AppHaptics.medium();
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        final ok = await supaCtrl.saveCredentials(
                          _urlCtrl.text.trim(),
                          _keyCtrl.text.trim(),
                        );
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Supabase منسلک ہو گیا (Connected Successfully)'
                                  : 'سیٹنگز محفوظ ہو گئیں (Saved)',
                            ),
                          ),
                        );
                        navigator.pop();
                      },
                      child: Text(
                        'محفوظ کریں (Save)',
                        style: AppTheme.urduTextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
