#!/usr/bin/env python3
"""Set the App Store listing text for Shady Seat: app name + subtitle (app info) and
keywords / description / promotional text for a version.

  scripts/store-metadata.py --version 2.0.0 [--dry-run]
"""
import argparse, importlib.util, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("submit", ROOT / "submit.py"); asc = importlib.util.module_from_spec(spec); spec.loader.exec_module(asc)
call, APP_ID = asc.call, asc.APP_ID

NAME = "Shady Seat"
SUBTITLE = "Sit on the shady side"                       # ≤ 30 chars
KEYWORDS = "shade,seat,sun,train,bus,plane,flight,window,glare,sunny side,sunnyside,commute,travel"  # ≤ 100 chars
PROMO = "Which side of the train, bus or plane will be in the shade? One word: LEFT or RIGHT."        # ≤ 170 chars
DESCRIPTION = """Which side of the train, bus, plane, car or ferry will be in the shade? Shady Seat tells you in one word.

Enter where you're going and when you leave. Shady Seat follows your route minute by minute, works out where the sun will be in the sky, and scores how hard it would shine through each side window. Then it says LEFT or RIGHT.

• Works for trains, buses, cars, planes and ferries
• Pick a departure time, or enter the trip length from your ticket
• A seat map of your vehicle inside a sun compass: drag the slider to see where the sun will be at any point of the trip
• Tells you when the sun switches sides, and can remind you five minutes before
• Nearest stations and airports one tap away; place search runs on Apple Maps
• Light and dark looks
• No account, no tracking. Only the place you search for leaves your phone

Formerly Sunny-Side."""

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--version", default="2.0.0"); ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args(); asc.load_env()
    assert len(SUBTITLE) <= 30 and len(KEYWORDS) <= 100 and len(PROMO) <= 170 and len(DESCRIPTION) <= 4000

    # App info (name/subtitle): edit the app info that is not yet live.
    infos = call("GET", f"/apps/{APP_ID}/appInfos", params={"fields[appInfos]": "appStoreState,state"})["data"]
    editable = [i for i in infos if (i["attributes"].get("state") or i["attributes"].get("appStoreState")) not in ("READY_FOR_DISTRIBUTION", "READY_FOR_SALE")] or infos
    info = editable[0]
    locs = call("GET", f"/appInfos/{info['id']}/appInfoLocalizations", params={"fields[appInfoLocalizations]": "locale,name,subtitle"})["data"]
    for loc in locs:
        cur = loc["attributes"]
        print(f"app info {cur['locale']}: name {cur.get('name')!r} → {NAME!r}, subtitle {cur.get('subtitle')!r} → {SUBTITLE!r}")
        if not a.dry_run:
            call("PATCH", f"/appInfoLocalizations/{loc['id']}", {"data": {"type": "appInfoLocalizations", "id": loc["id"], "attributes": {"name": NAME, "subtitle": SUBTITLE}}})

    # Version text
    vs = call("GET", f"/apps/{APP_ID}/appStoreVersions", params={"filter[platform]": "IOS", "filter[versionString]": a.version, "fields[appStoreVersions]": "versionString,appVersionState"})["data"]
    if not vs: sys.exit(f"no version {a.version}")
    vlocs = call("GET", f"/appStoreVersions/{vs[0]['id']}/appStoreVersionLocalizations", params={"fields[appStoreVersionLocalizations]": "locale,keywords"})["data"]
    for loc in vlocs:
        print(f"version {a.version} {loc['attributes']['locale']}: keywords, description, promotional text")
        if not a.dry_run:
            call("PATCH", f"/appStoreVersionLocalizations/{loc['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"],
                 "attributes": {"keywords": KEYWORDS, "description": DESCRIPTION, "promotionalText": PROMO}}})
    print("done" if not a.dry_run else "dry run")

if __name__ == "__main__":
    main()
