import firebase_admin
from firebase_admin import messaging

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
