"""Comprehensive probe of WhitsunPay with the NEW API key."""
import requests

CLIENT_ID = "019e8ba678a27f00bc19c3757989ed0b"
API_KEY = "wp_live_68d1S1eWkai78_KHCvfRFir6X7o7VOL1nwD8V11tMr"

headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'x-client-id': CLIENT_ID,
    'x-api-key': API_KEY,
}

test_payload = {
    'transactionReference': 'TEST-PROBE-002',
    'description': 'Connection test',
    'amount': '0.01',
    'debitParty': {
        'msisdn': '233550000000',
        'provider': 'mtn'
    }
}

urls = [
    "https://developer.whitsun.dev/api/v1/payments",
    "https://developer.whitsun.dev/v1/payments",
    "https://developer.whitsun.dev/payments",
    "https://developer.whitsun.dev/api/payments",
    "https://developer.whitsun.dev/api/v1/payment",
    "https://developer.whitsun.dev/api/v1/transactions",
    "https://developer.whitsun.dev/api/v1/charge",
    "https://developer.whitsun.dev/api/v1/collect",
    "https://developer.whitsun.dev/api/v1/momo/payments",
    "https://mmapi.whitsun.dev/api/v1/payments",
]

print("Client ID: " + CLIENT_ID)
print("API Key:   " + API_KEY[:20] + "..." + API_KEY[-4:])
print("=" * 60)

for url in urls:
    try:
        res = requests.post(url, json=test_payload, headers=headers, timeout=10)
        tag = "[OK]" if res.status_code in [200, 201, 202] else "[!!]" if res.status_code != 404 else "[--]"
        print("")
        print(tag + " " + url)
        print("    Status: " + str(res.status_code))
        try:
            body = res.json()
            print("    Body:   " + str(body))
        except:
            text = res.text[:150]
            print("    Body:   " + (text if text else "(empty)"))
    except Exception as e:
        print("")
        print("[ERR] " + url)
        print("    ERROR: " + str(e)[:80])

print("")
print("=" * 60)
print("Look for [OK] (200/201) or [!!] (non-404) responses.")
