import Foundation
import CoreLocation

/// Which side of the vehicle the passenger should sit on.
enum SeatSide: Equatable { case left, right }

struct SunSample: Equatable {
    enum SunSide: Equatable { case left, right, none }

    let time: Date
    let coordinate: CLLocationCoordinate2D
    let heading: Double        // vehicle heading at this point, ° clockwise from N
    let altitude: Double       // sun altitude °, negative = below horizon
    let azimuth: Double        // sun azimuth °, 0 = N, 90 = E
    let minimumAltitude: Double

    /// Sun azimuth relative to the direction of travel, 0…360 (90 = directly right).
    var relativeAzimuth: Double {
        (azimuth - heading + 720).truncatingRemainder(dividingBy: 360)
    }
    var hasSun: Bool { altitude >= minimumAltitude }

    /// Which side of the vehicle the sun is on (not the shady side).
    var sunSide: SunSide {
        guard hasSun else { return .none }
        let r = relativeAzimuth
        return r < 180 ? .right : .left
    }
    /// The seat side that is in shade for this sample.
    var shadySide: SeatSide? {
        switch sunSide { case .right: return .left; case .left: return .right; case .none: return nil }
    }

    /// Direct-sun irradiance on a vertical side window, normalised to 0…1.
    ///   DNI(alt) · cos(alt) · |sin(relAz)|,  DNI via Kasten–Young air mass.
    var glare: Double {
        guard hasSun else { return 0 }
        let altRad = altitude * .pi / 180
        let relRad = relativeAzimuth * .pi / 180
        return Self.directNormalIrradiance(altitudeDeg: altitude) * cos(altRad) * abs(sin(relRad)) / Self.maxGlare
    }

    /// Normalised DNI 0…1 for a clear sky (Meinel/Kasten–Young: 0.7^(AM^0.678)).
    static func directNormalIrradiance(altitudeDeg: Double) -> Double {
        guard altitudeDeg > 0 else { return 0 }
        let z = 90 - altitudeDeg
        let zr = z * .pi / 180
        let airMass = 1 / (cos(zr) + 0.50572 * pow(96.07995 - z, -1.6364))
        return pow(0.7, pow(airMass, 0.678))
    }

    /// Peak of DNI(alt)·cos(alt) over altitude, used for normalisation (≈0.39 at ~20°).
    static let maxGlare: Double = {
        stride(from: 0.5, through: 90, by: 0.5)
            .map { directNormalIrradiance(altitudeDeg: $0) * cos($0 * .pi / 180) }
            .max() ?? 1
    }()
}

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (a: CLLocationCoordinate2D, b: CLLocationCoordinate2D) -> Bool {
        a.latitude == b.latitude && a.longitude == b.longitude
    }
}
