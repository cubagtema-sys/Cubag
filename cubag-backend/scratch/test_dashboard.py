import requests

base_url = "http://127.0.0.1:8080/api"

def test_sub_admin_dashboard():
    # Login
    login_payload = {
        "email": "Membershipofficer@cubag.com",
        "password": "Cubag@2026"
    }
    r = requests.post(f"{base_url}/auth/login", json=login_payload)
    print("Login Status:", r.status_code)
    if r.status_code != 200:
        print("Login failed:", r.text)
        return
        
    token = r.json().get("token")
    print("Token obtained successfully.")
    
    # Fetch dashboard
    headers = {"Authorization": f"Bearer {token}"}
    d = requests.get(f"{base_url}/admin/dashboard", headers=headers)
    print("Dashboard Status:", d.status_code)
    print("Dashboard Response:", d.text)

if __name__ == "__main__":
    test_sub_admin_dashboard()
