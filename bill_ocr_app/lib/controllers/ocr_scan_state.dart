import 'dart:io';
import '../models/ocr_scan_result.dart';

sealed class OcrScanState {
  const OcrScanState();
}

class OcrScanInitial extends OcrScanState {
  const OcrScanInitial();
}

class OcrScanImageCaptured extends OcrScanState {
  final File rawImage;
  const OcrScanImageCaptured(this.rawImage);
}

class OcrScanCropping extends OcrScanState {
  final File rawImage;
  const OcrScanCropping(this.rawImage);
}

class OcrScanProcessing extends OcrScanState {
  final File croppedImage;
  final int stageIndex;
  final String statusUrdu;
  final String statusEn;

  const OcrScanProcessing({
    required this.croppedImage,
    required this.stageIndex,
    required this.statusUrdu,
    required this.statusEn,
  });
}

class OcrScanDataReady extends OcrScanState {
  final OcrScanResult result;
  final File croppedImage;
  final bool isExporting;

  const OcrScanDataReady({
    required this.result,
    required this.croppedImage,
    this.isExporting = false,
  });

  OcrScanDataReady copyWith({
    OcrScanResult? result,
    File? croppedImage,
    bool? isExporting,
  }) {
    return OcrScanDataReady(
      result: result ?? this.result,
      croppedImage: croppedImage ?? this.croppedImage,
      isExporting: isExporting ?? this.isExporting,
    );
  }
}

class OcrScanExportSuccess extends OcrScanState {
  final OcrScanResult result;
  final File excelFile;
  final File croppedImage;

  const OcrScanExportSuccess({
    required this.result,
    required this.excelFile,
    required this.croppedImage,
  });
}

class OcrScanError extends OcrScanState {
  final String errorMessage;
  final File? failedImage;

  const OcrScanError({
    required this.errorMessage,
    this.failedImage,
  });
}

