#!/usr/bin/env python3
"""Submit a Sunny-Side version for App Store review through the App Store Connect API.

  scripts/submit.py                      # version 2.0.0, newest processed build, submit
  scripts/submit.py --dry-run            # do everything except the final submit
  scripts/submit.py --version 2.0.1 --build 202611011200

Auth: ASC_KEY_ID + ASC_ISSUER_ID in ~/.config/sunnyside/asc.env, key file ~/.private_keys/AuthKey_<KEY_ID>.p8.
Release notes come from docs/release-notes/<version>.md.
"""
import argparse, base64, json, os, subprocess, sys, time, urllib.error, urllib.parse, urllib.request
from pathlib import Path

APP_ID = "6749254551"   # Sunny-Side
API = "https://api.appstoreconnect.apple.com/v1"
ROOT = Path(__file__).resolve().parent.parent

# ---------- auth ----------
def load_env():
    p = Path.home() / ".config/sunnyside/asc.env"
    if p.exists():
        for line in p.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1); os.environ.setdefault(k.strip(), v.strip())

def b64url(b): return base64.urlsafe_b64encode(b).rstrip(b"=").decode()

def der_to_raw(der):
    assert der[0] == 0x30; i, out = 2, b""
    for _ in range(2):
        n = der[i + 1]; out += der[i + 2:i + 2 + n].lstrip(b"\x00").rjust(32, b"\x00"); i += 2 + n
    return out

_token = None
def token():
    global _token
    if _token and _token[1] > time.time() + 60: return _token[0]
    key_id, issuer = os.environ.get("ASC_KEY_ID"), os.environ.get("ASC_ISSUER_ID")
    if not key_id or not issuer: sys.exit("Set ASC_KEY_ID and ASC_ISSUER_ID in ~/.config/sunnyside/asc.env")
    key = Path(os.environ.get("ASC_KEY_PATH", Path.home() / f".private_keys/AuthKey_{key_id}.p8"))
    if not key.exists(): sys.exit(f"Key file not found: {key}")
    now = int(time.time()); exp = now + 900
    h = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    p = b64url(json.dumps({"iss": issuer, "iat": now, "exp": exp, "aud": "appstoreconnect-v1"}).encode())
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", str(key)], input=f"{h}.{p}".encode(), capture_output=True, check=True).stdout
    _token = (f"{h}.{p}.{b64url(der_to_raw(der))}", exp)
    return _token[0]

def call(method, path, body=None, params=None):
    url = path if path.startswith("http") else API + path
    if params: url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        sys.exit(f"{method} {path} → HTTP {e.code}\n{detail[:1500]}")

# ---------- steps ----------
def find_build(version, build_number):
    params = {"filter[app]": APP_ID, "filter[preReleaseVersion.version]": version, "sort": "-uploadedDate", "limit": 10,
              "fields[builds]": "version,processingState,uploadedDate,usesNonExemptEncryption,expired"}
    if build_number: params["filter[version]"] = build_number
    # A freshly uploaded build can take a few minutes to show up in the API.
    for attempt in range(20):
        builds = [b for b in call("GET", "/builds", params=params)["data"] if not b["attributes"]["expired"]]
        if builds: return builds[0]
        print(f"  build not visible yet; waiting… ({attempt + 1}/20)"); time.sleep(60)
    sys.exit(f"No build found for version {version}" + (f" build {build_number}" if build_number else ""))

def wait_until_processed(build, minutes=40):
    deadline = time.time() + minutes * 60
    while build["attributes"]["processingState"] != "VALID":
        state = build["attributes"]["processingState"]
        if state in ("FAILED", "INVALID"): sys.exit(f"Build {build['attributes']['version']} is {state}; check the account holder's email for the ITMS reason.")
        if time.time() > deadline: sys.exit("Timed out waiting for Apple to process the build.")
        print(f"  build {build['attributes']['version']} is {state}; waiting…"); time.sleep(60)
        build = call("GET", f"/builds/{build['id']}", params={"fields[builds]": "version,processingState,usesNonExemptEncryption,expired"})["data"]
    return build

def ensure_version(version_string):
    existing = call("GET", f"/apps/{APP_ID}/appStoreVersions", params={"filter[platform]": "IOS", "filter[versionString]": version_string, "fields[appStoreVersions]": "versionString,appStoreState,appVersionState"})["data"]
    if existing:
        v = existing[0]; print(f"  version {version_string} exists ({v['attributes'].get('appVersionState') or v['attributes'].get('appStoreState')})"); return v
    body = {"data": {"type": "appStoreVersions", "attributes": {"platform": "IOS", "versionString": version_string, "releaseType": "AFTER_APPROVAL"},
                     "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}}
    v = call("POST", "/appStoreVersions", body)["data"]; print(f"  created version {version_string}"); return v

def attach_build(version_id, build_id):
    call("PATCH", f"/appStoreVersions/{version_id}/relationships/build", {"data": {"type": "builds", "id": build_id}})
    print("  build attached")

def set_release_notes(version_id, notes):
    locs = call("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations", params={"fields[appStoreVersionLocalizations]": "locale,whatsNew"})["data"]
    if not locs: sys.exit("The version has no localizations; open it once in App Store Connect.")
    for loc in locs:
        call("PATCH", f"/appStoreVersionLocalizations/{loc['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": {"whatsNew": notes}}})
        print(f"  release notes set for {loc['attributes']['locale']}")

def ensure_encryption_declared(build):
    if build["attributes"].get("usesNonExemptEncryption") is None:
        call("PATCH", f"/builds/{build['id']}", {"data": {"type": "builds", "id": build["id"], "attributes": {"usesNonExemptEncryption": False}}})
        print("  export compliance: declared no non-exempt encryption")

def submit(version_id):
    sub = call("POST", "/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
                                                        "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})["data"]
    call("POST", "/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems",
         "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
                           "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}})
    call("PATCH", f"/reviewSubmissions/{sub['id']}", {"data": {"type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}})
    print("  submitted for review")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", default="2.0.0")
    ap.add_argument("--build", default=None, help="build number; default newest for the version")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-wait", action="store_true")
    a = ap.parse_args()
    load_env()

    notes_path = ROOT / "docs/release-notes" / f"{a.version}.md"
    if not notes_path.exists(): sys.exit(f"Write the release notes first: {notes_path}")
    notes = notes_path.read_text().strip()

    print(f"▶ Finding build for {a.version}")
    build = find_build(a.version, a.build)
    print(f"  build {build['attributes']['version']} uploaded {build['attributes']['uploadedDate'][:16]}, {build['attributes']['processingState']}")
    if not a.no_wait: build = wait_until_processed(build)
    ensure_encryption_declared(build)

    print(f"▶ App Store version {a.version}")
    version = ensure_version(a.version)
    attach_build(version["id"], build["id"])
    set_release_notes(version["id"], notes)

    if a.dry_run:
        print("Dry run: not submitting. Review it at https://appstoreconnect.apple.com/apps/%s/distribution" % APP_ID); return
    print("▶ Submitting for review")
    submit(version["id"])
    print("Done. Apple usually reviews within 24–48 hours; the version goes live automatically after approval.")

if __name__ == "__main__":
    main()
