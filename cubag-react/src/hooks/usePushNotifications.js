import { useEffect } from 'react';
import { PushNotifications } from '@capacitor/push-notifications';
import { Capacitor } from '@capacitor/core';

export const usePushNotifications = () => {
  useEffect(() => {
    if (Capacitor.getPlatform() === 'web') return;

    const registerPush = async () => {
      let permStatus = await PushNotifications.checkPermissions();

      if (permStatus.receive === 'prompt') {
        permStatus = await PushNotifications.requestPermissions();
      }

      if (permStatus.receive !== 'granted') {
        console.warn('Push notification permission denied');
        return;
      }

      await PushNotifications.register();
    };

    // On success, we should be able to receive notifications
    PushNotifications.addListener('registration', (token) => {
      console.log('Push registration success, token:', token.value);

      // Send token to backend
      const memberToken = localStorage.getItem('cubag_token');
      if (memberToken) {
        fetch(`${import.meta.env.VITE_API_URL}/auth/update-fcm-token`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${memberToken}`
          },
          body: JSON.stringify({ token: token.value })
        }).catch(err => console.error('Failed to update FCM token on server', err));
      }
    });

    // Some error occurred
    PushNotifications.addListener('registrationError', (error) => {
      console.error('Error on registration:', JSON.stringify(error));
    });

    // Show us the notification payload if the app is open on our device
    PushNotifications.addListener('pushNotificationReceived', (notification) => {
      console.log('Push received:', JSON.stringify(notification));
    });

    // Method called when tapping on a notification
    PushNotifications.addListener('pushNotificationActionPerformed', (notification) => {
      console.log('Push action performed:', JSON.stringify(notification));
    });

    registerPush();

    return () => {
      PushNotifications.removeAllListeners();
    };
  }, []);
};
