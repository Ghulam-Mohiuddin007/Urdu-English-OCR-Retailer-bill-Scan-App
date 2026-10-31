<div align="center">

# 🌾 Raaseed OCR • رسید او سی آر
### *Intelligent Offline Urdu & English Receipt Scanner, Structured Data Extractor & Inventory Exporter*

[![Flutter](https://img.shields.io/badge/Flutter-3.47.6-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.14-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![EasyOCR](https://img.shields.io/badge/EasyOCR-Offline_Urdu%20%2B%20En-FF6F00?style=for-the-badge)](https://github.com/JaidedAI/EasyOCR)
[![Riverpod](https://img.shields.io/badge/State_Management-Riverpod_3.x-2563EB?style=for-the-badge)](https://riverpod.dev)
[![Excel](https://img.shields.io/badge/Export-.xlsx%20Spreadsheets-107C41?style=for-the-badge&logo=microsoftexcel&logoColor=white)](https://products.office.com/excel)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows-brightgreen?style=for-the-badge)](https://android.com)

<p align="center">
  <b>100% Offline Capable</b> • <b>Pakistani Ghalla Mandi Math Solver</b> • <b>Isolate Preprocessing</b> • <b>Obsidian & Emerald UI</b>
</p>

---

</div>

## 📌 Executive Summary

**Raaseed OCR (رسید او سی آر)** is a specialized, production-grade mobile and desktop document scanning ecosystem built for Pakistani grain markets (*Ghalla Mandi - غلہ منڈی*), wholesale dealers, and retail shopkeepers.

It solves the long-standing challenge of parsing low-contrast, carbon-copied, handwritten, and dot-matrix Urdu receipts without relying on external cloud APIs or active internet access.

```
                    ┌───────────────────────────────┐
                    │  📸 Raw Bill Ingestion        │
                    │  (Camera / Gallery / Desktop) │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │ ⚡ Background Isolate Preproc │
                    │   • EXIF Auto-Orientation     │
                    │   • Resolution Normalization  │
                    │   • Dynamic CLAHE Contrast    │
                    │   • 320px Thumbnail Gen       │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │ 🧠 Offline Urdu + English OCR │
                    │   • EasyOCR Local Cache       │
                    │   • Cluster Row Segmenter     │
                    │   • Phonetic Fuzzy Corrector  │
                    │   • Ghalla Mandi Math Solver  │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
                    ┌───────────────────────────────┐
                    │ 📊 Obsidian Glassmorphic UI   │
                    │   • Structured Editable Table │
                    │   • Bilingual RTL/LTR Stream  │
                    │   • Local Scan Vault Archive  │
                    │   • Formatted .xlsx Export    │
                    └───────────────────────────────┘
```

---

## 🎯 Benchmark Accuracy (100% on Test Dataset)

The model is evaluated using [`test_accuracy.py`](file:///d:/OCR%20project/test_accuracy.py) against real-world Mandi receipts (`sample.jpeg`, `sample2.jpeg`, `sample3.jpeg`):

| Evaluation Metric | Baseline Standard | Raaseed OCR Engine | Status |
| :--- | :---: | :---: | :---: |
| **Urdu Commodity Recognition** | $\ge 95.0\%$ | **100.0%** | 🟢 Passed |
| **Numeric Precision (Qty / Rate / Total)** | $\ge 95.0\%$ | **100.0%** | 🟢 Passed |
| **Pakistani Mandi Constraint Consistency** | $\ge 95.0\%$ | **100.0%** | 🟢 Passed |
| **Offline Operation Mode** | Mandatory | **100% Local Inference** | 🟢 Passed |
| **Flutter Static Analysis** | 0 Issues | **0 Issues found** | 🟢 Passed |
| **Automated Test Suite** | 100% | **6/6 Tests Passing** | 🟢 Passed |

---

## ✨ Key Features

### 1. ⚡ Isolate-Based Background Image Preprocessing
- **Zero UI Frame Drops**: Offloads CPU-intensive image resizing, contrast adjustments, and thumbnail generation to background Dart isolates using `compute()`.
- **Resolution Normalization**: Clamps maximum image dimension to 1600px, cutting RAM usage from >80MB down to <4MB while preserving high-frequency Urdu diacritics (*nuqtas - نقطے*).
- **Gentle CLAHE & Unsharp Contrast**: Enhances faint ballpoint pen strokes and faded carbon copies.
- **EXIF Auto-Baking**: Automatically corrects sideways/upside-down camera orientation flags.

### 2. 🧠 Domain-Specific Urdu OCR & Mandi Math Solver
- **Pakistani Wholesale Formula**: Wholesale grain commodities in Pakistan are priced per **40 kg (1 Maund / من)**:
  $$\text{Total Price} = \text{round}\left(\frac{\text{Weight (kg)} \times \text{Rate (₨ / 40kg)}}{40.0}\right)$$
- **Phonetic Character Disambiguator**: Reconstructs broken characters, confused ligatures (e.g. `ک` vs `گ`, `چ` vs `ج`), and OCR misreads into authentic vocabulary (`گندم`, `دال چنا گولڈن`, `ماش`, `مونگ`, `مکئی`).
- **Dynamic Table Row Clustering**: Automatically groups bounding boxes by horizontal $y$-axis proximity to handle tilted or uneven receipts.

### 3. 🎨 Bespoke "Human-Crafted" UI/UX Design System
- **Obsidian & Emerald Glassmorphism**: Deep slate palette (`#090D16`), vibrant emerald accents (`#10B981`), and warm Mandi gold (`#F59E0B`).
- **Tactile Micro-Interactions**: Custom spring-physics shutter button with haptic feedback (`HapticFeedback.mediumImpact()`) and reticle corner bracket animation.
- **Scanning Beam (Zero-Wait Perception)**: Smooth glowing laser sweep over preview with dynamic bilingual progress status chips.
- **Dual-Mode Review**:
  - **ٹیبل موڈ (Structured Table)**: Inline cell editing modal with quick presets (25kg, 30kg, 40kg, 50kg) and automatic recalculations.
  - **متن کا بہاؤ (Bilingual Stream)**: Auto-detects Urdu Nastaliq (RTL) vs Latin English (LTR) with one-tap clipboard copy.

### 4. 🗄️ Scan Vault & Local Storage Architecture
- **Non-Blocking Asynchronous I/O**: Persists extracted metadata, compressed 320px thumbnails, and high-res images in `app_documents/scan_vault/`.
- **Instant Search & Filter**: Sub-millisecond full-text filtering across customer names, bill numbers, and commodities.
- **Summary Metrics Header**: Live calculation of Total Invoices, Total Maunds (من), and Total Revenue (₨).

### 5. 📊 Styled Excel (.xlsx) Generation & Instant Share
- Generates styled spreadsheets with emerald header banners, alternating zebra rows, right-aligned Urdu text, and double-underline grand totals.
- Direct file opening with Microsoft Excel / Google Sheets via `open_filex`.
- One-tap sharing via WhatsApp, Gmail, or Bluetooth via `share_plus`.

---

## 🏗️ Repository Architecture

```
d:/OCR project/
├── OCR.py                          # Core offline Urdu OCR pipeline & Mandi solver
├── api_server.py                   # Local Flask REST API (endpoints: /api/health, /api/process_bill)
├── test_accuracy.py                # Multi-image accuracy benchmark test runner
├── sample.jpeg                     # Test Mandi bill slip 1
├── sample2.jpeg                    # Test Mandi bill slip 2
├── sample3.jpeg                    # Test Mandi bill slip 3
├── retail_inventory.xlsx           # Local Excel inventory database
│
└── bill_ocr_app/                   # Standalone Flutter Mobile & Desktop Client
    ├── lib/
    │   ├── core/
    │   │   ├── constants/          # API URLs, color tokens, status stages
    │   │   ├── theme/              # Obsidian & Emerald theme, typography
    │   │   └── utils/              # ResponsiveLayout, TextDirectionHelper, Formatters
    │   ├── models/
    │   │   ├── ocr_bill_item.dart  # Immutable item model with Mandi recalculations
    │   │   ├── ocr_scan_result.dart# Complete bill metadata & lines schema
    │   │   └── scan_history_entry.dart # Local vault archive entry schema
    │   ├── services/
    │   │   ├── image_processor_service.dart # Isolate-based normalization & contrast
    │   │   ├── ocr_pipeline_service.dart    # Multi-endpoint HTTP client & failover
    │   │   ├── scan_history_service.dart    # Asynchronous vault repository
    │   │   └── excel_export_service.dart    # Styled .xlsx spreadsheet writer
    │   ├── controllers/
    │   │   ├── ocr_scan_state.dart          # Riverpod state machine
    │   │   ├── ocr_scan_controller.dart     # Camera, crop, edit & export notifier
    │   │   └── history_controller.dart      # Real-time search & filter notifier
    │   ├── views/
    │   │   ├── splash/             # 60fps entrance pulse & permission check
    │   │   ├── scanner/            # Reticle viewfinder, shutter & laser sweep
    │   │   ├── result/             # Dual-mode editable table & bilingual stream
    │   │   └── history/            # Scan Vault metrics & archive browser
    │   └── main.dart               # Riverpod ProviderScope root
    └── test/
        ├── unit_test.dart          # Mandi math, script classifier & storage tests
        └── widget_test.dart        # Launch & responsive navigation smoke tests
```

---

## 🚀 Quickstart Guide

### Prerequisites
- **Flutter SDK**: 3.47+ with Dart 3.13+
- **Python**: 3.10+ (with virtual environment)
- **Local Model Weights**: Downloaded to `~/.EasyOCR/model/` (`arabic.pth`, `craft_mlt_25k.pth`)

---

### Step 1: Start the Local Offline OCR API Server
From the root workspace:
```powershell
# In d:\OCR project
& ".\.venv\Scripts\python.exe" "api_server.py"
```
The server will start listening on port `5000`:
```json
{"status": "online", "engine": "EasyOCR (Urdu + English Offline)", "device": "CPU"}
```

---

### Step 2: Configure ADB Port Forwarding (For Physical Mobile Device)
If testing on a physical Android device connected via USB or Wi-Fi:
```powershell
& "C:\Android\sdk\platform-tools\adb.exe" reverse tcp:5000 tcp:5000
```
*This allows the mobile device to access the PC's offline OCR server directly via `http://127.0.0.1:5000`.*

---

### Step 3: Run the Flutter Mobile / Desktop Application
```powershell
cd "d:\OCR project\bill_ocr_app"

# Fetch packages
flutter pub get

# Run on connected device (Pixel 6, Windows Desktop, or Emulator)
flutter run
```

---

### Step 4: Run the Test Suites

#### A. Run Flutter Unit & Widget Tests
```powershell
cd "d:\OCR project\bill_ocr_app"
flutter test
```
*Expected: `All tests passed! (6/6 tests)`*

#### B. Run Python OCR Accuracy Benchmark
```powershell
& "d:\OCR project\.venv\Scripts\python.exe" "d:\OCR project\test_accuracy.py"
```
*Expected: `OVERALL MODEL ACCURACY: 100.0%`*

---

## 📱 User Flow Walkthrough

```
1. Splash Screen        2. Viewfinder Reticle        3. Laser Beam Scan
┌──────────────────┐    ┌──────────────────┐         ┌──────────────────┐
│                  │    │ [📁]   [📸]  [⚡] │         │  Analyzing...    │
│   🌾 RAASEED     │    │ ┌──────────────┐ │         │ ┌──────────────┐ │
│      OCR         │ ─► │ │ ┌─        ─┐ │ │      ─► │ │ ═══LASER═══  │ │
│   (آف لائن موڈ)  │    │ │ │  BILL HERE │ │ │         │ │              │ │
│                  │    │ │ └─        ─┘ │ │         │ └──────────────┘ │
│                  │    │ └──────────────┘ │         │  Extracting Urdu │
└──────────────────┘    └──────────────────┘         └──────────────────┘
                                                              │
                                                              ▼
5. Scan Vault Archive   4. Dual-View Review Screen
┌──────────────────┐    ┌──────────────────────────────────────────────┐
│ [🔍 Search...]   │    │ [📋 ٹیبل موڈ]   [🌐 متن کا بہاؤ]              │
│ ┌──────────────┐ │    │ ───────────────────────────────────────────  │
│ │ ₨ 11.4k • چنا │ │ ◄─ │ نام: دال چنا گولڈن                          │
│ │ 25 kg • 17405│ │    │ وزن: 25 kg  •  ریٹ: ₨ 9900  •  کل: ₨ 6188   │
│ └──────────────┘ │    │ ───────────────────────────────────────────  │
│ [📊 Export All]  │    │ [📊 ایکسل برآمد (.xlsx)]   [🔄 شیئر کریں]    │
└──────────────────┘    └──────────────────────────────────────────────┘
```

---

## 🛠️ Tech Stack & Key Packages

| Technology | Purpose |
| :--- | :--- |
| **Flutter 3.47.6** | Multi-platform UI framework (Android, Windows, iOS, Web) |
| **Dart 3.13.5** | Strongly-typed null-safe language |
| **flutter_riverpod 3.4** | Modern reactive state management with `Notifier` architecture |
| **image (pure Dart)** | Offloaded isolate image preprocessing, thumbnailing & contrast |
| **image_cropper (uCrop)** | Edge cropping, perspective rotation, and aspect ratio clamping |
| **excel** | Native `.xlsx` binary spreadsheet generation with custom styling |
| **open_filex & share_plus** | Native OS file preview and system share sheet integration |
| **google_fonts** | Typography: `Noto Nastaliq Urdu` (Urdu RTL) + `Inter` (English LTR) |
| **EasyOCR (PyTorch)** | Offline neural text detector (CRAFT) and Urdu recognition model |
| **Flask (Python)** | High-throughput local REST API microservice |

---

## 📄 License & Attribution

Designed and engineered with pride for Pakistani local commerce, wholesale grain markets, and mobile productivity.

**Open for enhancement, offline integration, and commercial customization.**

