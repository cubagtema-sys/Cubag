import asyncio
import json
import os
import threading
import websockets
from datetime import datetime, timezone
from socket_instance import socketio

AIS_API_KEY = os.getenv('AIS_API_KEY')
# Bounding box for Ghana region (approx)
GHANA_BBOX = [[[4.0, -4.0], [6.5, 2.0]]]

class AISStreamManager:
    def __init__(self):
        self.loop = None
        self.thread = None
        self.active_vessels = {}
        self.is_running = False
        self.tracked_mmsis = set()
        self.websocket = None
        self.lock = threading.Lock()

    def start(self):
        if not AIS_API_KEY:
            print("[AIS] API Key missing. AIS stream will not start.")
            return

        if self.is_running:
            return

        self.is_running = True
        self.thread = threading.Thread(target=self._run_loop, daemon=True)
        self.thread.start()
        print("[AIS] Background thread started.")

    def add_track(self, mmsi):
        if not mmsi: return
        with self.lock:
            self.tracked_mmsis.add(str(mmsi))
        if self.loop and self.websocket:
            print(f"[AIS] Manually tracking MMSI: {mmsi}")
            asyncio.run_coroutine_threadsafe(self._update_subscription(), self.loop)

    def _run_loop(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        self.loop.run_until_complete(self._connect_ais_stream())

    async def _update_subscription(self):
        if not self.websocket: return
        with self.lock:
            mmsi_list = list(self.tracked_mmsis)[:50] # API limit 50

        subscribe_message = {
            "APIKey": AIS_API_KEY,
            "BoundingBoxes": GHANA_BBOX,
            "FilterMessageTypes": ["PositionReport", "ShipStaticData"]
        }
        if mmsi_list:
            subscribe_message["FiltersShipMMSI"] = mmsi_list
            # Expand to worldwide if tracking specific ships outside Ghana
            subscribe_message["BoundingBoxes"] = [[[-90, -180], [90, 180]]]

        await self.websocket.send(json.dumps(subscribe_message))
        print(f"[AIS] Subscription updated. Total tracked: {len(mmsi_list)}")

    async def _connect_ais_stream(self):
        retry_delay = 5
        while self.is_running:
            try:
                print(f"[AIS] Connecting to AIS Stream...")
                async with websockets.connect("wss://stream.aisstream.io/v0/stream") as websocket:
                    self.websocket = websocket
                    await self._update_subscription()

                    async for message_json in websocket:
                        message = json.loads(message_json)
                        self._handle_ais_message(message)

                    self.websocket = None

            except Exception as e:
                self.websocket = None
                print(f"[AIS] Connection error: {e}. Retrying in {retry_delay}s...")
                await asyncio.sleep(retry_delay)
                retry_delay = min(retry_delay * 2, 60)

    def _handle_ais_message(self, msg):
        msg_type = msg.get("MessageType")
        metadata = msg.get("Metadata", {})
        ship_name = metadata.get("VesselName", "Unknown").strip()
        mmsi = metadata.get("MMSI")

        if not mmsi:
            return

        # Prepare a unified vessel object
        vessel = self.active_vessels.get(mmsi, {
            'mmsi': mmsi,
            'name': ship_name,
            'type': 'Unknown',
            'status': 'Underway',
            'lat': metadata.get('Latitude'),
            'lng': metadata.get('Longitude'),
            'last_update': datetime.now(timezone.utc).isoformat()
        })

        if msg_type == "PositionReport":
            pos = msg['Message']['PositionReport']
            vessel['lat'] = pos.get('Latitude')
            vessel['lng'] = pos.get('Longitude')
            vessel['speed'] = pos.get('Sog')
            vessel['course'] = pos.get('Cog')
            vessel['last_update'] = datetime.now(timezone.utc).isoformat()

        elif msg_type == "ShipStaticData":
            static = msg['Message']['ShipStaticData']
            vessel['name'] = static.get('Name', vessel['name']).strip()
            vessel['type'] = self._decode_ship_type(static.get('Type'))
            vessel['destination'] = static.get('Destination', 'Unknown').strip()
            vessel['eta'] = self._format_eta(static.get('Eta'))
            vessel['last_update'] = datetime.now(timezone.utc).isoformat()

        # Update cache
        self.active_vessels[mmsi] = vessel

        # Broadcast to all connected socket.io clients
        socketio.emit('vessel_update', vessel)

    def _decode_ship_type(self, type_id):
        if not type_id: return "Unknown"
        if 70 <= type_id <= 79: return "Cargo Ship"
        if 80 <= type_id <= 89: return "Tanker"
        if 60 <= type_id <= 69: return "Passenger"
        if 30 <= type_id <= 30: return "Fishing"
        return f"Ship ({type_id})"

    def _format_eta(self, eta_obj):
        if not eta_obj: return "Unknown"
        try:
            m = eta_obj.get('Month', 0)
            d = eta_obj.get('Day', 0)
            h = eta_obj.get('Hour', 0)
            min = eta_obj.get('Minute', 0)
            if m == 0 or d == 0: return "Unknown"
            return f"{d}/{m} {h:02d}:{min:02d} UTC"
        except:
            return "Unknown"

# Global instance
ais_manager = AISStreamManager()
