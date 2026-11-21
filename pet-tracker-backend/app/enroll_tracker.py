"""Operator-only enrollment for Wi-Fi trackers with preassigned IDs."""

import argparse
import re

from pydantic import ValidationError

from app.schemas.devices import PT_DEVICE_ID_PATTERN, DeviceRegisterRequest
from app.services.device_service import DeviceConflictError, DeviceService, UNCLAIMED_TRACKER_OWNER


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("device_id", help="The PT- ID embedded in the device")
    parser.add_argument("--name", help="Optional display name")
    args = parser.parse_args()
    tracker_id = args.device_id.strip().upper()
    if not re.fullmatch(PT_DEVICE_ID_PATTERN, tracker_id):
        parser.error("Use PT- followed by 12 hexadecimal characters.")
    try:
        request = DeviceRegisterRequest(device_id=tracker_id, name=args.name)
    except ValidationError:
        parser.error("If provided, the name must be 1–40 characters.")
    try:
        result = DeviceService().register_device(UNCLAIMED_TRACKER_OWNER, request)
    except DeviceConflictError:
        parser.error("That tracker ID already exists; no credentials were changed.")
    print(f"Device ID: {result.device.device_id}")
    print(f"Device secret (store privately on the tracker): {result.device_secret}")


if __name__ == "__main__":
    main()
