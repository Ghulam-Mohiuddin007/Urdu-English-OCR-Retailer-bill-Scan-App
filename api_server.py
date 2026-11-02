import os
import tempfile
import sys
import io

# Ensure UTF-8 output encoding
if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except AttributeError:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

from flask import Flask, request, jsonify
from OCR import RetailBillProcessor

app = Flask(__name__)

# Initialize processor once at startup
print("[*] Starting Raaseed OCR Backend Server...")
processor = RetailBillProcessor()
print("[✓] Raaseed OCR Backend ready to receive requests.")


@app.after_request
def add_cors_headers(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
    return response


@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "online",
        "engine": "EasyOCR (Urdu + English Offline)",
        "device": "CUDA" if processor.use_gpu else "CPU"
    })


@app.route('/api/process_bill', methods=['POST', 'OPTIONS'])
def process_bill_endpoint():
    if request.method == 'OPTIONS':
        return jsonify({"status": "ok"})

    if 'file' not in request.files and 'image' not in request.files:
        return jsonify({"success": False, "error": "No image file provided in request."}), 400

    uploaded_file = request.files.get('file') or request.files.get('image')
    if uploaded_file.filename == '':
        return jsonify({"success": False, "error": "Empty filename."}), 400

    # Save to temp file
    suffix = os.path.splitext(uploaded_file.filename)[1] or '.jpg'
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_img:
        temp_path = temp_img.name
        uploaded_file.save(temp_path)

    try:
        print(f"[*] Processing incoming image: {uploaded_file.filename} ({temp_path})")
        df = processor.parse_bill(temp_path, interactive_crop=False)

        items = []
        bill_no = "N/A"
        date_str = "N/A"
        customer = "صلاح الدین ساہیوال"

        if not df.empty:
            bill_no = str(df['Bill_No'].iloc[0])
            date_str = str(df['Date'].iloc[0])
            customer = str(df['Customer'].iloc[0])

            for _, row in df.iterrows():
                items.append({
                    "item_name": str(row['Item_Name']),
                    "quantity": float(row.get('Quantity', 1.0)),
                    "weight": float(row.get('Weight', 0.0)),
                    "unit_price": float(row.get('Unit_Price', 0.0)),
                    "total_price": float(row.get('Total_Price', 0.0)),
                    "status": str(row.get('Status', 'Verified'))
                })

        total_weight = sum(item['weight'] for item in items)
        subtotal = sum(item['total_price'] for item in items)

        return jsonify({
            "success": True,
            "metadata": {
                "bill_no": bill_no,
                "date": date_str,
                "biller_date": date_str,
                "customer": customer
            },
            "items": items,
            "summary": {
                "total_items": len(items),
                "total_weight": total_weight,
                "total_weight_kg": total_weight,
                "subtotal": subtotal,
                "subtotal_rs": subtotal,
                "commission_rs": 0.0,
                "grand_total_rs": subtotal
            }
        })

    except Exception as e:
        print(f"[!] Error processing image: {e}")
        return jsonify({"success": False, "error": str(e)}), 500
    finally:
        if os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except Exception:
                pass


@app.route('/api/inventory', methods=['GET'])
def get_inventory():
    """Returns current inventory items from retail_inventory.xlsx."""
    try:
        import pandas as pd
        excel_path = processor.excel_path
        if not os.path.exists(excel_path):
            return jsonify({"success": True, "items": []})

        df = pd.read_excel(excel_path, sheet_name="Stock")
        items = []
        for _, row in df.iterrows():
            items.append({
                "commodity_name": str(row.get('Item_Name', '')),
                "stock_weight_kg": float(row.get('Weight', 0.0)),
                "last_purchase_rate": float(row.get('Unit_Price', 0.0)),
                "total_stock_value": float(row.get('Total_Price', 0.0)),
                "last_bill_no": str(row.get('Bill_No', '')),
                "last_biller_date": str(row.get('Date', '')),
                "last_supplier": str(row.get('Customer', '')),
            })
        return jsonify({"success": True, "items": items})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/api/add_to_inventory', methods=['POST', 'OPTIONS'])
def add_to_inventory_endpoint():
    """Adds bill items into retail_inventory.xlsx."""
    if request.method == 'OPTIONS':
        return jsonify({"status": "ok"})

    data = request.get_json(silent=True) or {}
    bill_no = data.get('bill_no', 'N/A')
    date_str = data.get('biller_date', 'N/A')
    customer = data.get('customer', 'صلاح الدین ساہیوال')
    raw_items = data.get('items', [])

    if not raw_items:
        return jsonify({"success": False, "error": "No items provided."}), 400

    try:
        import pandas as pd
        rows = []
        for item in raw_items:
            rows.append({
                "Bill_No": bill_no,
                "Date": date_str,
                "Customer": customer,
                "Item_Name": item.get('item_name', item.get('commodity', 'نامعلوم')),
                "Quantity": float(item.get('quantity', 1.0)),
                "Weight": float(item.get('weight', 0.0)),
                "Unit_Price": float(item.get('unit_price', 0.0)),
                "Total_Price": float(item.get('total_price', 0.0)),
                "Status": "Verified"
            })
        df = pd.DataFrame(rows)
        processor.update_excel_inventory(df)
        return jsonify({"success": True, "message": f"{len(rows)} items added to inventory."})
    except Exception as e:
        print(f"[!] Error updating inventory: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    print(f"[*] OCR API Server listening on http://0.0.0.0:{port}")
    app.run(host='0.0.0.0', port=port, debug=False)

