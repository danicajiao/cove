//
//  ImagePreloader.swift
//  Cove
//

import UIKit

/// Downloads a fixed set of images up front, so a group of cards can be revealed
/// together and cards off-screen in a lazy stack are ready before they scroll in.
///
/// Signs each key through `ImageRepository`, then fetches the imgproxy URL's bytes.
/// A key that fails or takes longer than `timeout` is simply missing from the
/// result, so one slow image can't hold back the rest.
struct ImagePreloader {
    let imageRepository: ImageRepository
    var session: URLSession = .shared
    var timeout: TimeInterval = 8

    /// - Parameters:
    ///   - keys: Garage object keys, keyed by the caller's ID for each image.
    ///   - width: Output width in pixels.
    ///   - height: Output height in pixels.
    /// - Returns: Decoded images keyed by the caller's ID.
    func load(_ keys: [String: String], width: Int, height: Int) async -> [String: UIImage] {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for (id, key) in keys {
                group.addTask {
                    guard let url = try? await imageRepository.imageURL(for: key, width: width, height: height) else {
                        return (id, nil)
                    }
                    let request = URLRequest(url: url, timeoutInterval: timeout)
                    guard let (data, _) = try? await session.data(for: request) else { return (id, nil) }
                    return (id, UIImage(data: data))
                }
            }
            var images: [String: UIImage] = [:]
            for await (id, image) in group {
                if let image {
                    images[id] = image
                }
            }
            return images
        }
    }
}
