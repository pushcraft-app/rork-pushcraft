import Foundation
import Supabase
import UIKit

/// Downloads battle opponents' photos from the private avatars bucket. Storage
/// rules only allow this while the two players share a battle.
final class AvatarCache {
    static let shared = AvatarCache()

    private var images: [String: UIImage] = [:]

    func image(for path: String) async -> UIImage? {
        if let cached = images[path] { return cached }
        do {
            let data = try await Backend.client.storage.from("avatars").download(path: path)
            guard let image = UIImage(data: data) else { return nil }
            images[path] = image
            return image
        } catch {
            print("[Avatar] Download failed: \(error.localizedDescription)")
            return nil
        }
    }
}
