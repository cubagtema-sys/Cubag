import { useEffect, useState } from 'react';
import { io } from 'socket.io-client';

const baseUrl = import.meta.env.VITE_API_URL.replace('/api', '');

export const useSocket = () => {
  const [socket, setSocket] = useState(null);

  useEffect(() => {
    const newSocket = io(baseUrl, {
      transports: ['websocket', 'polling'],
    });

    setSocket(newSocket);

    return () => newSocket.close();
  }, []);

  return socket;
};
