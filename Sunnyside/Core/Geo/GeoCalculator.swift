import Foundation
import CoreLocation

struct GeoCalculator {

    // True bearing (0–360°, clockwise from North) from one coordinate to another
    static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = rad(from.latitude), lat2 = rad(to.latitude)
        let dLon = rad(to.longitude - from.longitude)
        let x = cos(lat2) * sin(dLon)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(x, y) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    // Great-circle distance in kilometres
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let R = 6371.0
        let dLat = rad(to.latitude - from.latitude)
        let dLon = rad(to.longitude - from.longitude)
        let a = sin(dLat/2) * sin(dLat/2)
                + cos(rad(from.latitude)) * cos(rad(to.latitude)) * sin(dLon/2) * sin(dLon/2)
        return R * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    // Great-circle interpolation at fraction [0, 1] between two coordinates
    static func interpolate(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        fraction f: Double
    ) -> CLLocationCoordinate2D {
        let f = max(0, min(1, f))
        let lat1 = rad(from.latitude), lon1 = rad(from.longitude)
        let lat2 = rad(to.latitude), lon2 = rad(to.longitude)

        let d = distance(from: from, to: to) / 6371.0  // angular distance (radians)
        guard d > 1e-9 else { return from }

        let sinD = sin(d)
        let A = sin((1 - f) * d) / sinD
        let B = sin(f * d) / sinD

        let x = A * cos(lat1) * cos(lon1) + B * cos(lat2) * cos(lon2)
        let y = A * cos(lat1) * sin(lon1) + B * cos(lat2) * sin(lon2)
        let z = A * sin(lat1) + B * sin(lat2)

        return CLLocationCoordinate2D(
            latitude:  atan2(z, sqrt(x*x + y*y)) * 180 / .pi,
            longitude: atan2(y, x) * 180 / .pi
        )
    }

    /// Sun azimuth relative to the direction of travel, 0…360 (90 = directly to the right).
    static func relativeAzimuth(bearing: Double, sunAzimuth: Double) -> Double {
        (sunAzimuth - bearing + 720).truncatingRemainder(dividingBy: 360)
    }

    /// Which side of the vehicle is shaded given heading and sun azimuth.
    /// Returns nil when the sun is below the horizon.
    static func shadySide(bearing: Double, sunAzimuth: Double, sunAltitude: Double) -> SeatSide? {
        guard sunAltitude > 0 else { return nil }
        // Sun on the right (relative azimuth 0…180) → shade on the left, and vice versa.
        return relativeAzimuth(bearing: bearing, sunAzimuth: sunAzimuth) < 180 ? .left : .right
    }

    /// Heading (° clockwise from N) of the great-circle route at fraction `f` of the way
    /// from `from` to `to` – i.e. the *initial* bearing from the interpolated point to `to`.
    /// At f = 1 the final bearing is returned (reverse bearing from `to` back to `from`, +180°).
    static func heading(along from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, at f: Double) -> Double {
        if f >= 1 - 1e-9 {
            return (bearing(from: to, to: from) + 180).truncatingRemainder(dividingBy: 360)
        }
        let p = interpolate(from: from, to: to, fraction: f)
        return bearing(from: p, to: to)
    }

    private static func rad(_ deg: Double) -> Double { deg * .pi / 180 }
}
