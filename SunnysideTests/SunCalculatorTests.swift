import XCTest
import CoreLocation
@testable import Sunnyside

final class SunCalculatorTests: XCTestCase {

    // London, 21 Jun 2024 12:00 BST (11:00 UTC) — about an hour before solar noon,
    // so the sun is still east of south. NOAA: alt ≈ 59.5°, az ≈ 151°.
    func testLondonSummerLateMorning() {
        let date = utc(2024, 6, 21, 11, 0)
        let r = SunCalculator.position(date: date, lat: 51.5, lon: -0.12)
        XCTAssertEqual(r.altitude, 59.5, accuracy: 1.5)
        XCTAssertEqual(r.azimuth, 151, accuracy: 2)
    }

    // London winter solstice, 12:00 UTC: alt ≈ 15°, az ≈ 180°.
    func testLondonWinterNoon() {
        let r = SunCalculator.position(date: utc(2024, 12, 21, 12, 0), lat: 51.5, lon: -0.12)
        XCTAssertEqual(r.altitude, 15, accuracy: 1.5)
        XCTAssertEqual(r.azimuth, 180, accuracy: 3)
    }

    func testNighttime() {
        let r = SunCalculator.position(date: utc(2024, 6, 20, 23, 0), lat: 51.5, lon: -0.12)
        XCTAssertLessThan(r.altitude, 0)
    }

    // Southern hemisphere: Sydney local noon in December → sun in the SOUTH (az ≈ 0/360).
    func testSydneySummerNoonSunIsSouth() {
        // 21 Dec 2024 02:00 UTC ≈ 13:00 AEDT; solar noon ≈ 12:58 AEDT at lon 151.2
        let r = SunCalculator.position(date: utc(2024, 12, 21, 1, 58), lat: -33.87, lon: 151.21)
        XCTAssertGreaterThan(r.altitude, 75)
        let azFromNorth = min(r.azimuth, 360 - r.azimuth)
        XCTAssertLessThan(azFromNorth, 8, "Sydney midsummer noon sun should be almost due south (azimuth near 0/360), got \(r.azimuth)")
    }

    // Morning sun is in the east (az < 180), afternoon in the west (az > 180).
    func testAzimuthQuadrants() {
        let morning = SunCalculator.position(date: utc(2024, 3, 20, 7, 0), lat: 40.7, lon: -74.0 + 180) // lon 106E, 07:00 UTC ≈ 14:00 local? keep simple below
        _ = morning
        let nyMorning = SunCalculator.position(date: utc(2024, 3, 20, 13, 0), lat: 40.7, lon: -74.0) // 09:00 EDT
        let nyAfternoon = SunCalculator.position(date: utc(2024, 3, 20, 20, 0), lat: 40.7, lon: -74.0) // 16:00 EDT
        XCTAssertLessThan(nyMorning.azimuth, 180)
        XCTAssertGreaterThan(nyAfternoon.azimuth, 180)
    }

    // MARK: Geometry

    func testSeatSideNorthTravelSunEast() {
        XCTAssertEqual(GeoCalculator.shadySide(bearing: 0, sunAzimuth: 90, sunAltitude: 30), .left,
                       "Heading north, an eastern sun is on your RIGHT → sit LEFT")
    }

    func testSeatSideEastTravelSunSouth() {
        XCTAssertEqual(GeoCalculator.shadySide(bearing: 90, sunAzimuth: 180, sunAltitude: 30), .left,
                       "Heading east, a southern sun is on your RIGHT → sit LEFT")
    }

    func testSeatSideWestTravelSunSouth() {
        XCTAssertEqual(GeoCalculator.shadySide(bearing: 270, sunAzimuth: 180, sunAltitude: 30), .right,
                       "Heading west, a southern sun is on your LEFT → sit RIGHT")
    }

    func testNoSunBelowHorizon() {
        XCTAssertNil(GeoCalculator.shadySide(bearing: 0, sunAzimuth: 180, sunAltitude: -5))
    }

    func testDistanceLondonParis() {
        let d = GeoCalculator.distance(from: coord(51.5, -0.12), to: coord(48.85, 2.35))
        XCTAssertEqual(d, 344, accuracy: 10)
    }

    func testInterpolateMidpoint() {
        let mid = GeoCalculator.interpolate(from: coord(51.5, -0.12), to: coord(48.85, 2.35), fraction: 0.5)
        XCTAssertEqual(mid.latitude, 50.19, accuracy: 0.3)
        XCTAssertEqual(mid.longitude, 1.09, accuracy: 0.3)
    }

    // JFK→LHR: initial bearing ≈ 51°, final ≈ 108°. The heading must drift along the route.
    func testHeadingDriftsAlongGreatCircle() {
        let jfk = coord(40.64, -73.78), lhr = coord(51.47, -0.46)
        let start = GeoCalculator.heading(along: jfk, to: lhr, at: 0)
        let mid   = GeoCalculator.heading(along: jfk, to: lhr, at: 0.5)
        let end   = GeoCalculator.heading(along: jfk, to: lhr, at: 1)
        XCTAssertEqual(start, 51, accuracy: 3)
        XCTAssertEqual(end, 108, accuracy: 3)
        XCTAssertGreaterThan(mid, start + 15)
        XCTAssertLessThan(mid, end - 15)
    }

    // MARK: Helpers

    func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    func coord(_ lat: Double, _ lon: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
