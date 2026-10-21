//
//  InterestOnboardingViewModel.swift
//  Cove
//

import SwiftUI

/// A level 1 category card in the interest picker, with its level 2 pills.
struct InterestGroup: Identifiable {
    let id: String
    let name: String
    let path: String
    let wideImageKey: String?
    let options: [InterestOption]
    let pillColor: Color
}

/// A level 2 category pill under an `InterestGroup`.
struct InterestOption: Identifiable {
    let id: String
    let name: String
}

@MainActor
class InterestOnboardingViewModel: ObservableObject {
    @Published var groups: [InterestGroup] = []
    @Published var selectedGroupIDs: Set<String> = []
    @Published var selectedOptionIDs: Set<String> = []
    @Published var groupImages: [String: UIImage] = [:]
    @Published var isLoadingImages: Bool = false
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var serverError: String?

    /// Pixel size the wide images are requested at: the card's on-screen size
    /// times the display scale, reported by the view once it has laid out.
    private var imagePixelSize: (width: Int, height: Int)?

    private let appState: AppState
    private let api: CoveAPIClient
    private let imageRepository: ImageRepository

    init(
        appState: AppState,
        api: CoveAPIClient = .shared,
        imageRepository: ImageRepository = CoveAPIImageRepository()
    ) {
        self.appState = appState
        self.api = api
        self.imageRepository = imageRepository
    }

    var canSubmit: Bool {
        !selectedGroupIDs.isEmpty && !isSubmitting
    }

    /// Every selected level 1 ID plus every selected level 2 ID. A group with no
    /// pills selected saves just the level 1 category, meaning "everything in it".
    var selectedCategoryIDs: [String] {
        Array(selectedGroupIDs.union(selectedOptionIDs))
    }

    func fetchCategories() async {
        isLoading = true
        do {
            let nodes = try await api.categories()
            groups = Self.buildGroups(from: nodes)
        } catch {
            print("❌ fetchCategories failed: \(error)")
        }
        // Show the cards right away; each shimmers until its image arrives.
        isLoading = false
        isLoadingImages = groups.contains { $0.wideImageKey != nil }
        await prefetchImagesIfReady()
    }

    /// Called by the view with the card's laid-out size. Images are requested at
    /// exactly that size in pixels (points × display scale), so each device
    /// downloads only what it shows, at full sharpness.
    func cardSizeDidChange(_ size: CGSize, displayScale: CGFloat) async {
        guard size.width > 0, size.height > 0, imagePixelSize == nil else { return }
        imagePixelSize = (
            width: Int((size.width * displayScale).rounded(.up)),
            height: Int((size.height * displayScale).rounded(.up))
        )
        await prefetchImagesIfReady()
    }

    /// Whether a group's card should shimmer. Every card with an image shimmers
    /// until the whole set has downloaded, then they're revealed together.
    func isLoadingImage(for group: InterestGroup) -> Bool {
        isLoadingImages && group.wideImageKey != nil
    }

    /// Selects a group (expanding its pills), or deselects it, collapsing it and
    /// clearing its selected pills.
    func toggleGroup(id: String) {
        if selectedGroupIDs.contains(id) {
            selectedGroupIDs.remove(id)
            if let group = groups.first(where: { $0.id == id }) {
                selectedOptionIDs.subtract(group.options.map(\.id))
            }
        } else {
            selectedGroupIDs.insert(id)
        }
    }

    func toggleOption(id: String) {
        if selectedOptionIDs.contains(id) {
            selectedOptionIDs.remove(id)
        } else {
            selectedOptionIDs.insert(id)
        }
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        serverError = nil
        do {
            try await api.replaceInterests(categoryIds: selectedCategoryIDs)
            complete()
        } catch {
            print("❌ replaceInterests failed: \(error)")
            serverError = "Something went wrong. Please try again."
            isSubmitting = false
        }
    }

    func skip() async {
        isSubmitting = true
        do {
            try await api.replaceInterests(categoryIds: [])
        } catch {
            print("❌ skip replaceInterests failed: \(error)")
        }
        appState.setAuthState(.loggedIn)
    }

    private func complete() {
        appState.setAuthState(.loggedIn)
    }

    /// Downloads every wide image once both the categories and the card size are
    /// known, then reveals them all at once.
    private func prefetchImagesIfReady() async {
        guard let size = imagePixelSize, !groups.isEmpty, groupImages.isEmpty else { return }
        let keys = groups.reduce(into: [String: String]()) { keys, group in
            keys[group.id] = group.wideImageKey
        }
        isLoadingImages = true
        let images = await ImagePreloader(imageRepository: imageRepository)
            .load(keys, width: size.width, height: size.height)
        withAnimation(.easeOut(duration: 0.25)) {
            groupImages = images
            isLoadingImages = false
        }
    }

    /// One group per level 1 category, in the fixed `LevelOneCategories` order
    /// (unlisted ones after, by name), each with all of its level 2 children.
    static func buildGroups(from nodes: [Components.Schemas.CategoryNode]) -> [InterestGroup] {
        nodes
            .map { root in
                InterestGroup(
                    id: root.id,
                    name: root.name,
                    path: root.path,
                    wideImageKey: root.wide_image_key,
                    options: (root.children ?? []).map { InterestOption(id: $0.id, name: $0.name) },
                    pillColor: LevelOneCategories.color(for: root.path)
                )
            }
            .sorted { lhs, rhs in
                let lhsRank = LevelOneCategories.rank(of: lhs.path) ?? .max
                let rhsRank = LevelOneCategories.rank(of: rhs.path) ?? .max
                return lhsRank == rhsRank ? lhs.name < rhs.name : lhsRank < rhsRank
            }
    }
}
