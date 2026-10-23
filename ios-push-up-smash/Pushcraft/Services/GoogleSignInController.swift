import GoogleSignIn
import UIKit

/// Presents Google's native account-picker sheet and returns the Google ID
/// token plus the raw nonce that was used for the request.
///
/// The client ID and its reversed URL scheme come from the merged Info.plist
/// (see `GoogleSignInInfo.plist`); no runtime configuration is needed.
final class GoogleSignInController {
    enum GoogleSignInError: Error {
        case cannotPresent
        case noIDToken
    }

    /// Thrown when the user closes the native sheet without signing in.
    struct Canceled: Error {}

    struct Credentials {
        let idToken: String
        let nonce: String
    }

    /// True once the real Google OAuth client is wired into the merged
    /// Info.plist. Before that, the native flow is skipped so the browser
    /// fallback handles sign-in instead.
    static var isConfigured: Bool {
        let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? ""
        return !clientID.isEmpty && !clientID.contains("PLACEHOLDER")
    }

    /// Runs the native Google sign-in flow.
    ///
    /// - Returns: the ID token and the raw nonce. Supabase's
    ///   `signInWithIdToken` expects the raw nonce; Google hashes it into the
    ///   token's `nonce` claim.
    func signIn() async throws -> Credentials {
        guard let presenting = Self.topViewController() else {
            throw GoogleSignInError.cannotPresent
        }
        let nonce = Self.randomNonce()
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presenting,
            hint: nil,
            additionalScopes: nil,
            nonce: nonce
        )
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInError.noIDToken
        }
        return Credentials(idToken: idToken, nonce: nonce)
    }

    /// True when the user closed the native sheet without signing in
    /// (these failures should not trigger the browser fallback).
    static func isCancellation(_ error: Error) -> Bool {
        if error is Canceled { return true }
        let nsError = error as NSError
        return nsError.domain == kGIDSignInErrorDomain
            && nsError.code == GIDSignInError.Code.canceled.rawValue
    }

    // MARK: - Helpers

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        while result.count < length {
            var byte: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
            guard status == errSecSuccess else { continue }
            if Int(byte) < charset.count * (256 / charset.count) {
                result.append(charset[Int(byte) % charset.count])
            }
        }
        return result
    }
}
