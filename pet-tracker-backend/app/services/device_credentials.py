import base64
import hashlib
import hmac
import secrets


PBKDF2_ALGORITHM = "pbkdf2_sha256"
PBKDF2_ITERATIONS = 210_000
SECRET_BYTES = 32
SALT_BYTES = 16


def generate_device_secret() -> str:
    return secrets.token_urlsafe(SECRET_BYTES)


def hash_device_secret(secret: str) -> str:
    salt = secrets.token_bytes(SALT_BYTES)
    digest = hashlib.pbkdf2_hmac("sha256", secret.encode("utf-8"), salt, PBKDF2_ITERATIONS)
    return "$".join(
        [
            PBKDF2_ALGORITHM,
            str(PBKDF2_ITERATIONS),
            base64.urlsafe_b64encode(salt).decode("ascii"),
            base64.urlsafe_b64encode(digest).decode("ascii"),
        ]
    )


def verify_device_secret(secret: str, stored_hash: str | None) -> bool:
    if not secret or not stored_hash:
        return False

    try:
        algorithm, iterations_value, salt_value, digest_value = stored_hash.split("$", maxsplit=3)
        if algorithm != PBKDF2_ALGORITHM:
            return False

        iterations = int(iterations_value)
        salt = base64.urlsafe_b64decode(salt_value.encode("ascii"))
        expected_digest = base64.urlsafe_b64decode(digest_value.encode("ascii"))
    except (ValueError, TypeError):
        return False

    supplied_digest = hashlib.pbkdf2_hmac("sha256", secret.encode("utf-8"), salt, iterations)
    return hmac.compare_digest(supplied_digest, expected_digest)
