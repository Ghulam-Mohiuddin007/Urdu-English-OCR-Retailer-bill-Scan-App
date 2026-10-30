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
                "customer": customer
            },
            "items": items,
            "summary": {
                "total_items": len(items),
                "total_weight": total_weight,
                "subtotal": subtotal
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


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    print(f"[*] OCR API Server listening on http://0.0.0.0:{port}")
    app.run(host='0.0.0.0', port=port, debug=False)

