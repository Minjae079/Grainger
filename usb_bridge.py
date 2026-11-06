
import argparse
import json
import threading
import time

from http.server import (
    BaseHTTPRequestHandler,
    ThreadingHTTPServer,
)

# =====================================
# Server settings
# =====================================

HOST = "127.0.0.1"
HTTP_PORT = 8765
DATA_MAX_AGE_SECONDS = 8.0

latest = None
last_received = 0.0
sequence = 0

lock = threading.Lock()


# =====================================
# Save latest Arduino data
# =====================================

def update_latest(data):
    global latest, last_received, sequence

    if not isinstance(data, dict):
        return

    # Required Arduino JSON fields
    if "sensorOk" not in data:
        return

    if "sensor2Ok" not in data:
        return

    with lock:
        latest = data
        last_received = time.monotonic()
        sequence += 1

        current_sequence = sequence

    t1 = data.get("temperature")
    t2 = data.get("temperature2")

    print(
        f"[Data #{current_sequence}] "
        f"Sensor 1: {t1} C | "
        f"Sensor 2: {t2} C",
        flush=True,
    )


# =====================================
# Read Arduino USB Serial
# =====================================

def read_usb(port, baud):
    try:
        import serial
    except ImportError:
        print(
            "Please install pyserial first.",
            flush=True,
        )
        return

    while True:
        try:
            print(
                f"Connecting to {port} "
                f"at {baud} baud...",
                flush=True,
            )

            with serial.Serial(
                port=port,
                baudrate=baud,
                timeout=1,
            ) as ser:

                print(
                    "Arduino USB connected!",
                    flush=True,
                )

                while True:
                    raw = ser.readline()

                    if not raw:
                        continue

                    line = raw.decode(
                        "utf-8",
                        errors="replace",
                    ).strip()

                    # Only process JSON lines
                    if not line.startswith("{"):
                        continue

                    try:
                        data = json.loads(line)
                    except json.JSONDecodeError:
                        continue

                    update_latest(data)

        except Exception as e:
            print(
                f"Serial error: {e}",
                flush=True,
            )

            print(
                "Retrying in 3 seconds...",
                flush=True,
            )

            time.sleep(3)


# =====================================
# Generate demo sensor data
# =====================================

def demo_worker(sensor2_error):
    index = 0

    while True:
        t1 = max(
            -5.0,
            13.0 - 0.035 * index,
        )

        t2 = max(
            -5.0,
            14.0 - 0.045 * index,
        )

        slope1 = (
            -1.05
            if index >= 5 and t1 > -5
            else None
        )

        slope2 = (
            -1.35
            if index >= 5 and t2 > -5
            else None
        )

        eta1 = (
            (t1 - 2) / (-slope1)
            if slope1 is not None and t1 > 2
            else None
        )

        eta2 = (
            (t2 - 2) / (-slope2)
            if slope2 is not None and t2 > 2
            else None
        )

        danger1 = (
            t1 <= 2
            or (
                t1 <= 12
                and eta1 is not None
                and eta1 <= 15
            )
        )

        danger2 = (
            not sensor2_error
            and (
                t2 <= 2
                or (
                    t2 <= 12
                    and eta2 is not None
                    and eta2 <= 15
                )
            )
        )

        data = {
            "sensorOk": True,
            "temperature": round(t1, 2),
            "slope": slope1,
            "etaMinutes": (
                round(eta1, 2)
                if eta1 is not None
                else None
            ),
            "danger": danger1,

            "sensor2Ok": not sensor2_error,
            "temperature2": (
                None
                if sensor2_error
                else round(t2, 2)
            ),
            "slope2": (
                None
                if sensor2_error
                else slope2
            ),
            "etaMinutes2": (
                None
                if sensor2_error or eta2 is None
                else round(eta2, 2)
            ),
            "danger2": danger2,

            "anyDanger": danger1 or danger2,
            "anySensorError": sensor2_error,
            "uptimeSeconds": 2 * index,
        }

        update_latest(data)

        index += 1
        time.sleep(2)


# =====================================
# HTTP server for Flutter
# =====================================

class Handler(BaseHTTPRequestHandler):

    def do_GET(self):

        if self.path != "/temperature":
            self.send_json(
                404,
                {"error": "Not found"},
            )
            return

        with lock:
            data = (
                dict(latest)
                if latest is not None
                else None
            )

            age = (
                time.monotonic()
                - last_received
            )

            seq = sequence

        if (
            data is None
            or age > DATA_MAX_AGE_SECONDS
        ):
            self.send_json(
                503,
                {
                    "error":
                    "No recent Arduino data"
                },
            )
            return

        # Used by Flutter to prevent
        # duplicate graph points
        data["sequence"] = seq

        data["receivedAgeSeconds"] = round(
            age,
            1,
        )

        self.send_json(200, data)

    def send_json(self, status, obj):

        payload = json.dumps(
            obj,
            ensure_ascii=False,
            allow_nan=False,
        ).encode("utf-8")

        self.send_response(status)

        self.send_header(
            "Content-Type",
            "application/json; charset=utf-8",
        )

        self.send_header(
            "Content-Length",
            str(len(payload)),
        )

        self.send_header(
            "Cache-Control",
            "no-store",
        )

        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format_string, *args):
        pass


# =====================================
# Main
# =====================================

def main():

    parser = argparse.ArgumentParser(
        description="Arduino USB to Flutter"
    )

    parser.add_argument(
        "--port",
        help="Arduino COM port, e.g. COM5",
    )

    parser.add_argument(
        "--baud",
        type=int,
        default=9600,
    )

    parser.add_argument(
        "--demo",
        action="store_true",
    )

    parser.add_argument(
        "--sensor2-error",
        action="store_true",
    )

    parser.add_argument(
        "--list-ports",
        action="store_true",
    )

    args = parser.parse_args()

    # List connected serial ports
    if args.list_ports:
        try:
            from serial.tools import list_ports
        except ImportError:
            parser.error(
                "Install pyserial first"
            )

        for port in list_ports.comports():
            print(
                f"{port.device}: "
                f"{port.description}"
            )

        return

    if not args.demo and not args.port:
        parser.error(
            "Specify --demo or --port COM5"
        )

    # Start background data reader
    if args.demo:
        worker = threading.Thread(
            target=demo_worker,
            args=(args.sensor2_error,),
            daemon=True,
        )
    else:
        worker = threading.Thread(
            target=read_usb,
            args=(args.port, args.baud),
            daemon=True,
        )

    worker.start()

    server = ThreadingHTTPServer(
        (HOST, HTTP_PORT),
        Handler,
    )

    print(
        "Python HTTP server started!",
        flush=True,
    )

    print(
        f"Windows: "
        f"http://127.0.0.1:{HTTP_PORT}/temperature",
        flush=True,
    )

    print(
        f"Android Emulator: "
        f"http://10.0.2.2:{HTTP_PORT}/temperature",
        flush=True,
    )

    try:
        server.serve_forever()

    except KeyboardInterrupt:
        print("Server stopped")

    finally:
        server.server_close()


if __name__ == "__main__":
    main()
