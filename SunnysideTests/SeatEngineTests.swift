import XCTest
import CoreLocation
@testable import Sunnyside

final class SeatEngineTests: XCTestCase {

    // MARK: Weighting physics

    func testGlareIsStrongestForLowSunSquareOnToTheWindow() {
        let low  = sample(alt: 20, relAz: 90)
        let high = sample(alt: 70, relAz: 90)
        let ahead = sample(alt: 20, relAz: 2)
        XCTAssertGreaterThan(low.glare, high.glare, "a low sun through the side window beats a high sun hitting the roof")
        XCTAssertLessThan(ahead.glare, low.glare * 0.1, "sun dead ahead barely touches the side windows")
        XCTAssertEqual(sample(alt: -3, relAz: 90).glare, 0)
    }

    func testSunSideFromRelativeAzimuth() {
        XCTAssertEqual(sample(alt: 30, relAz: 90).sunSide, .right)
        XCTAssertEqual(sample(alt: 30, relAz: 270).sunSide, .left)
        XCTAssertEqual(sample(alt: 30, relAz: 90).shadySide, .left)
        XCTAssertEqual(sample(alt: -1, relAz: 90).sunSide, .none)
    }

    // MARK: Journey-level

    // Night train Berlin → Munich, departs 23:00 local → no sun.
    func testNightJourneyHasNoSun() {
        let j = Journey(origin: place("Berlin", 52.52, 13.40), destination: place("Munich", 48.14, 11.58),
                        vehicle: .train, departureTime: utc(2024, 6, 21, 21, 0))
        let rec = SeatEngine.recommend(journey: j)
        XCTAssertEqual(rec.verdict, .noSun)
    }

    // Winter, heading east Paris → Strasbourg at 10:00 local: low southern sun → on the RIGHT → sit LEFT.
    func testEastboundWinterMorningSitLeft() {
        let j = Journey(origin: place("Paris", 48.85, 2.35), destination: place("Strasbourg", 48.57, 7.75),
                        vehicle: .train, departureTime: utc(2024, 12, 15, 9, 0))
        let rec = SeatEngine.recommend(journey: j)
        XCTAssertEqual(rec.verdict, .sitLeft)
        XCTAssertGreaterThan(rec.sunRightShare, 0.9)
    }

    // Same route westbound → sun on the LEFT → sit RIGHT.
    func testWestboundWinterMorningSitRight() {
        let j = Journey(origin: place("Strasbourg", 48.57, 7.75), destination: place("Paris", 48.85, 2.35),
                        vehicle: .train, departureTime: utc(2024, 12, 15, 9, 0))
        XCTAssertEqual(SeatEngine.recommend(journey: j).verdict, .sitRight)
    }

    // Southbound in the northern hemisphere, mid-morning: sun in the SE = ahead-left → sit RIGHT.
    func testSouthboundMorningSitRight() {
        let j = Journey(origin: place("Hamburg", 53.55, 9.99), destination: place("Frankfurt", 50.11, 8.68),
                        vehicle: .train, departureTime: utc(2024, 4, 10, 7, 30))
        XCTAssertEqual(SeatEngine.recommend(journey: j).verdict, .sitRight)
    }

    // Long southbound trip spanning solar noon: sun moves from left (morning, east) to right (afternoon, west)
    // → segments must show a switch and the verdict should not be a confident 100% either way.
    func testSunCrossesOverOnLongSouthboundTrip() {
        let j = Journey(origin: place("Hamburg", 53.55, 9.99), destination: place("Munich", 48.14, 11.58),
                        vehicle: .bus, departureTime: utc(2024, 6, 21, 7, 0), durationOverride: 10 * 3600)
        let rec = SeatEngine.recommend(journey: j)
        let sunnySegments = rec.segments.filter { $0.sunSide != .none }
        XCTAssertGreaterThanOrEqual(sunnySegments.count, 2, "expected the sun to change sides")
        XCTAssertLessThan(max(rec.sunLeftShare, rec.sunRightShare), 0.95)
    }

    // Identical endpoints must not crash and yields a no-sun/undefined-safe result.
    func testSameOriginAndDestinationIsSafe() {
        let j = Journey(origin: place("A", 48.85, 2.35), destination: place("A", 48.85, 2.35),
                        vehicle: .bus, departureTime: utc(2024, 6, 21, 12, 0))
        XCTAssertTrue(j.isTooShort)
        _ = SeatEngine.recommend(journey: j)   // must not trap
    }

    // Sampling density: a 50-minute trip gets more than two samples.
    func testShortTripIsSampledDensely() {
        let j = Journey(origin: place("A", 48.85, 2.35), destination: place("B", 49.2, 2.9),
                        vehicle: .bus, departureTime: utc(2024, 6, 21, 12, 0), durationOverride: 50 * 60)
        let rec = SeatEngine.recommend(journey: j)
        XCTAssertGreaterThanOrEqual(rec.samples.count, 10)
    }

    // Duration override is respected.
    func testDurationOverride() {
        var j = Journey(origin: place("A", 48.85, 2.35), destination: place("B", 48.57, 7.75),
                        vehicle: .train, departureTime: utc(2024, 6, 21, 12, 0))
        XCTAssertEqual(j.duration, j.estimatedDuration)
        j.durationOverride = 2 * 3600 + 15 * 60
        XCTAssertEqual(j.duration, 8100)
        XCTAssertEqual(j.formattedDuration, "2 h 15 min")
    }

    // MARK: Helpers

    private func sample(alt: Double, relAz: Double) -> SunSample {
        SunSample(time: Date(), coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                  heading: 0, altitude: alt, azimuth: relAz, minimumAltitude: 2)
    }

    private func place(_ name: String, _ lat: Double, _ lon: Double) -> PlaceResult {
        PlaceResult(name: name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }

    private func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }
}
