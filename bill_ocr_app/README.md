# Raaseed OCR (رسید او سی آر) - Flutter Mobile Application

A standalone Flutter mobile application focused purely on Bill & Document OCR scanning, edge cropping, structured data extraction, and Excel (`.xlsx`) export for Pakistani retail and wholesale grain markets (Ghalla Mandi).

---

## Architecture Overview

```
bill_ocr_app/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart          # API endpoints, colors, Urdu status messages
│   │   ├── theme/
│   │   │   └── app_theme.dart              # Emerald & Teal theme, Typography (Noto Nastaliq Urdu & Inter)
│   │   └── utils/
│   │       └── formatters.dart             # Currency (Rs. / PKR) & Weight (kg/Maund) formatters
│   ├── models/
│   │   ├── ocr_bill_item.dart              # Immutable line item model with Mandi math recalculations
│   │   └── ocr_scan_result.dart            # Complete bill result with headers, totals, and fallbacks
│   ├── services/
│   │   ├── ocr_pipeline_service.dart       # HTTP client connecting to offline Python OCR backend
│   │   └── excel_export_service.dart       # Styled Excel (.xlsx) generator, OpenFilex & SharePlus
│   ├── controllers/
│   │   ├── ocr_scan_state.dart             # State machine (initial, scanning, success, editing, error)
│   │   └── ocr_scan_controller.dart        # Riverpod 3.x Notifier handling camera, crop, and updates
│   ├── views/
│   │   ├── splash/
│   │   │   └── animated_splash_screen.dart # 60fps entrance pulse & permission checks
│   │   ├── scanner/
│   │   │   ├── ocr_scanner_screen.dart     # Document ingestion dashboard (Camera / Gallery picker)
│   │   │   └── scanning_animation_overlay.dart # Glowing laser beam scan loop & dynamic status chips
│   │   └── result/
│   │       └── ocr_result_table_screen.dart # Editable data table, inline dialogs, Excel/Share bar
│   └── main.dart                           # Riverpod ProviderScope root & portrait orientation setup
└── test/
    ├── unit_test.dart                      # Model recalculation & Excel generation tests
    └── widget_test.dart                    # App launch & splash-to-scanner smoke test
```

---

## Key Features

1. **Animated Splash Screen (`animated_splash_screen.dart`)**:
   - Subtle pulse and fade animation (using Flutter `AnimationController` and `CurvedAnimation`).
   - Checks camera and gallery permissions in the background and navigates to the scanner dashboard.

2. **Document Ingestion (`ocr_scanner_screen.dart`)**:
   - Modern cards for **[📸 Take Photo / کیمرہ]** and **[📁 Upload Slip / گیلری]**.
   - Interactive crop configuration using `image_cropper` (`CropAspectRatioPreset.ratio4x3`, `CropAspectRatioPreset.ratio16x9`, freeform).

3. **Laser Beam Scan Animation (`scanning_animation_overlay.dart`)**:
   - Zero-wait perception during OCR inference.
   - Dual-gradient glowing scanning beam traveling over the bill preview.
   - Dynamic Urdu/English status chips cycling every 1.5 seconds.

4. **Editable Data Table (`ocr_result_table_screen.dart`)**:
   - Displays Item Name / نام, Quantity / تعداد, Rate / قیمت, and Total / کل رقم.
   - Tap any cell to quickly correct weights, rates, or Urdu commodity names.
   - Automatic Mandi recalculation:
     $$\text{Total Price} = \text{round}\left(\frac{\text{Weight (kg)} \times \text{Rate (Rs./40kg)}}{40.0}\right)$$
   - Zero layout pixel overflows (`SingleChildScrollView` with `viewInsets` padding when the keyboard appears).

5. **Local Excel (.xlsx) Generation & Sharing (`excel_export_service.dart`)**:
   - Generates formatted `.xlsx` spreadsheets with emerald headers, double-line summary borders, and auto-adjusted column widths.
   - Direct opening via `open_filex` and one-tap sharing via `share_plus`.

---

## How to Run

### Step 1: Start the Offline OCR Backend Server
From the root project directory:
```bash
# In d:\OCR project
.\.venv\Scripts\python.exe api_server.py
```
*The server will start listening on `http://127.0.0.1:5000` (or `http://10.0.2.2:5000` for Android Emulator).*

### Step 2: Run the Flutter App
From the `bill_ocr_app` directory:
```bash
cd "d:\OCR project\bill_ocr_app"
flutter pub get
flutter run
```

### Step 3: Run the Test Suite
```bash
flutter test
```
All unit and widget tests will execute and verify model math, Excel generation, and navigation.
