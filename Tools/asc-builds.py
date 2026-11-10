#!/usr/bin/env python3
"""Print build processing state from App Store Connect.

The .p8 private key stays outside the repo, in
~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8, and the two identifiers
come from the environment so nothing account-specific is committed:

    export ASC_KEY_ID=XXXXXXXXXX
    export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    python3 Tools/asc-builds.py [--watch]

App id is Unidle's; override with ASC_APP_ID.
"""

import base64, json, os, pathlib, sys, time, urllib.request
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, utils as asym_utils

KEY_ID = os.environ.get("ASC_KEY_ID")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID")
APP_ID = os.environ.get("ASC_APP_ID", "6800692328")

if not KEY_ID or not ISSUER_ID:
    sys.exit("set ASC_KEY_ID and ASC_ISSUER_ID (see this file's docstring)")

KEY_PATH = pathlib.Path.home() / f".appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8"
if not KEY_PATH.exists():
    sys.exit(f"private key not found at {KEY_PATH}")


def token() -> str:
    """ES256 JWT. Apple wants a raw r||s signature, not the DER openssl emits."""
    key = serialization.load_pem_private_key(KEY_PATH.read_bytes(), password=None)
    b64 = lambda d: base64.urlsafe_b64encode(d).rstrip(b"=")
    now = int(time.time())
    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    payload = {"iss": ISSUER_ID, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}
    dumps = lambda o: json.dumps(o, separators=(",", ":")).encode()
    signing_input = b64(dumps(header)) + b"." + b64(dumps(payload))
    r, s = asym_utils.decode_dss_signature(key.sign(signing_input, ec.ECDSA(hashes.SHA256())))
    return (signing_input + b"." + b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))).decode()


def builds():
    request = urllib.request.Request(
        f"https://api.appstoreconnect.apple.com/v1/builds?filter[app]={APP_ID}&limit=10&sort=-version",
        headers={"Authorization": "Bearer " + token()},
    )
    return json.load(urllib.request.urlopen(request, timeout=30)).get("data", [])


def show():
    rows = builds()
    print(f"{'BUILD':8} {'STATE':22} UPLOADED")
    for b in rows:
        a = b["attributes"]
        print(f"{a.get('version',''):8} {str(a.get('processingState','')):22} {str(a.get('uploadedDate',''))[:19]}")
    return rows


if "--watch" in sys.argv:
    for _ in range(40):
        rows = show()
        if rows and rows[0]["attributes"].get("processingState") not in {"PROCESSING", None}:
            break
        print("--- waiting 30s ---")
        time.sleep(30)
else:
    show()
