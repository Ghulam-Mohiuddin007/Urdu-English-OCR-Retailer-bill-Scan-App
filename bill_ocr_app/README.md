<div align="center">

# 🌾 Raaseed OCR (رسید او سی آر)
### *Mobile Client • Offline Urdu & English Document Scanner & Excel Exporter*

[![Flutter](https://img.shields.io/badge/Flutter-3.47.6-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.5-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Riverpod](https://img.shields.io/badge/Riverpod-3.4.3-2563EB?style=for-the-badge)](https://riverpod.dev)
[![Excel](https://img.shields.io/badge/Excel-Native_.xlsx-107C41?style=for-the-badge&logo=microsoftexcel&logoColor=white)](https://pub.dev/packages/excel)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows-brightgreen?style=for-the-badge)](https://flutter.dev)

<p align="center">
  <b>Bespoke Obsidian Glassmorphism UI</b> • <b>Isolate Preprocessing</b> • <b>Bilingual RTL/LTR Stream</b> • <b>Scan Vault Archive</b>
</p>

---

</div>

## 📱 Visual App Highlights

- **Bespoke Obsidian Canvas**: Deep slate backgrounds (`#090D16`), vibrant emerald highlights (`#10B981`), and warm Mandi gold (`#F59E0B`).
- **Tactile Micro-Interactions**: Spring-physics camera shutter button with haptic feedback (`AppHaptics.medium()`), animated reticle corner brackets, and glowing dual-gradient laser sweep.
- **Dual-Mode Review**:
  - **ٹیبل موڈ (Structured Table)**: Editable item rows with quick weight chips (25, 30, 40, 50 kg), +/- steppers, and Pakistani Mandi math solver ($Total = round(Weight \times Rate / 40)$).
  - **متن کا بہاؤ (Bilingual Stream)**: Unicode-aware text cards distinguishing Urdu Nastaliq (RTL) from English Latin (LTR) with one-tap clipboard copy.
- **Scan Vault (محفوظ شدہ رسیدیں)**: Non-blocking asynchronous local document archive with live metrics (Total Invoices, Maunds, PKR) and instant full-text search.
- **Direct Excel Export & Share**: Generates styled `.xlsx` spreadsheets locally and opens them immediately in Excel or shares via WhatsApp.

---

## 🏗️ Directory Structure

```
bill_ocr_app/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart          # API URLs, color tokens, status stages
│   │   ├── theme/
│   │   │   └── app_theme.dart              # Obsidian theme, haptic helpers & typography
│   │   └── utils/
│   │       ├── responsive.dart             # ResponsiveLayout, dynamic clamps & containers
│   │       ├── text_direction_helper.dart  # Unicode block classifier (Urdu RTL vs Latin LTR)
│   │       └── formatters.dart             # Rs./PKR currency & kg/Maund weight formatters
│   ├── models/
│   │   ├── ocr_bill_item.dart              # Immutable line item model with Mandi price recalculator
│   │   ├── ocr_scan_result.dart            # Complete bill schema (bill#, customer, date, line items, totals)
│   │   └── scan_history_entry.dart         # Local vault archive schema
│   ├── services/
│   │   ├── image_processor_service.dart    # Isolate-based normalization, contrast & thumbnails
│   │   ├── ocr_pipeline_service.dart       # HTTP client connecting to offline Python OCR backend
│   │   ├── scan_history_service.dart       # Asynchronous local vault storage (save, search, delete)
│   │   └── excel_export_service.dart       # Styled Excel (.xlsx) generator, OpenFilex & SharePlus
│   ├── controllers/
│   │   ├── ocr_scan_state.dart             # Riverpod state machine (Initial, Cropping, Processing, Ready, Error)
│   │   ├── ocr_scan_controller.dart        # Riverpod 3.x Notifier orchestrating camera, cropping, and edits
│   │   └── history_controller.dart         # Riverpod Notifier for instant search and status filtering
│   ├── views/
│   │   ├── splash/
│   │   │   └── animated_splash_screen.dart # 60fps logo pulse & background permission check
│   │   ├── scanner/
│   │   │   ├── ocr_scanner_screen.dart     # Responsive intake dashboard (Camera / Gallery / Demo)
│   │   │   ├── scanning_animation_overlay.dart # Laser beam scan loop + dynamic progress status chips
│   │   │   └── components/
│   │   │       ├── viewfinder_reticle.dart # Custom-painted corner brackets & pulsing laser beam
│   │   │       └── camera_shutter_button.dart # Tactile spring shutter with haptic feedback
│   │   ├── result/
│   │   │   ├── ocr_result_table_screen.dart# Editable DataTable, Grand Totals, Excel & Share Bar
│   │   │   └── components/
│   │   │       └── bilingual_text_card.dart# RTL/LTR auto-detected card with copy action
│   │   └── history/
│   │       └── scan_history_screen.dart    # Scan Vault metrics overview & search/filter archive
│   └── main.dart                           # Riverpod ProviderScope root & portrait orientation setup
└── test/
    ├── unit_test.dart                      # Mandi math, script classifier & storage filtering tests
    └── widget_test.dart                    # App launch & splash-to-scanner navigation smoke tests
```

---

## ⚡ How to Run

### 1. Ensure the Local Python OCR Server is Active
From the root repository:
```powershell
# In d:\OCR project
& ".\.venv\Scripts\python.exe" "api_server.py"
```

### 2. Forward Ports for Physical Mobile Testing
```powershell
& "C:\Android\sdk\platform-tools\adb.exe" reverse tcp:5000 tcp:5000
```

### 3. Launch the Flutter App
```powershell
cd "d:\OCR project\bill_ocr_app"
flutter pub get
flutter run
```

### 4. Run the Automated Tests
```powershell
flutter test
```
*All 6 unit and widget test suites execute and verify model math, Excel generation, Unicode classification, and responsive navigation.*
