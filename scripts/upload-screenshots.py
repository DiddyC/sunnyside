#!/usr/bin/env python3
"""Replace the App Store screenshots of a version with the PNGs in a folder.

  scripts/upload-screenshots.py --version 2.0.0 --iphone dir/iphone --ipad dir/ipad

Files are uploaded in alphabetical order. Display slots: iPhone 6.7" (APP_IPHONE_67,
1290x2796) and iPad Pro 12.9"/13" (APP_IPAD_PRO_3GEN_129, 2064x2752 or 2048x2732).
If the version is waiting for review, pass --resubmit to cancel the submission,
replace the screenshots and submit again.
"""
import argparse, hashlib, importlib.util, json, sys, time, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("submit", ROOT / "submit.py"); asc = importlib.util.module_from_spec(spec); spec.loader.exec_module(asc)
call, APP_ID = asc.call, asc.APP_ID

def version_id(version):
    vs = call("GET", f"/apps/{APP_ID}/appStoreVersions", params={"filter[platform]": "IOS", "filter[versionString]": version, "fields[appStoreVersions]": "versionString,appVersionState"})["data"]
    if not vs: sys.exit(f"No App Store version {version}")
    return vs[0]["id"], vs[0]["attributes"]["appVersionState"]

def localization_id(vid, locale="en-US"):
    locs = call("GET", f"/appStoreVersions/{vid}/appStoreVersionLocalizations", params={"fields[appStoreVersionLocalizations]": "locale"})["data"]
    for l in locs:
        if l["attributes"]["locale"] == locale: return l["id"]
    sys.exit(f"No {locale} localization")

def screenshot_set(loc_id, display_type):
    sets = call("GET", f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets", params={"fields[appScreenshotSets]": "screenshotDisplayType"})["data"]
    for s in sets:
        if s["attributes"]["screenshotDisplayType"] == display_type: return s["id"]
    body = {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display_type},
                     "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}}}
    return call("POST", "/appScreenshotSets", body)["data"]["id"]

def clear_set(set_id):
    shots = call("GET", f"/appScreenshotSets/{set_id}/appScreenshots", params={"fields[appScreenshots]": "fileName"})["data"]
    for s in shots:
        call("DELETE", f"/appScreenshots/{s['id']}")
    if shots: print(f"  removed {len(shots)} old screenshot(s)")

def upload(set_id, path):
    data = path.read_bytes()
    shot = call("POST", "/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": path.name, "fileSize": len(data)},
                                                       "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})["data"]
    for op in shot["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]: op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"], headers={h["name"]: h["value"] for h in op["requestHeaders"]})
        with urllib.request.urlopen(req, timeout=120) as r: r.read()
    call("PATCH", f"/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
         "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print(f"  uploaded {path.name} ({len(data)//1024} KB)")
    return shot["id"]

def wait_processed(shot_ids):
    """Returns the ids that Apple failed to process (ASSET_FAILED is usually transient)."""
    failed = []
    for sid in shot_ids:
        for _ in range(40):
            st = call("GET", f"/appScreenshots/{sid}", params={"fields[appScreenshots]": "assetDeliveryState"})["data"]["attributes"]["assetDeliveryState"]["state"]
            if st == "COMPLETE": break
            if st == "FAILED":
                print(f"  Apple failed to process screenshot {sid}; will retry"); failed.append(sid); break
            time.sleep(3)
    return failed

def cancel_review(version):
    subs = call("GET", "/reviewSubmissions", params={"filter[app]": APP_ID, "filter[state]": "WAITING_FOR_REVIEW,READY_FOR_REVIEW,UNRESOLVED_ISSUES", "fields[reviewSubmissions]": "state"})["data"]
    for s in subs:
        call("PATCH", f"/reviewSubmissions/{s['id']}", {"data": {"type": "reviewSubmissions", "id": s["id"], "attributes": {"canceled": True}}})
        print(f"  cancelled review submission ({s['attributes']['state']})")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", default="2.0.0")
    ap.add_argument("--iphone", help="folder of 1290x2796 PNGs")
    ap.add_argument("--ipad", help="folder of 2064x2752 PNGs")
    ap.add_argument("--resubmit", action="store_true")
    a = ap.parse_args()
    asc.load_env()
    vid, state = version_id(a.version)
    print(f"▶ Version {a.version} is {state}")
    if state == "WAITING_FOR_REVIEW" and a.resubmit:
        cancel_review(a.version)
        for _ in range(20):
            time.sleep(3); _, state = version_id(a.version)
            if state != "WAITING_FOR_REVIEW": break
        print(f"  version now {state}")
    loc = localization_id(vid)
    for folder, display in [(a.iphone, "APP_IPHONE_67"), (a.ipad, "APP_IPAD_PRO_3GEN_129")]:
        if not folder: continue
        files = sorted(Path(folder).glob("*.png"))
        if not files: print(f"  no PNGs in {folder}"); continue
        print(f"▶ {display}: {len(files)} file(s)")
        sid = screenshot_set(loc, display)
        clear_set(sid)
        pending = {upload(sid, f): f for f in files}
        for attempt in range(3):
            failed = wait_processed(list(pending))
            if not failed: break
            retry = {}
            for fid in failed:
                f = pending.pop(fid); call("DELETE", f"/appScreenshots/{fid}")
                retry[upload(sid, f)] = f
            pending = retry
        else:
            sys.exit("Apple kept failing to process some screenshots; try again later.")
        # keep store order = file order
        order = [i for i, _ in sorted(((i, f) for i, f in {**pending}.items()), key=lambda x: x[1].name)]
        all_ids = [i for i in call("GET", f"/appScreenshotSets/{sid}/appScreenshots", params={"fields[appScreenshots]": "fileName"})["data"]]
        by_name = sorted(all_ids, key=lambda x: x["attributes"]["fileName"])
        call("PATCH", f"/appScreenshotSets/{sid}/relationships/appScreenshots", {"data": [{"type": "appScreenshots", "id": x["id"]} for x in by_name]})
        print(f"  {len(by_name)} screenshot(s) processed and ordered")
    if a.resubmit:
        print("▶ Submitting for review again"); asc.submit(vid)

if __name__ == "__main__":
    main()
