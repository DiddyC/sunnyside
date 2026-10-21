#!/usr/bin/env python3
"""Create the lifetime non-consumable in App Store Connect (idempotent) at a given USD price.

  scripts/create-iap.py [--price 1.99] [--dry-run]

The product is created in "Ready to Submit" state; it ships when it is added to a version's
review submission. Flip Monetization.enabled in the app only after that.
"""
import argparse, importlib.util, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("submit", ROOT / "submit.py"); asc = importlib.util.module_from_spec(spec); spec.loader.exec_module(asc)
call, APP_ID = asc.call, asc.APP_ID

def call_or_none(method, path, **kw):
    import urllib.request, urllib.error, json as _json
    url = path if path.startswith("http") else asc.API + path
    if kw.get("params"): import urllib.parse; url += ("&" if "?" in url else "?") + urllib.parse.urlencode(kw["params"])
    req = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {asc.token()}"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r: return _json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        if e.code == 404: return {}
        raise

PRODUCT_ID = "com.didisd.SunnySideApp.lifetime"
REF_NAME = "Shady Seat Lifetime"
DISPLAY_NAME = "Shady Seat Lifetime"
DESCRIPTION = "Unlimited searches, no ads, forever."
REVIEW_NOTE = "One-time unlock. Free users get one search per day; this removes the limit and the ad slot."

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--price", default="1.99"); ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args(); asc.load_env()

    existing = call("GET", f"/apps/{APP_ID}/inAppPurchasesV2", params={"filter[productId]": PRODUCT_ID, "fields[inAppPurchases]": "productId,state,name"})["data"]
    if existing:
        iap = existing[0]; print(f"exists: {iap['attributes']['name']} ({iap['attributes']['state']})")
    else:
        print(f"creating {PRODUCT_ID} ({REF_NAME})")
        if a.dry_run: return
        # The in-app purchase resource lives under /v2; asc.call only prefixes /v1 for relative paths.
        iap = call("POST", "https://api.appstoreconnect.apple.com/v2/inAppPurchases", {"data": {"type": "inAppPurchases",
              "attributes": {"name": REF_NAME, "productId": PRODUCT_ID, "inAppPurchaseType": "NON_CONSUMABLE", "reviewNote": REVIEW_NOTE},
              "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}}})["data"]
        print("  created", iap["id"])

    # Localization (en-US)
    locs = call("GET", f"https://api.appstoreconnect.apple.com/v2/inAppPurchases/{iap['id']}/inAppPurchaseLocalizations", params={"fields[inAppPurchaseLocalizations]": "locale,name"})["data"]
    if not any(l["attributes"]["locale"] == "en-US" for l in locs):
        if not a.dry_run:
            call("POST", "/inAppPurchaseLocalizations", {"data": {"type": "inAppPurchaseLocalizations", "attributes": {"locale": "en-US", "name": DISPLAY_NAME, "description": DESCRIPTION},
                 "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap["id"]}}}}})
        print("  en-US localization set")

    # Price: find the USD price point closest to --price, then a manual schedule with USA as base territory.
    pts = call("GET", f"https://api.appstoreconnect.apple.com/v2/inAppPurchases/{iap['id']}/pricePoints", params={"filter[territory]": "USA", "fields[inAppPurchasePricePoints]": "customerPrice,proceeds", "limit": 200})["data"]
    target = float(a.price)
    best = min(pts, key=lambda p: abs(float(p["attributes"]["customerPrice"]) - target))
    print(f"  price point USD {best['attributes']['customerPrice']} (proceeds {best['attributes']['proceeds']})")
    if a.dry_run: return
    sched = call_or_none("GET", f"https://api.appstoreconnect.apple.com/v2/inAppPurchases/{iap['id']}/iapPriceSchedule", params={"fields[inAppPurchasePriceSchedules]": "baseTerritory"})
    if not sched.get("data"):
        call("POST", "/inAppPurchasePriceSchedules", {"data": {"type": "inAppPurchasePriceSchedules",
             "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap["id"]}},
                               "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                               "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price1}"}]}}},
             "included": [{"type": "inAppPurchasePrices", "id": "${price1}", "attributes": {"startDate": None},
                           "relationships": {"inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": best["id"]}}}}]})
        print("  price schedule created")
    avail = call_or_none("GET", f"https://api.appstoreconnect.apple.com/v2/inAppPurchases/{iap['id']}/inAppPurchaseAvailability", params={"fields[inAppPurchaseAvailabilities]": "availableInNewTerritories"})
    if not avail.get("data"):
        terr = call("GET", "/territories", params={"limit": 200})["data"]
        call("POST", "/inAppPurchaseAvailabilities", {"data": {"type": "inAppPurchaseAvailabilities", "attributes": {"availableInNewTerritories": True},
             "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap["id"]}},
                               "availableTerritories": {"data": [{"type": "territories", "id": t["id"]} for t in terr]}}}})
        print("  available in all territories")
    print("done")

if __name__ == "__main__":
    main()
