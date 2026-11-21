"""Generate a package ID and private hardware reporting credential offline."""

import argparse
import re
import secrets

from app.core.config import settings
from app.schemas.devices import PT_DEVICE_ID_PATTERN
from app.services.device_credentials import derive_factory_device_secret


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("device_id", nargs="?", help="Existing PT- ID (omit to generate a new ID)")
    args = parser.parse_args()
    device_id = args.device_id.strip().upper() if args.device_id else f"PT-{secrets.token_hex(16).upper()}"
    if not re.fullmatch(PT_DEVICE_ID_PATTERN, device_id):
        parser.error("Use PT- followed by 12 or 32 hexadecimal characters.")
    if settings.tracker_factory_key is None:
        parser.error("Set TRACKER_FACTORY_KEY to the same private key as the backend deployment.")
    secret = derive_factory_device_secret(device_id, settings.tracker_factory_key.get_secret_value())
    print(f"Package ID: {device_id}")
    print(f"Device secret (store privately on the tracker): {secret}")


if __name__ == "__main__":
    main()
