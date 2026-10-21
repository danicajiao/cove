//
//  InterestOnboardingView.swift
//  Cove
//

import SwiftUI

struct InterestOnboardingView: View {
    @StateObject private var viewModel: InterestOnboardingViewModel
    @Environment(\.displayScale) private var displayScale

    init(appState: AppState) {
        _viewModel = StateObject(wrappedValue: InterestOnboardingViewModel(appState: appState))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            contentSection
            bottomSection
        }
        .background(Color.Colors.Backgrounds.primary.ignoresSafeArea(.all))
        .task { await viewModel.fetchCategories() }
    }

    private var headerSection: some View {
        VStack(spacing: Spacing.xl) {
            Text("Cove.")
                .font(.custom("Gazpacho-Heavy", size: 40))
                .foregroundStyle(Color.Colors.Text.primary)

            SpectrumDivider()

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("What are you into?")
                    .font(.custom("Gazpacho-Black", size: 28))
                    .foregroundStyle(Color.Colors.Text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Pick categories that match your style. We'll use them to personalize your home feed.")
                    .font(.custom("Lato-Regular", size: 14))
                    .foregroundStyle(Color.Colors.Text.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.lg)
    }

    @ViewBuilder
    private var contentSection: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView()
            Spacer()
        } else if viewModel.groups.isEmpty {
            Spacer()
            Text("Couldn't load categories.")
                .font(.custom("Lato-Regular", size: 14))
                .foregroundStyle(Color.Colors.Text.tertiary)
            Button("Try again") {
                Task { await viewModel.fetchCategories() }
            }
            .font(.custom("Lato-Bold", size: 14))
            .foregroundStyle(Color.Colors.Brand.accent)
            Spacer()
        } else {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: Spacing.lg) {
                        ForEach(viewModel.groups) { group in
                            InterestGroupSection(
                                group: group,
                                image: viewModel.groupImages[group.id],
                                isLoadingImage: viewModel.isLoadingImage(for: group),
                                isSelected: viewModel.selectedGroupIDs.contains(group.id),
                                selectedOptionIDs: viewModel.selectedOptionIDs,
                                onToggleGroup: { viewModel.toggleGroup(id: group.id) },
                                onToggleOption: { viewModel.toggleOption(id: $0) }
                            )
                            .id(group.id)
                        }
                    }
                    // The stack's width before padding is the card width.
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                        let cardSize = CGSize(width: width, height: InterestCategoryCard.height)
                        Task { await viewModel.cardSizeDidChange(cardSize, displayScale: displayScale) }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.md)
                }
                .onChange(of: viewModel.selectedGroupIDs) { oldIDs, newIDs in
                    guard let expandedID = newIDs.subtracting(oldIDs).first else { return }
                    scrollSectionIntoView(expandedID, proxy: proxy)
                }
            }
        }
    }

    /// Scrolls the minimum distance needed to show a newly expanded section, card
    /// and pills, in full. A section that's already fully visible doesn't move.
    private func scrollSectionIntoView(_ id: String, proxy: ScrollViewProxy) {
        Task { @MainActor in
            // Let the pill grid lay out first so the section has its expanded height.
            try? await Task.sleep(for: .milliseconds(50))
            withAnimation(.easeInOut(duration: 0.3)) {
                // No anchor: scroll only as far as needed to make the view fully visible.
                proxy.scrollTo(id)
            }
        }
    }

    private var bottomSection: some View {
        VStack(spacing: Spacing.md) {
            if let error = viewModel.serverError {
                Text(error)
                    .font(.custom("Lato-Regular", size: 12))
                    .foregroundStyle(Color.Colors.Support.Error.fg)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Button {
                Task { await viewModel.submit() }
            } label: {
                if viewModel.isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(PrimaryButton())
            .disabled(!viewModel.canSubmit)

            Button {
                Task { await viewModel.skip() }
            } label: {
                Text("Skip for now")
                    .font(.custom("Lato-Regular", size: 14))
                    .foregroundStyle(Color.Colors.Text.tertiary)
            }

            Text("Don't worry, you can change this later.")
                .font(.custom("Lato-Regular", size: 12))
                .foregroundStyle(Color.Colors.Text.quaternary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xl)
    }
}

// MARK: - InterestGroupSection

/// A level 1 card that expands into its level 2 pills while selected.
private struct InterestGroupSection: View {
    let group: InterestGroup
    let image: UIImage?
    var isLoadingImage: Bool = false
    let isSelected: Bool
    let selectedOptionIDs: Set<String>
    let onToggleGroup: () -> Void
    let onToggleOption: (String) -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            InterestCategoryCard(
                name: group.name,
                image: image,
                isLoadingImage: isLoadingImage,
                isSelected: isSelected
            ) {
                withAnimation(.easeInOut(duration: 0.2)) { onToggleGroup() }
            }

            if isSelected, !group.options.isEmpty {
                PillGrid(
                    options: group.options,
                    selectedIDs: selectedOptionIDs,
                    selectedFill: group.pillColor,
                    onTap: onToggleOption
                )
                // Pills animate themselves in; the grid itself only fades out on collapse.
                .transition(.asymmetric(insertion: .identity, removal: .opacity))
            }
        }
    }
}

