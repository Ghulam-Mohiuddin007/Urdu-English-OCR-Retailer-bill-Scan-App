class AppConstants {
  static const String appName = 'Raaseed OCR';
  static const String appTaglineUrdu = 'رسید اور بل کی خودکار ڈیجیٹائزیشن';
  static const String appTaglineEn = 'Intelligent Urdu & English Bill Scanner';

  // Local OCR Backend API URL (configurable)
  // For Android emulator: 10.0.2.2 points to host machine
  // For iOS / Desktop / Web: 127.0.0.1 or localhost
  static const String defaultAndroidEmulatorUrl = 'http://10.0.2.2:5000/api/process_bill';
  static const String defaultLocalhostUrl = 'http://127.0.0.1:5000/api/process_bill';

  // Progressive OCR Scanning Status Messages
  static const List<Map<String, String>> scanningStatusStages = [
    {
      'urdu': 'بل کا جائزہ لیا جا رہا ہے...',
      'en': 'Analyzing slip geometry & borders...',
    },
    {
      'urdu': 'لکھائی اور اعداد نکالے جا رہے ہیں...',
      'en': 'Extracting Urdu & English text...',
    },
    {
      'urdu': 'ٹیبل اور قیمتیں بنائی جا رہی ہیں...',
      'en': 'Structuring purchase items & prices...',
    },
    {
      'urdu': 'حسابی تصدیق مکمل ہو رہی ہے...',
      'en': 'Verifying mathematical consistency...',
    },
  ];

  // Standard Mandi bag weights
  static const List<double> standardWeights = [25.0, 30.0, 40.0, 50.0, 100.0];
}

