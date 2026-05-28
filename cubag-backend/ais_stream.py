import json
import os
import threading
import time
import websocket
from datetime import datetime, timezone
from socket_instance import socketio

AIS_API_KEY = os.getenv('AIS_API_KEY')
GHANA_BBOX = [[[4.0, -4.0], [6.5, 2.0]]]

class AISStreamManager:
    def __init__(self):
        self.thread = None
        self.active_vessels = {}
        self.is_running = False
        self.tracked_mmsis = set()
        self.ws = None
        self.lock = threading.Lock()

    def start(self):
        if not AIS_API_KEY:
            print("[AIS] API Key missing. AIS stream will not start.")
            return

        if self.is_running:
            return

        self.is_running = True
        self.thread = threading.Thread(target=self._run_forever, daemon=True)
        self.thread.start()
        print("[AIS] Synchronous background thread started.")

    def add_track(self, mmsi):
        if not mmsi: return
        try:
            mmsi_int = int(mmsi)
            with self.lock:
                if mmsi_int in self.tracked_mmsis:
                    return
                self.tracked_mmsis.add(mmsi_int)
            print(f"[AIS] Now tracking MMSI: {mmsi_int}")
        except:
            return

        if self.ws and self.ws.sock and self.ws.sock.connected:
            self._send_subscription(self.ws)

    def _run_forever(self):
        while self.is_running:
            try:
                print("[AIS] Connecting to stream...")
                self.ws = websocket.WebSocketApp(
                    "wss://stream.aisstream.io/v0/stream",
                    on_open=self._on_open,
                    on_message=self._on_message,
                    on_error=self._on_error,
                    on_close=self._on_close
                )
                self.ws.run_forever(ping_interval=30, ping_timeout=10)
            except Exception as e:
                print(f"[AIS] Manager error: {e}")

            print("[AIS] Disconnected. Retrying in 10s...")
            time.sleep(10)

    def _on_open(self, ws):
        print("[AIS] WebSocket Connected.")
        self._send_subscription(ws)

    def _send_subscription(self, ws):
        # Always track Ghana by default
        subscribe_message = {
            "APIKey": AIS_API_KEY,
            "BoundingBoxes": GHANA_BBOX,
            "FilterMessageTypes": ["PositionReport", "ShipStaticData"]
        }

        with self.lock:
            # Send MMSIs as integers (required by protocol)
            mmsi_list = [int(m) for m in list(self.tracked_mmsis)[:50]]

        if mmsi_list:
            subscribe_message["FiltersShipMMSI"] = mmsi_list
            # Expand to worldwide for these specific vessels
            subscribe_message["BoundingBoxes"] = [[[-90, -180], [90, 180]]]

        try:
            ws.send(json.dumps(subscribe_message))
            print(f"[AIS] Subscription sent (Ghana + {len(mmsi_list)} live filters)")
        except Exception as e:
            print(f"[AIS] Failed to send subscription: {e}")

    def _on_message(self, ws, message_json):
        try:
            msg = json.loads(message_json)
            self._handle_ais_message(msg)
        except Exception as e:
            print(f"[AIS] Message parse error: {e}")

    def _on_error(self, ws, error):
        print(f"[AIS] WebSocket Error: {error}")

    def _on_close(self, ws, close_status_code, close_msg):
        print(f"[AIS] WebSocket Closed: {close_msg}")

    def _handle_ais_message(self, msg):
        msg_type = msg.get("MessageType")
        metadata = msg.get("Metadata", {})
        ship_name = metadata.get("VesselName", "Unknown").strip()
        mmsi = metadata.get("MMSI")

        if not mmsi:
            return

        now_str = datetime.now(timezone.utc).isoformat()
        vessel = self.active_vessels.get(mmsi, {
            'mmsi': mmsi,
            'name': ship_name,
            'type': 'Unknown',
            'status': 'Unknown',
            'lat': metadata.get('Latitude'),
            'lng': metadata.get('Longitude'),
            'last_update': now_str,
            'last_emit': 0,
            'imo': '—',
            'callsign': '—',
            'flag': 'Unknown',
            'length': '—',
            'width': '—',
            'speed': 0,
            'course': '—',
            'heading': '—',
            'rot': '—',
            'draught': '—',
            'destination': '—',
            'eta': '—',
            'region': metadata.get('Area', 'Global')
        })

        if msg_type == "PositionReport":
            pos = msg['Message']['PositionReport']
            vessel['lat'] = pos.get('Latitude')
            vessel['lng'] = pos.get('Longitude')
            vessel['speed'] = pos.get('Sog', 0)
            vessel['course'] = pos.get('Cog', '—')
            vessel['heading'] = pos.get('TrueHeading', '—')
            vessel['rot'] = pos.get('Rot', '—')
            vessel['status'] = self._decode_nav_status(pos.get('NavigationalStatus'))
            vessel['last_update'] = now_str

        elif msg_type == "ShipStaticData":
            static = msg['Message']['ShipStaticData']
            vessel['name'] = static.get('Name', vessel['name']).strip()
            vessel['imo'] = static.get('Imo', '—')
            vessel['callsign'] = static.get('CallSign', '—').strip()
            vessel['type'] = self._decode_ship_type(static.get('Type'))
            vessel['destination'] = static.get('Destination', '—').strip()
            vessel['eta'] = self._format_eta(static.get('Eta'))
            vessel['draught'] = static.get('Draught', '—')

            # Dimensions
            dim = static.get('Dimension', {})
            a, b, c, d = dim.get('A', 0), dim.get('B', 0), dim.get('C', 0), dim.get('D', 0)
            if a or b: vessel['length'] = a + b
            if c or d: vessel['width'] = c + d

            vessel['last_update'] = now_str

        self.active_vessels[mmsi] = vessel

        # Throttle emissions
        curr_ts = time.time()
        if curr_ts - vessel.get('last_emit', 0) > 10:
            vessel['last_emit'] = curr_ts
            socketio.emit('vessel_update', vessel)

    def _decode_ship_type(self, type_id):
        if not type_id: return "Unknown"
        if 70 <= type_id <= 79: return "Cargo Ship"
        if 80 <= type_id <= 89: return "Tanker"
        if 60 <= type_id <= 69: return "Passenger"
        if 30 <= type_id <= 30: return "Fishing"
        return f"Ship ({type_id})"

    def _decode_nav_status(self, status_id):
        statuses = {
            0: "Underway using Engine",
            1: "At Anchor",
            2: "Not Under Command",
            3: "Restricted Manoeuvrability",
            4: "Constrained by Draught",
            5: "Moored",
            6: "Aground",
            7: "Engaged in Fishing",
            8: "Underway Sailing",
            15: "Unknown"
        }
        return statuses.get(status_id, f"Other ({status_id})")

    def _format_eta(self, eta_obj):
        if not eta_obj: return "—"
        try:
            m, d, h, mn = eta_obj.get('Month', 0), eta_obj.get('Day', 0), eta_obj.get('Hour', 0), eta_obj.get('Minute', 0)
            if m == 0 or d == 0: return "—"
            return f"2026-{m:02d}-{d:02d} {h:02d}:{mn:02d} UTC"
        except:
            return "—"

ais_manager = AISStreamManager()
