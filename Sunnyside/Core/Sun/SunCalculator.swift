import Foundation

// Jean Meeus "Astronomical Algorithms" Ch.25 simplified low-precision solar position.
// Accurate to ~1°, sufficient for seat-side determination.
struct SunCalculator {

    static func position(date: Date, lat: Double, lon: Double) -> (altitude: Double, azimuth: Double) {
        let jd = julianDay(date: date)
        let n = jd - 2451545.0  // days from J2000.0

        // Mean longitude
        let L = mod360(280.460 + 0.9856474 * n)
        // Mean anomaly
        let g = mod360(357.528 + 0.9856003 * n)
        let gRad = rad(g)

        // Ecliptic longitude
        let lambda = L + 1.915 * sin(gRad) + 0.020 * sin(2 * gRad)
        let lambdaRad = rad(lambda)

        // Obliquity of ecliptic
        let epsilon = 23.439 - 0.0000004 * n
        let epsilonRad = rad(epsilon)

        // Declination
        let sinDec = sin(epsilonRad) * sin(lambdaRad)
        let decRad = asin(sinDec)

        // Right ascension (hours)
        var ra = atan2(cos(epsilonRad) * sin(lambdaRad), cos(lambdaRad)) * 180 / .pi
        if ra < 0 { ra += 360 }
        ra /= 15

        // Greenwich Mean Sidereal Time (hours)
        let gmst = mod24(6.697375 + 0.0657098242 * n + utHours(date: date))

        // Local Hour Angle (hours → degrees)
        var ha = mod24(gmst - ra + lon / 15)
        if ha > 12 { ha -= 24 }
        let haRad = rad(ha * 15)

        let latRad = rad(lat)

        // Altitude
        let sinAlt = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(haRad)
        let altitude = asin(max(-1, min(1, sinAlt))) * 180 / .pi

        // Azimuth (clockwise from North)
        let cosAlt = cos(asin(max(-1, min(1, sinAlt))))
        let cosAz = cosAlt > 0.0001
            ? (sin(decRad) - sin(latRad) * sinAlt) / (cos(latRad) * cosAlt)
            : 0
        var azimuth = acos(max(-1, min(1, cosAz))) * 180 / .pi
        if sin(haRad) > 0 { azimuth = 360 - azimuth }

        return (altitude: altitude, azimuth: azimuth)
    }

    // MARK: - Helpers

    private static func rad(_ deg: Double) -> Double { deg * .pi / 180 }
    private static func mod360(_ x: Double) -> Double { x.truncatingRemainder(dividingBy: 360) + (x < 0 ? 360 : 0) }
    private static func mod24(_ x: Double) -> Double { x.truncatingRemainder(dividingBy: 24) + (x < 0 ? 24 : 0) }

    private static func julianDay(date: Date) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        var Y = Double(c.year!), M = Double(c.month!)
        let D = Double(c.day!) + (Double(c.hour!) + Double(c.minute!) / 60 + Double(c.second!) / 3600) / 24
        if M <= 2 { Y -= 1; M += 12 }
        let A = floor(Y / 100)
        let B = 2 - A + floor(A / 4)
        return floor(365.25 * (Y + 4716)) + floor(30.6001 * (M + 1)) + D + B - 1524.5
    }

    private static func utHours(date: Date) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.hour, .minute, .second], from: date)
        return Double(c.hour!) + Double(c.minute!) / 60 + Double(c.second!) / 3600
    }
}
