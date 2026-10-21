# Sunnyside — Product Brief

## Problem
When traveling by bus, train, or plane, the sun can make a seat unbearable — glare, heat, squinting for hours. There's no easy way to know in advance which side of the vehicle to sit on.

## Solution
Sunnyside takes your route and travel time, computes the sun's position across the journey, and tells you simply: **sit on the left** or **sit on the right**.

## User flow
1. Open app
2. Enter origin (or use current location), destination, vehicle type
3. Tap "Find my seat"
4. See: **"Sit on the LEFT"** / **"Sit on the RIGHT"** / **"No sun — enjoy any seat"**
5. Optional: see a visual showing travel direction vs sun angle

## Core algorithm

### Step 1 — Geocode
Convert origin and destination strings to (lat, lon) coordinates.

### Step 2 — Travel bearing
```
bearing = arctan2(sin(Δlon)·cos(lat2),
                  cos(lat1)·sin(lat2) − sin(lat1)·cos(lat2)·cos(Δlon))
bearing = (bearing + 360) % 360   // normalize to 0–360°
```

### Step 3 — Sun position sampling
For each hour H from departure to arrival:
- Compute position along route at time H (interpolate by distance)
- Get sun azimuth + altitude at that (lat, lon, time) using VSOP87 / simplified astronomical formula
- If altitude < 0°: sun is below horizon, skip this sample

### Step 4 — Seat decision per sample
```
angle_to_sun_on_right = (sun_azimuth − bearing + 360) % 360
angle_to_sun_on_left  = (360 − angle_to_sun_on_right) % 360

if angle_to_sun_on_right < angle_to_sun_on_left:
    sun is on the RIGHT → sit LEFT to avoid it
else:
    sun is on the LEFT → sit RIGHT to avoid it
```

### Step 5 — Aggregate
Weight each sample by side-window glare (low sun square on to the window counts most; noon sun hits the roof) and integrate over time. Return the dominant side; below a 60/40 split surface "either" and the crossover time. See docs/algorithm.md.

## v2 → v3 improvements
| Area | v2 | v3 |
|------|----|----|
| Sun sampling | Departure only | Hourly across journey |
| Vehicle types | Bus, Train, Plane | + Car, Ferry |
| UI | Raw JSON output | Polished native iOS |
| Platform | Python/Flask (web) | Swift/SwiftUI (offline) |
| Geocoding | Nominatim | MapKit / Apple (no key) |
| Visualization | None | Direction + sun angle diagram |
| Edge cases | Basic | Night travel, polar summer, east-west routes |

## Edge cases to handle
- **Night travel**: sun below horizon entire journey → "No sun, sit anywhere"
- **North–south route across solar noon**: sun shifts sides during journey → show the switch time and, when close, an "either" verdict (east–west routes at mid-latitudes keep the sun on one side)
- **Very short trip** (< 15 min): single sample is fine
- **Polar regions in summer**: midnight sun — treat normally, algorithm still valid
- **No location permission**: manual origin entry fallback

## What the app is NOT
- Not a navigation app
- Not a ticketing app
- No accounts, no cloud sync, no ads
- Does not tell you about window seat availability

## Design principles
- Answer in one word (LEFT / RIGHT) — everything else is secondary
- Offline-first — no network needed after geocoding
- Privacy: nothing but the place-search text leaves the device, and only to Apple Maps
- Fast: result in under 2 seconds

## Success metric
User opens app, gets a clear answer, closes app. Done in under 30 seconds.
