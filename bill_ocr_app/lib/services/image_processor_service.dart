import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class PreprocessedImageData {
  final File normalizedImage;
  final File thumbnailImage;
  final int originalWidth;
  final int originalHeight;
  final int processedWidth;
  final int processedHeight;
  final int processingDurationMs;

  const PreprocessedImageData({
    required this.normalizedImage,
    required this.thumbnailImage,
    required this.originalWidth,
    required this.originalHeight,
    required this.processedWidth,
    required this.processedHeight,
    required this.processingDurationMs,
  });
}

class ImageProcessorService {
  /// Offloads complete image preprocessing, contrast enhancement, EXIF orientation,
  /// resolution normalization, and thumbnail generation to a background isolate.
  static Future<PreprocessedImageData> preprocessForOcr(File rawImage) async {
    final stopwatch = Stopwatch()..start();

    final rawBytes = await rawImage.readAsBytes();
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final normalizedPath = '${tempDir.path}/normalized_$timestamp.jpg';
    final thumbPath = '${tempDir.path}/thumb_$timestamp.jpg';

    // Offload to background isolate
    final result = await compute<Map<String, dynamic>, Map<String, dynamic>>(
      _isolateProcessTask,
      {
        'bytes': rawBytes,
        'normalizedPath': normalizedPath,
        'thumbPath': thumbPath,
      },
    );

    stopwatch.stop();

    return PreprocessedImageData(
      normalizedImage: File(result['normalizedPath'] as String),
      thumbnailImage: File(result['thumbPath'] as String),
      originalWidth: result['originalWidth'] as int,
      originalHeight: result['originalHeight'] as int,
      processedWidth: result['processedWidth'] as int,
      processedHeight: result['processedHeight'] as int,
      processingDurationMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Top-level function executed in the background isolate
  static Map<String, dynamic> _isolateProcessTask(Map<String, dynamic> params) {
    final Uint8List rawBytes = params['bytes'] as Uint8List;
    final String normalizedPath = params['normalizedPath'] as String;
    final String thumbPath = params['thumbPath'] as String;

    // 1. Decode image bytes
    img.Image? decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      throw Exception('Failed to decode raw image in background isolate.');
    }

    final origW = decoded.width;
    final origH = decoded.height;

    // 2. Correct orientation if image contains EXIF orientation flags
    decoded = img.bakeOrientation(decoded);

    // 3. Resolution Normalization: Clamp maximum dimension to 1600px
    // This preserves high-frequency text details for Urdu dots while cutting RAM by >80%.
    const int maxTargetDim = 1600;
    img.Image normalized = decoded;
    if (decoded.width > maxTargetDim || decoded.height > maxTargetDim) {
      if (decoded.width >= decoded.height) {
        normalized = img.copyResize(
          decoded,
          width: maxTargetDim,
          interpolation: img.Interpolation.linear,
        );
      } else {
        normalized = img.copyResize(
          decoded,
          height: maxTargetDim,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // 4. Contrast & Dynamic Range Optimization for faint Mandi slips
    // Boost contrast slightly (+12%) to sharpen ink strokes against carbon/yellow paper
    normalized = img.adjustColor(
      normalized,
      contrast: 1.12,
      brightness: 1.02,
    );

    // 5. Generate high-quality compressed JPEG for OCR upload
    final normalizedBytes = Uint8List.fromList(
      img.encodeJpg(normalized, quality: 90),
    );
    File(normalizedPath).writeAsBytesSync(normalizedBytes);

    // 6. Generate lightweight (320px) compressed thumbnail for local history list
    final thumbnail = img.copyResize(
      normalized,
      width: (normalized.width > normalized.height) ? 320 : 0,
      height: (normalized.height >= normalized.width) ? 320 : 0,
      interpolation: img.Interpolation.average,
    );
    final thumbBytes = Uint8List.fromList(
      img.encodeJpg(thumbnail, quality: 78),
    );
    File(thumbPath).writeAsBytesSync(thumbBytes);

    return {
      'normalizedPath': normalizedPath,
      'thumbPath': thumbPath,
      'originalWidth': origW,
      'originalHeight': origH,
      'processedWidth': normalized.width,
      'processedHeight': normalized.height,
    };
  }
}

