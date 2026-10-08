import Foundation
import Supabase

/// The app's single Supabase client plus shared encoding and error helpers.
nonisolated enum Backend {
    /// Return link for the Google sign-in web flow. Must be listed under
    /// Supabase → Authentication → URL Configuration → Redirect URLs.
    static let authRedirectURL = URL(string: "pushcraft://auth-callback")!

    static let client: SupabaseClient = {
        let url = URL(string: Config.EXPO_PUBLIC_SUPABASE_URL) ?? URL(string: "https://invalid.supabase.co")!
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: Config.EXPO_PUBLIC_SUPABASE_ANON_KEY,
            options: SupabaseClientOptions(
                db: .init(decoder: BackendCoding.decoder),
                auth: .init(redirectToURL: authRedirectURL)
            )
        )
    }()

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

/// JSON decoding for database responses: snake_case keys, Postgres timestamps.
nonisolated enum BackendCoding {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = BackendDates.parse(raw) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date: \(raw)")
        }
        return decoder
    }()
}

nonisolated enum BackendDates {
    /// Parses Postgres ISO-8601 timestamps such as `2026-10-05T10:51:53.947123+00:00`.
    static func parse(_ raw: String) -> Date? {
        var value = raw
        if let dot = value.firstIndex(of: "."),
           let zoneStart = value[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            let fraction = String(value[value.index(after: dot)..<zoneStart])
            let millis = String((fraction + "000").prefix(3))
            value = String(value[..<dot]) + "." + millis + String(value[zoneStart...])
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    /// `yyyy-MM-dd` for a date in the given time zone.
    static func dayString(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// Classifies backend errors into offline vs. server-reported codes.
nonisolated enum BackendFailure {
    /// The `RAISE EXCEPTION` code from a database function, e.g. `battle_not_found`.
    static func code(_ error: Error) -> String? {
        (error as? PostgrestError)?.message
    }

    static func isOffline(_ error: Error) -> Bool {
        if error is URLError { return true }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return true }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
           underlying.domain == NSURLErrorDomain {
            return true
        }
        return false
    }
}
