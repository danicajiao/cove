//
//  ProfileHeaderView.swift
//  Cove
//
//  Created by Daniel Cajiao on 3/15/26.
//

import SwiftUI

struct ProfileHeaderView: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Circle()
                .fill(Color.Colors.Fills.secondary)
                .frame(width: 140, height: 140)
                .overlay {
                    if let url = viewModel.photoURL {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipShape(Circle())
                        } placeholder: {
                            initialsView
                        }
                    } else {
                        initialsView
                    }
                }

            VStack(spacing: Spacing.xs) {
                Text(viewModel.displayName)
                    .font(Font.custom("Gazpacho-Black", size: 24))
                    .foregroundStyle(Color.Colors.Fills.primary)

                Text(viewModel.username)
                    .font(Font.custom("Lato-SemiBold", size: 16))
                    .foregroundStyle(Color.Colors.Fills.primary)

                if !viewModel.memberSinceText.isEmpty {
                    Text(viewModel.memberSinceText)
                        .font(Font.custom("Lato-Regular", size: 14))
                        .foregroundStyle(Color.Colors.Fills.tertiary)
                }
            }
            .padding(.horizontal, Spacing.xl)
        }
        .frame(maxWidth: .infinity)
//        .padding(.vertical, 20)
    }

    private var initialsView: some View {
        Text(viewModel.initials)
            .font(Font.custom("Gazpacho-Black", size: 30))
            .foregroundStyle(Color.Colors.Fills.primary)
    }
}

struct ProfileHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileHeaderView(viewModel: ProfileViewModel())
            .padding(.horizontal, Spacing.xl)
            .background(Color.Colors.Backgrounds.primary)
    }
}
