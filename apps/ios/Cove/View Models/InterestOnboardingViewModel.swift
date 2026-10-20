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
    @Published var groupImageURLs: [String: URL] = [:]
    @Published var isLoading: Bool = false
    @Published var isSubmitting: Bool = false
    @Published var serverError: String?

    /// Wide card images are requested at the widest card (400pt Pro Max at 3×)
    /// by its fixed 90pt height; imgproxy crops, and the card fills.
    private let imageWidth = 1200
    private let imageHeight = 270

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
            await prefetchImages(for: groups)
        } catch {
            print("❌ fetchCategories failed: \(error)")
        }
        isLoading = false
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

    private func prefetchImages(for groups: [InterestGroup]) async {
        await withTaskGroup(of: (String, URL?).self) { taskGroup in
            for group in groups {
                guard let key = group.wideImageKey else { continue }
                taskGroup.addTask {
                    let url = try? await self.imageRepository.imageURL(
                        for: key, width: self.imageWidth, height: self.imageHeight
                    )
                    return (group.id, url)
                }
            }
            for await (id, url) in taskGroup {
                if let url {
                    groupImageURLs[id] = url
                }
            }
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
