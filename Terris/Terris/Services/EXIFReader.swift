//
//  EXIFReader.swift
//  Terris
//

import Foundation
import ImageIO
import UIKit

struct EXIFResult {
    let latitude: Double?
    let longitude: Double?
    let takenDate: Date?
}

struct EXIFReader {
    static func read(from data: Data) -> EXIFResult {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let meta = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return EXIFResult(latitude: nil, longitude: nil, takenDate: nil)
        }

        // GPS
        var lat: Double? = nil
        var lon: Double? = nil
        if let gps = meta[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            let rawLat  = gps[kCGImagePropertyGPSLatitude  as String] as? Double
            let rawLon  = gps[kCGImagePropertyGPSLongitude as String] as? Double
            let latRef  = gps[kCGImagePropertyGPSLatitudeRef  as String] as? String
            let lonRef  = gps[kCGImagePropertyGPSLongitudeRef as String] as? String
            if let rawLat, let rawLon {
                lat = (latRef == "S") ? -rawLat : rawLat
                lon = (lonRef == "W") ? -rawLon : rawLon
            }
        }

        // Date
        var takenDate: Date? = nil
        if let exif = meta[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateStr = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy:MM:dd HH:mm:ss"
            takenDate = fmt.date(from: dateStr)
        }

        return EXIFResult(latitude: lat, longitude: lon, takenDate: takenDate)
    }
}