// MARK: - PillGrid

private struct PillGrid: View {
    let options: [InterestOption]
    let selectedIDs: Set<String>
    let selectedFill: Color
    let onTap: (String) -> Void

    /// Flips on appear so each pill rises into place, staggered by its index.
    @State private var hasAppeared = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.sm), count: 3)
    private let staggerDelay = 0.03
    private let riseDistance: CGFloat = 12

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.sm) {
            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                CategoryPill(
                    name: option.name,
                    isSelected: selectedIDs.contains(option.id),
                    selectedFill: selectedFill
                )
                .onTapGesture { onTap(option.id) }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : riseDistance)
                .animation(
                    .easeOut(duration: 0.25).delay(Double(index) * staggerDelay),
                    value: hasAppeared
                )
            }
        }
        .onAppear { hasAppeared = true }
    }
}

// MARK: - CategoryPill

private struct CategoryPill: View {
    let name: String
    let isSelected: Bool
    let selectedFill: Color

    var body: some View {
        // Text.primary on every fill: white fails WCAG contrast on all six brand colors.
        Text(name)
            .font(.custom("Lato-Regular", size: 14))
            .foregroundStyle(Color.Colors.Text.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(isSelected ? selectedFill : Color.Colors.Fills.quinary)
            .clipShape(Capsule())
            .overlay {
                if !isSelected {
                    Capsule().stroke(Color.Colors.Strokes.primary.opacity(0.3), lineWidth: 1)
                }
            }
            .contentShape(Capsule())
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    InterestOnboardingView(appState: AppState())
}

#Preview("Collapsed and expanded") {
    let food = InterestGroup(
        id: "food", name: "Food", path: "food", wideImageKey: nil,
        options: ["Baked Goods", "Beverages", "Coffee", "Condiments", "Confections", "Dairy", "Tea"]
            .map { InterestOption(id: $0, name: $0) },
        pillColor: LevelOneCategories.color(for: "food")
    )
    let apparel = InterestGroup(
        id: "apparel", name: "Apparel", path: "apparel", wideImageKey: nil,
        options: [], pillColor: LevelOneCategories.color(for: "apparel")
    )
    let foodImage = Bundle.main.path(forResource: "category-preview-food", ofType: "jpg").flatMap(UIImage.init(contentsOfFile:))

    ScrollView {
        VStack(spacing: Spacing.lg) {
            InterestGroupSection(
                group: food, image: foodImage, isSelected: true,
                selectedOptionIDs: ["Baked Goods", "Coffee"],
                onToggleGroup: {}, onToggleOption: { _ in }
            )
            InterestGroupSection(
                group: apparel, image: nil, isSelected: false,
                selectedOptionIDs: [], onToggleGroup: {}, onToggleOption: { _ in }
            )
        }
        .padding(.horizontal, Spacing.xl)
    }
    .background(Color.Colors.Backgrounds.primary)
}
