import 'package:flutter/material.dart';

enum DetectedScript {
  urdu, // Nastaliq / Arabic RTL
  english, // Latin LTR
  mixed, // Contains both significant Urdu and English/digits
  numericOnly, // Digits, punctuation, symbols
}

class TextDirectionHelper {
  /// Checks if a unicode code point belongs to Arabic/Urdu/Persian ranges.
  static bool isUrduChar(int codePoint) {
    return (codePoint >= 0x0600 && codePoint <= 0x06FF) || // Arabic / Urdu
        (codePoint >= 0x0750 && codePoint <= 0x077F) || // Arabic Supplement
        (codePoint >= 0x08A0 && codePoint <= 0x08FF) || // Arabic Extended-A
        (codePoint >= 0xFB50 && codePoint <= 0xFDFF) || // Arabic Presentation Forms-A
        (codePoint >= 0xFE70 && codePoint <= 0xFEFF); // Arabic Presentation Forms-B
  }

  /// Checks if code point is an ASCII or Latin alphabet letter.
  static bool isLatinChar(int codePoint) {
    return (codePoint >= 0x0041 && codePoint <= 0x005A) || // A-Z
        (codePoint >= 0x0061 && codePoint <= 0x007A); // a-z
  }

  /// Detects the dominant script in a given string.
  static DetectedScript detectScript(String text) {
    if (text.trim().isEmpty) return DetectedScript.numericOnly;

    int urduCount = 0;
    int latinCount = 0;

    for (final rune in text.runes) {
      if (isUrduChar(rune)) {
        urduCount++;
      } else if (isLatinChar(rune)) {
        latinCount++;
      }
    }

    if (urduCount == 0 && latinCount == 0) {
      return DetectedScript.numericOnly;
    }
    if (urduCount > 0 && latinCount > 0) {
      return DetectedScript.mixed;
    }
    if (urduCount > 0) {
      return DetectedScript.urdu;
    }
    return DetectedScript.english;
  }

  /// Determines natural TextDirection for a string.
  static TextDirection getTextDirection(String text) {
    final script = detectScript(text);
    switch (script) {
      case DetectedScript.urdu:
        return TextDirection.rtl;
      case DetectedScript.english:
        return TextDirection.ltr;
      case DetectedScript.mixed:
        // In Pakistani billing, mixed text typically leads with Urdu commodity name
        return TextDirection.rtl;
      case DetectedScript.numericOnly:
        return TextDirection.ltr;
    }
  }

  /// Wraps a string with Unicode directional isolation mark to ensure clean bi-directional rendering.
  static String isolateBidi(String text, {bool rtl = true}) {
    if (text.isEmpty) return text;
    // RLI (Right-to-Left Isolate) = \u2067, LRI (Left-to-Right Isolate) = \u2066, PDI (Pop Directional Isolate) = \u2069
    final marker = rtl ? '\u2067' : '\u2066';
    return '$marker$text\u2069';
  }
}

