import os
import firebase_admin
from firebase_admin import credentials, messaging
from config.db import get_db

def send_push_notification(fcm_token, title, body, data=None):
    """
    Sends a push notification to a specific device using FCM.
    """
    if not fcm_token:
        return False
        
    try:
        # Check if Firebase is initialized
        if not firebase_admin._apps:
            print("Firebase not initialized. Cannot send push notification.")
            return False

        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data if data else {},
            token=fcm_token,
        )
        
        response = messaging.send(message)
        print(f"Successfully sent message: {response}")
        return True
    except Exception as e:
        print(f"Error sending push notification: {e}")
        return False

# Load service account from environment variable (JSON string) or file
# Primary env variable used across the system is FIREBASE_CREDENTIALS_JSON
service_account_json = os.getenv('FIREBASE_CREDENTIALS_JSON') or os.getenv('FIREBASE_SERVICE_ACCOUNT')

def _init_firebase():
    """Initializes the Firebase Admin SDK if not already initialized."""
    try:
        firebase_admin.get_app()
    except ValueError:
        if service_account_json:
            import json
            try:
                cred_dict = json.loads(service_account_json)
                cred = credentials.Certificate(cred_dict)
                firebase_admin.initialize_app(cred)
                print("[Push] Firebase Admin initialized from ENV.")
            except Exception as e:
                print(f"[Push] Error parsing FIREBASE_CREDENTIALS_JSON: {e}")
                return False
        elif os.path.exists('firebase-service-account.json'):
            cred = credentials.Certificate('firebase-service-account.json')
            firebase_admin.initialize_app(cred)
            print("[Push] Firebase Admin initialized from FILE.")
        elif os.path.exists('planning-with-ai-a2368-firebase-adminsdk-fbsvc-3f0078de77.json'):
            cred = credentials.Certificate('planning-with-ai-a2368-firebase-adminsdk-fbsvc-3f0078de77.json')
            firebase_admin.initialize_app(cred)
            print("[Push] Firebase Admin initialized from LEGACY FILE.")
        else:
            print("[Push] Firebase Credentials not found. Skipping push.")
            return False
    return True

def send_push_to_all(title, body, data=None):
    """
    Sends a push notification to all members who have an fcm_token registered.
    Uses the modern FCM V1 API via Firebase Admin SDK.
    """
    if not _init_firebase():
        return

    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT fcm_token FROM members WHERE fcm_token IS NOT NULL")
            tokens = [row['fcm_token'] for row in cursor.fetchall()]

        print(f"[DEBUG] Push notification triggered. Found {len(tokens)} tokens in DB.")

        if not tokens:
            return

        # Prepare the message data (must be strings)
        string_data = {k: str(v) for k, v in (data or {}).items()}

        # Multicast message allows sending to up to 500 tokens at once
        for i in range(0, len(tokens), 500):
            batch = tokens[i:i+500]
            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=string_data,
                tokens=batch,
            )
            try:
                response = messaging.send_multicast(message)
                print(f"[Push] Batch sent: {response.success_count} success, {response.failure_count} failure")

                # Cleanup invalid tokens if any (optional but recommended)
                if response.failure_count > 0:
                    for index, resp in enumerate(response.responses):
                        if not resp.success:
                            # Token is invalid (e.g. app uninstalled) - could delete from DB here
                            pass
            except Exception as e:
                print(f"[Push] Error sending batch: {e}")

    except Exception as e:
        print(f"[Push] Database error: {e}")
    finally:
        conn.close()
