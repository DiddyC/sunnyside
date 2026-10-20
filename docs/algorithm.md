# Seat-side algorithm (v3)

Everything lives in `Sunnyside/Core` as pure functions. Entry point: `SeatEngine.recommend(journey:)`.

## 1. Sample the route
Every 5 minutes from departure to arrival (minimum 2, capped at 400 samples). Position is interpolated along the great circle. Duration is the traveller's override (from the ticket) or `distance / vehicle.averageSpeed + overhead`.

## 2. Heading at each sample
The heading is the great-circle tangent at that point: the initial bearing from the sample point to the destination (final bearing at the last sample). On JFK→LHR the heading drifts 51° → 108°, so reusing the departure bearing (v2 behaviour) put the sun on the wrong side for 8–16 % of long-haul departures.

## 3. Sun position
`SunCalculator.position` (low-precision Meeus). Validated against the NOAA algorithm over 4,800 points in 2026: altitude error ≤ 0.009°, azimuth error ≤ 0.02° below 85° altitude.

## 4. Side-window glare per sample
What a passenger feels is direct sun through a **vertical side window**:

```
glare = DNI(altitude) · cos(altitude) · |sin(relativeAzimuth)|
DNI   = 0.7 ^ (airMass ^ 0.678)        (clear-sky, Kasten–Young air mass)
```

| sun altitude | 5° | 10° | 20° | 30° | 45° | 60° | 80° |
|---|---|---|---|---|---|---|---|
| glare (normalised) | 0.36 | 0.64 | 0.92 | 1.00 | 0.92 | 0.69 | 0.25 |

A low sun square on to the window is the worst case. A noon sun hits the roof. Sun dead ahead or behind counts for neither side. Below 2° altitude the sun is ignored (terrain, haze).

`relativeAzimuth < 180` → sun on the **right** → shade on the **left**.

## 5. Aggregate
Trapezoid integration over time gives exposure in "peak-sun hours" per side.

- total exposure < 0.1 h → **ANYWHERE** (no sun to dodge)
- one side ≥ 60 % → **LEFT** / **RIGHT** (the subtitle still names a crossover if there is one)
- otherwise → **EITHER**, with the lower-exposure side named

Contiguous runs of samples with the sun on the same side become `segments`; those carrying ≥ 15 % of the exposure are shown on the route strip with local switch times.

## Edge cases
- Night: handled by the exposure threshold.
- North–south routes flip sides at local solar noon (east–west routes at mid-latitudes keep the sun on one side all day).
- Same origin and destination (< 0.5 km): rejected in the form.
- Time zones: all maths uses absolute `Date`; display uses the origin's time zone from MapKit.
