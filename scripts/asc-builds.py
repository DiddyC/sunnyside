#!/usr/bin/env python3
"""List the latest builds of Sunny-Side in App Store Connect with their processing state.

Auth: ASC_KEY_ID + ASC_ISSUER_ID in ~/.config/sunnyside/asc.env (or the environment),
key file ~/.private_keys/AuthKey_<KEY_ID>.p8. Uses only the standard library plus openssl.
"""
import base64, json, os, subprocess, sys, time, urllib.request, urllib.parse
from pathlib import Path

APP_ID = "6749254551"   # Sunny-Side

def load_env():
    p = Path.home() / ".config/sunnyside/asc.env"
    if p.exists():
        for line in p.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())

def b64url(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()

def der_to_raw(der: bytes) -> bytes:
    # ECDSA DER SEQUENCE { INTEGER r, INTEGER s } → r||s (32 bytes each)
    assert der[0] == 0x30
    i = 2
    out = b""
    for _ in range(2):
        assert der[i] == 0x02
        n = der[i + 1]
        v = der[i + 2:i + 2 + n].lstrip(b"\x00")
        out += v.rjust(32, b"\x00")
        i += 2 + n
    return out

def token(key_id: str, issuer: str, key_path: Path) -> str:
    now = int(time.time())
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    payload = b64url(json.dumps({"iss": issuer, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}).encode())
    signing_input = f"{header}.{payload}".encode()
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", str(key_path)], input=signing_input,
                         capture_output=True, check=True).stdout
    return f"{header}.{payload}.{b64url(der_to_raw(der))}"

def main():
    load_env()
    key_id, issuer = os.environ.get("ASC_KEY_ID"), os.environ.get("ASC_ISSUER_ID")
    if not key_id or not issuer:
        sys.exit("Set ASC_KEY_ID and ASC_ISSUER_ID (see ~/.config/sunnyside/asc.env.example)")
    key_path = Path(os.environ.get("ASC_KEY_PATH", Path.home() / f".private_keys/AuthKey_{key_id}.p8"))
    if not key_path.exists():
        sys.exit(f"Key file not found: {key_path}")
    q = urllib.parse.urlencode({
        "filter[app]": APP_ID, "sort": "-uploadedDate", "limit": "8",
        "fields[builds]": "version,processingState,uploadedDate,expired,usesNonExemptEncryption,preReleaseVersion",
        "include": "preReleaseVersion", "fields[preReleaseVersions]": "version",
    })
    req = urllib.request.Request(f"https://api.appstoreconnect.apple.com/v1/builds?{q}",
                                 headers={"Authorization": f"Bearer {token(key_id, issuer, key_path)}"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
    versions = {i["id"]: i["attributes"]["version"] for i in data.get("included", []) if i["type"] == "preReleaseVersions"}
    if not data.get("data"):
        print("No builds found for the app."); return
    print(f"{'version':<9} {'build':<16} {'state':<12} uploaded")
    for b in data["data"]:
        a = b["attributes"]
        pv = b.get("relationships", {}).get("preReleaseVersion", {}).get("data") or {}
        print(f"{versions.get(pv.get('id'), '?'):<9} {a['version']:<16} {a['processingState']:<12} {a['uploadedDate'][:16].replace('T', ' ')}"
              + ("  (expired)" if a.get("expired") else ""))

if __name__ == "__main__":
    main()
