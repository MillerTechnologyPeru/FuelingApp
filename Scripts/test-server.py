#!/usr/bin/env python3
"""
Local test server for the Fueling app.

Serves GET /v1/locations and GET /v1/fuelprice from a JSON file acting as a
tiny flat-file "database" (see test-data.json alongside this script), in the
same wire format FuelingAPI's GetLocation/FuelPrice DTOs expect. Point the
app at it with:

    FUELING_SERVER_URL=http://localhost:8080 swift run          # Fueling.swiftpm
    ./gradlew :app:assembleDebug -PfuelingServerUrl=http://10.0.2.2:8080  # Android emulator

The data file is reloaded from disk on every request, so you can edit
test-data.json while the server is running and see the changes immediately
without a restart.

Usage:
    python3 test-server.py [--port 8080] [--data test-data.json]
"""

import argparse
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs

DEFAULT_PORT = 8080
DEFAULT_DATA_PATH = Path(__file__).resolve().parent / "test-data.json"


def load_database(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def filter_by_site_ids(records: list, site_ids: list, id_key: str) -> list:
    if not site_ids:
        return records
    wanted = set(site_ids)
    return [record for record in records if record.get(id_key) in wanted]


class Handler(BaseHTTPRequestHandler):
    data_path: Path = DEFAULT_DATA_PATH

    def _send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _error_envelope(self, message: str) -> dict:
        return {"status": "Error", "message": message, "data": None}

    def do_GET(self):  # noqa: N802 (BaseHTTPRequestHandler API)
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        site_ids = query.get("siteIds", [])

        try:
            db = load_database(self.data_path)
        except FileNotFoundError:
            self._send_json(500, self._error_envelope(f"Data file not found: {self.data_path}"))
            return
        except json.JSONDecodeError as error:
            self._send_json(500, self._error_envelope(f"Invalid JSON in data file: {error}"))
            return

        if parsed.path == "/v1/locations":
            locations = filter_by_site_ids(db.get("locations", []), site_ids, "site_id")
            self._send_json(200, {"status": "Success", "message": None, "data": locations})
        elif parsed.path == "/v1/fuelprice":
            prices = filter_by_site_ids(db.get("fuel_prices", []), site_ids, "siteID")
            self._send_json(200, {"status": "Success", "message": None, "data": prices})
        else:
            self._send_json(404, self._error_envelope(f"No such endpoint: {parsed.path}"))

    def log_message(self, format: str, *args) -> None:  # noqa: A002 (matches base signature)
        sys.stderr.write("[test-server] " + (format % args) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help=f"port to listen on (default: {DEFAULT_PORT})")
    parser.add_argument(
        "--data",
        type=Path,
        default=DEFAULT_DATA_PATH,
        help=f"path to the JSON data file (default: {DEFAULT_DATA_PATH})",
    )
    args = parser.parse_args()

    if not args.data.is_file():
        print(f"error: data file not found: {args.data}", file=sys.stderr)
        raise SystemExit(1)

    Handler.data_path = args.data
    server = HTTPServer(("127.0.0.1", args.port), Handler)
    print(f"Fueling test server serving fake data from {args.data}")
    print(f"Listening on http://127.0.0.1:{args.port}  (GET /v1/locations, GET /v1/fuelprice)")
    print("Press Ctrl-C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping.")
        server.server_close()


if __name__ == "__main__":
    main()
