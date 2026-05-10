import { useEffect } from 'react';
import { PushNotifications } from '@capacitor/push-notifications';
import { Capacitor } from '@capacitor/core';

export const usePushNotifications = () => {
  useEffect(() => {
    if (Capacitor.getPlatform() === 'web') {
        console.log('[Push] Running on web, skipping native push registration.');
        return;
    }

    const registerPush = async () => {
      console.log('[Push] Checking permissions...');
      let permStatus = await PushNotifications.checkPermissions();
      console.log('[Push] Current permission status:', permStatus.receive);

      if (permStatus.receive === 'prompt') {
        console.log('[Push] Requesting permissions...');
        permStatus = await PushNotifications.requestPermissions();
        console.log('[Push] Permission requested result:', permStatus.receive);
      }

      if (permStatus.receive !== 'granted') {
        console.warn('[Push] Notification permission denied');
        return;
      }

      console.log('[Push] Registering with Firebase...');
      await PushNotifications.register();
    };

    // On success, we should be able to receive notifications
    PushNotifications.addListener('registration', (token) => {
      console.log('[Push] Registration success. Token:', token.value);

      // Send token to backend
      const memberToken = localStorage.getItem('cubag_token');
      if (memberToken) {
        console.log('[Push] Sending token to backend...');
        fetch(`${import.meta.env.VITE_API_URL}/auth/update-fcm-token`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${memberToken}`
          },
          body: JSON.stringify({ token: token.value })
        })
        .then(res => res.json())
        .then(data => console.log('[Push] Backend update result:', data))
        .catch(err => console.error('[Push] Failed to update FCM token on server', err));
      } else {
        console.warn('[Push] No member token found in storage, skipping backend sync.');
      }
    });

    // Some error occurred
    PushNotifications.addListener('registrationError', (error) => {
      console.error('[Push] Error on registration:', JSON.stringify(error));
    });

    // Show us the notification payload if the app is open on our device
    PushNotifications.addListener('pushNotificationReceived', (notification) => {
      console.log('[Push] Notification received while app open:', JSON.stringify(notification));
    });

    // Method called when tapping on a notification
    PushNotifications.addListener('pushNotificationActionPerformed', (notification) => {
      console.log('[Push] Notification action performed:', JSON.stringify(notification));
    });

    registerPush();

    return () => {
      console.log('[Push] Removing listeners');
      PushNotifications.removeAllListeners();
    };
  }, []);
};
