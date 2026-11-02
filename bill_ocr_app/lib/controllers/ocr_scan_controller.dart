import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/ocr_bill_item.dart';
import '../models/ocr_scan_result.dart';
import '../services/excel_export_service.dart';
import '../services/ocr_pipeline_service.dart';
import 'ocr_scan_state.dart';

final ocrPipelineServiceProvider = Provider<OcrPipelineService>((ref) {
  final service = OcrPipelineService();
  ref.onDispose(() => service.dispose());
  return service;
});

final ocrScanControllerProvider =
    NotifierProvider<OcrScanController, OcrScanState>(
  OcrScanController.new,
);

class OcrScanController extends Notifier<OcrScanState> {
  late final OcrPipelineService _pipelineService;
  final ImagePicker _picker = ImagePicker();
  Timer? _statusCycleTimer;

  @override
  OcrScanState build() {
    _pipelineService = ref.watch(ocrPipelineServiceProvider);
    ref.onDispose(() {
      _statusCycleTimer?.cancel();
    });
    return const OcrScanInitial();
  }

  /// 1. Capture image via Camera
  Future<void> captureFromCamera(BuildContext context) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 95,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        final imageFile = File(photo.path);
        state = OcrScanImageCaptured(imageFile);
        if (context.mounted) {
          await cropAndProcessImage(context, imageFile);
        }
      }
    } catch (e) {
      state = OcrScanError(errorMessage: 'کیمرہ کھولنے میں دشواری: ${e.toString()}');
    }
  }

  /// 2. Select document from Gallery
  Future<void> pickFromGallery(BuildContext context) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image != null) {
        final imageFile = File(image.path);
        state = OcrScanImageCaptured(imageFile);
        if (context.mounted) {
          await cropAndProcessImage(context, imageFile);
        }
      }
    } catch (e) {
      state = OcrScanError(errorMessage: 'گیلری سے تصویر منتخب نہ ہو سکی: ${e.toString()}');
    }
  }

  /// 3. Mobile Edge Cropping & Perspective Alignment
  Future<void> cropAndProcessImage(BuildContext context, File rawImage) async {
    state = OcrScanCropping(rawImage);

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: rawImage.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'بل کاؤنٹر کراپ کریں (Crop Bill)',
            toolbarColor: AppTheme.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            activeControlsWidgetColor: AppTheme.accent,
            cropFrameColor: AppTheme.accent,
            cropGridColor: AppTheme.accentMint.withValues(alpha: 0.5),
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Bill / رسید کراپ کریں',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
        ],
      );

      if (croppedFile != null) {
        final processedFile = File(croppedFile.path);
        await startOcrProcessing(processedFile);
      } else {
        // User cancelled crop, revert to image captured or initial
        state = const OcrScanInitial();
      }
    } catch (e) {
      debugPrint('[OcrScanController] Cropper error: $e. Proceeding with raw image.');
      // If cropper platform plugin is unavailable, continue with raw image
      await startOcrProcessing(rawImage);
    }
  }

  /// 4. Animated OCR Processing with cycling status chips
  Future<void> startOcrProcessing(File croppedImage) async {
    int currentStage = 0;
    final stages = AppConstants.scanningStatusStages;

    state = OcrScanProcessing(
      croppedImage: croppedImage,
      stageIndex: currentStage,
      statusUrdu: stages[currentStage]['urdu']!,
      statusEn: stages[currentStage]['en']!,
    );

    // Cycle status chips every 1.5 seconds for zero-wait perception
    _statusCycleTimer?.cancel();
    _statusCycleTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (state is OcrScanProcessing) {
        currentStage = (currentStage + 1) % stages.length;
        state = OcrScanProcessing(
          croppedImage: croppedImage,
          stageIndex: currentStage,
          statusUrdu: stages[currentStage]['urdu']!,
          statusEn: stages[currentStage]['en']!,
        );
      } else {
        timer.cancel();
      }
    });

    try {
      final result = await _pipelineService.processImage(croppedImage);
      _statusCycleTimer?.cancel();
      state = OcrScanDataReady(result: result, croppedImage: croppedImage);
    } catch (e) {
      _statusCycleTimer?.cancel();
      state = OcrScanError(
        errorMessage: 'OCR پروسیسنگ میں خرابی پیش آگئی: ${e.toString()}',
        failedImage: croppedImage,
      );
    }
  }

  /// 5. Inline Cell Updates with Pakistani Mandi recalculation
  void updateItem(int index, OcrBillItem updatedItem) {
    final currentState = state;
    if (currentState is OcrScanDataReady) {
      final items = List<OcrBillItem>.from(currentState.result.items);
      if (index >= 0 && index < items.length) {
        final recalculated = updatedItem.recalculate(isMandiRate: true);
        items[index] = recalculated;

        final newResult = currentState.result.copyWith(items: items).recomputeTotals();
        state = currentState.copyWith(result: newResult);
      }
    }
  }

  /// 5b. Update Biller Date
  void updateBillerDate(String newDate) {
    final currentState = state;
    if (currentState is OcrScanDataReady) {
      final newResult = currentState.result.copyWith(
        date: newDate,
        billerDate: newDate,
      );
      state = currentState.copyWith(result: newResult);
    }
  }

  /// 5c. Update Customer / Biller Name
  void updateCustomerName(String newCustomer) {
    final currentState = state;
    if (currentState is OcrScanDataReady) {
      final newResult = currentState.result.copyWith(customer: newCustomer);
      state = currentState.copyWith(result: newResult);
    }
  }

  /// 5d. Update Commission / Arhat Expenses
  void updateCommission(double commission) {
    final currentState = state;
    if (currentState is OcrScanDataReady) {
      final newResult = currentState.result.copyWith(commission: commission);
      state = currentState.copyWith(result: newResult);
    }
  }

  /// 5e. Mark Bill as added to inventory
  void markAddedToInventory() {
    final currentState = state;
    if (currentState is OcrScanDataReady) {
      final newResult = currentState.result.copyWith(addedToInventory: true);
      state = currentState.copyWith(result: newResult);
    }
  }

  /// 5f. Mark Bill as synced to Supabase
  void markSyncedToSupabase(String? imageUrl) {
    final currentState = state;
    if (currentState is OcrScanDataReady) {
      final newResult = currentState.result.copyWith(
        syncedToSupabase: true,
        supabaseImageUrl: imageUrl,
      );
      state = currentState.copyWith(result: newResult);
    }
  }

  /// 6. Delete Row
  void deleteItem(int index) {
    final currentState = state;
    if (currentState is OcrScanDataReady) {
      final items = List<OcrBillItem>.from(currentState.result.items);
      if (index >= 0 && index < items.length) {
        items.removeAt(index);
        final newResult = currentState.result.copyWith(items: items).recomputeTotals();
        state = currentState.copyWith(result: newResult);
      }
    }
  }

  /// 7. Add Row
  void addNewItem() {
    final currentState = state;
    if (currentState is OcrScanDataReady) {
      final items = List<OcrBillItem>.from(currentState.result.items);
      final newItem = OcrBillItem(
        id: 'new_item_${DateTime.now().millisecondsSinceEpoch}',
        itemName: 'نیا آئٹم',
        quantity: 1.0,
        weight: 25.0,
        unitPrice: 8000.0,
        totalPrice: 5000.0,
        status: 'Edited',
      );
      items.add(newItem);
      final newResult = currentState.result.copyWith(items: items).recomputeTotals();
      state = currentState.copyWith(result: newResult);
    }
  }

  /// 8. Export to Excel (.xlsx)
  Future<File?> exportToExcel() async {
    final currentState = state;
    if (currentState is OcrScanDataReady) {
      state = currentState.copyWith(isExporting: true);

      try {
        final file = await ExcelExportService.generateExcel(
          result: currentState.result,
        );
        state = OcrScanExportSuccess(
          result: currentState.result,
          excelFile: file,
          croppedImage: currentState.croppedImage,
        );
        return file;
      } catch (e) {
        state = currentState.copyWith(isExporting: false);
        debugPrint('[OcrScanController] Excel export failed: $e');
        rethrow;
      }
    }
    return null;
  }

  /// 9. Share Excel file directly
  Future<void> shareExcelFile(File excelFile) async {
    await ExcelExportService.shareExcelFile(excelFile);
  }

  /// 10. Process sample bill for instant testing
  Future<void> processSampleBill(BuildContext context) async {
    final sampleResult = OcrScanResult.sampleSlip1();
    state = OcrScanDataReady(result: sampleResult);
  }

  /// 11. Reset workflow
  void reset() {
    _statusCycleTimer?.cancel();
    state = const OcrScanInitial();
  }

  void resetToInitial() => reset();
}
