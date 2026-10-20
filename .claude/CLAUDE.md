# Sunnyside — iOS App

## What this is
An iOS app that tells you **which side of the vehicle to sit on to avoid the sun** during a journey. Input: origin, destination, transport type. Output: left or right seat recommendation.

## Core algorithm (v3, see docs/algorithm.md)
1. Geocode origin + destination with MapKit (no API key)
2. Sample the great-circle route every 5 min; heading = tangent at each sample (not the departure bearing)
3. Sun altitude/azimuth per sample (`SunCalculator`, validated ±0.02° vs NOAA)
4. Weight each sample by side-window glare: DNI(alt)·cos(alt)·|sin(relAz)| (low sun counts most)
5. Aggregate → LEFT / RIGHT / EITHER / ANYWHERE, plus segments with local switch times

## Vehicle types (average speed is only a fallback; the user can enter the ticket duration)
| Vehicle | Speed | Overhead |
|---------|-------|----------|
| Train   | 100 km/h | — |
| Bus     | 70 km/h  | — |
| Car     | 90 km/h  | — |
| Plane   | 800 km/h | +25 min |
| Ferry   | 35 km/h  | +10 min |

## Tech stack (iOS v3)
- Swift + SwiftUI
- CoreLocation for device location
- MapKit / Apple Maps for geocoding
- Astronomy: computed natively (no dependency)
- No backend — fully on-device computation; only place-search text goes to Apple Maps

## Project structure (target)
```
Sunnyside/
  App/
  Features/
    Journey/      # input form
    Result/       # seat recommendation + visualization
  Core/
    Engine/       # SeatEngine: sampling + aggregation (pure)
    Sun/          # sun position math, SunSample glare model
    Geo/          # MapKit place search, bearing, distance, heading
    Vehicle/      # speed/type definitions
    Models/       # Journey, SeatRecommendation
  Design/         # colours, system-font helpers, card/button styles
  Resources/      # Assets.xcassets (AppIcon, LaunchBackground, AccentColor), PrivacyInfo.xcprivacy
docs/             # brief, algorithm, setup
```

## Coding conventions
- SwiftUI-first, no UIKit unless forced
- No third-party dependencies unless unavoidable
- Pure functions for all math (easily testable)
- No analytics, no tracking, no accounts — privacy by design

## Current state
- v2 prototype: Python/Flask in `old/sunnyside_v2/` — reference only, not shipped
- v3 iOS: redesigned Oct 2026 (MapKit search, departure time picker, duration override, vehicle-shaped seat map inside a sun compass with time scrubber, light/dark/system appearance, switch reminder, 22 unit tests)
- Needs: an Apple ID signed into Xcode for the configured team. No fonts, no API keys.
- `-demo left|right|switch|mixed|car|ferry|night|plane|dayplane` and `-appearance light|dark|system` launch arguments open canned results (screenshots, previews)
- See `docs/setup.md`

## Regenerate Xcode project after adding files
```bash
xcodegen generate
```
Info.plist is generated from `project.yml`; never hand-edit it.
