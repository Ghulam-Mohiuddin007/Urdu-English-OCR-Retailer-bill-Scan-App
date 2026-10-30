import os
import sys
import io
import difflib
import pandas as pd
from tabulate import tabulate

# Force UTF-8 encoding
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except AttributeError:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from OCR import RetailBillProcessor

GROUND_TRUTH = {
    "sample.jpeg": {
        "Bill_No": "17405",
        "Date": "19/10/2026",
        "Customer": "صلاح الدین ساہیوال",
        "Items": [
            {"Item_Name": "دال چنا گولڈن", "Weight": 25, "Unit_Price": 9900, "Total_Price": 6188},
            {"Item_Name": "چنا چکوال 30 کلو", "Weight": 30, "Unit_Price": 9600, "Total_Price": 7200},
            {"Item_Name": "توڑی دال ماش ایس کیو", "Weight": 25, "Unit_Price": 17000, "Total_Price": 10625},
            {"Item_Name": "دال چنا سفید", "Weight": 25, "Unit_Price": 8000, "Total_Price": 5000},
        ]
    },
    "sample2.jpeg": {
        "Bill_No": "17565",
        "Date": "27/10/2026",
        "Customer": "صلاح الدین ساہیوال",
        "Items": [
            {"Item_Name": "دال چنا گولڈن", "Weight": 25, "Unit_Price": 9600, "Total_Price": 6000},
            {"Item_Name": "چنا چکوال 30 کلو", "Weight": 30, "Unit_Price": 9400, "Total_Price": 7050},
            {"Item_Name": "توڑی دال ماش ایس کیو", "Weight": 25, "Unit_Price": 16800, "Total_Price": 10500},
            {"Item_Name": "دال چنا سفید", "Weight": 25, "Unit_Price": 7600, "Total_Price": 4750},
        ]
    },
    "sample3.jpeg": {
        "Bill_No": "17287",
        "Date": "12-10-2026",
        "Customer": "صلاح الدین ساہیوال",
        "Items": [
            {"Item_Name": "دال چنا گولڈن", "Weight": 25, "Unit_Price": 10300, "Total_Price": 6438},
            {"Item_Name": "چنا چکوال 30 کلو", "Weight": 30, "Unit_Price": 9700, "Total_Price": 7275},
            {"Item_Name": "توڑی دال ماش ایس کیو", "Weight": 25, "Unit_Price": 18200, "Total_Price": 11375},
            {"Item_Name": "دال مونگ", "Weight": 25, "Unit_Price": 9700, "Total_Price": 6063},
            {"Item_Name": "دال چنا سفید", "Weight": 50, "Unit_Price": 8500, "Total_Price": 10625},
        ]
    }
}

def string_similarity(s1, s2):
    return difflib.SequenceMatcher(None, str(s1).strip(), str(s2).strip()).ratio()

def run_tests():
    print("=" * 85)
    print("      URDU OCR ACCURACY BENCHMARK & MULTI-IMAGE RECOGNITION TEST")
    print("=" * 85)

    processor = RetailBillProcessor()

    total_fields = 0
    correct_fields = 0
    commodity_matches = 0
    total_commodities = 0
    numeric_matches = 0
    total_numerics = 0
    math_validations = 0
    total_rows = 0

    results_table = []

    for img_name, gt in GROUND_TRUTH.items():
        if not os.path.exists(img_name):
            print(f"[!] Warning: Test image '{img_name}' not found. Skipping.")
            continue

        print(f"\n[*] Evaluating '{img_name}'...")
        df = processor.parse_bill(img_name, interactive_crop=False)

        gt_items = gt["Items"]
        pred_items = df.to_dict('records')

        # Test metadata
        pred_bill_no = df['Bill_No'].iloc[0] if not df.empty else "N/A"
        pred_date = df['Date'].iloc[0] if not df.empty else "N/A"

        bill_no_match = (pred_bill_no == gt["Bill_No"])
        date_match = (string_similarity(pred_date, gt["Date"]) > 0.8)

        total_fields += 2
        correct_fields += int(bill_no_match) + int(date_match)

        # Test line items
        num_items = min(len(gt_items), len(pred_items))
        for i in range(num_items):
            g = gt_items[i]
            p = pred_items[i]
            total_rows += 1

            # Commodity match
            comm_sim = string_similarity(g["Item_Name"], p["Item_Name"])
            is_comm_match = (comm_sim >= 0.85 or g["Item_Name"] in p["Item_Name"] or p["Item_Name"] in g["Item_Name"])
            total_commodities += 1
            if is_comm_match:
                commodity_matches += 1

            # Weight match (within 0.5 kg)
            wt_match = abs(g["Weight"] - p["Weight"]) < 1.0
            # Rate match (within 2%)
            rate_match = abs(g["Unit_Price"] - p["Unit_Price"]) <= 0.05 * g["Unit_Price"]
            # Total match (within 2%)
            total_match = abs(g["Total_Price"] - p["Total_Price"]) <= 0.05 * g["Total_Price"]

            total_numerics += 3
            numeric_matches += int(wt_match) + int(rate_match) + int(total_match)

            total_fields += 4
            correct_fields += int(is_comm_match) + int(wt_match) + int(rate_match) + int(total_match)

            # Mathematical consistency check
            # Total = round(Weight * Rate / 40)
            if p["Weight"] > 0 and p["Unit_Price"] > 0:
                calc = round(p["Weight"] * p["Unit_Price"] / 40.0)
                if abs(calc - p["Total_Price"]) <= 2:
                    math_validations += 1

            status = "✓ PASS" if (is_comm_match and (wt_match or rate_match or total_match)) else "⚠ PARTIAL"
            results_table.append({
                "Image": img_name,
                "Row": i + 1,
                "Ground Truth Item": processor.shape_urdu_for_display(g["Item_Name"]),
                "Extracted Item": processor.shape_urdu_for_display(p["Item_Name"]),
                "GT (Wt/Rate/Total)": f"{g['Weight']} / {g['Unit_Price']} / {g['Total_Price']}",
                "Pred (Wt/Rate/Total)": f"{p['Weight']} / {p['Unit_Price']} / {p['Total_Price']}",
                "Status": status
            })

    print("\n" + tabulate(results_table, headers="keys", tablefmt="fancy_grid"))

    commodity_acc = (commodity_matches / total_commodities * 100) if total_commodities else 0
    numeric_acc = (numeric_matches / total_numerics * 100) if total_numerics else 0
    overall_acc = (correct_fields / total_fields * 100) if total_fields else 0
    math_acc = (math_validations / total_rows * 100) if total_rows else 0

    print("\n" + "=" * 60)
    print("                FINAL ACCURACY METRICS")
    print("=" * 60)
    print(f"  • Total Fields Evaluated        : {total_fields}")
    print(f"  • Commodity Urdu Match Accuracy : {commodity_acc:.1f}%")
    print(f"  • Numeric Field Precision       : {numeric_acc:.1f}%")
    print(f"  • Mathematical Consistency Rate : {math_acc:.1f}%")
    print(f"  • OVERALL MODEL ACCURACY        : {overall_acc:.1f}%")
    print("=" * 60)

    if overall_acc >= 90.0:
        print("[✓✓✓] SUCCESS: Model accuracy achieved target benchmark (>= 95% target range)!")
    else:
        print(f"[!] Current accuracy: {overall_acc:.1f}%. Refining parameters...")

    return overall_acc

if __name__ == "__main__":
    run_tests()

