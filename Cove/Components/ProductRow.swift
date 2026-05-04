//
//  ProductRow.swift
//  Cove
//
//  Created by Daniel Cajiao on 4/17/23.
//

import SwiftUI

struct ProductRow: View {
    @Binding var bagProduct: BagProduct

    var body: some View {
        if let coffeeProduct = bagProduct.product as? CoffeeProduct {
            HStack {
                AsyncImage(url: URL(string: coffeeProduct.defaultImageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background {
                            Color.Colors.Fills.inverse
                        }
                        .cornerRadius(Radius.lg)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 80, height: 80)

//                Spacer()

                VStack(alignment: .leading) {
                    Text(coffeeProduct.info.name)
                        .font(Font.custom("Lato-Regular", size: 12))
                        .foregroundStyle(Color.Colors.Text.primary)
                    Text(coffeeProduct.info.roastery)
                        .font(Font.custom("Lato-Regular", size: 12))
                        .foregroundStyle(Color.Colors.Text.tertiary)

                    Spacer()

                    HStack {
                        Button {
                            if bagProduct.quantity > 1 {
                                bagProduct.quantity -= 1
                            }
                        } label: {
                            Image(systemName: "minus.square")
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        .foregroundStyle(Color.Colors.Brand.accent)
                        .disabled(bagProduct.quantity == 1 ? true : false)

                        Text(String(bagProduct.quantity))
                            .font(Font.custom("Lato-Regular", size: 14))
                            .frame(width: 30, height: 20)

                        Button {
                            if bagProduct.quantity < 15 {
                                bagProduct.quantity += 1
                            }
                        } label: {
                            Image(systemName: "plus.square")
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        .foregroundStyle(Color.Colors.Brand.accent)
                        .disabled(bagProduct.quantity == 15 ? true : false)
                    }
                }

                Spacer()

                VStack(alignment: .trailing) {
//                    Image(systemName: "x.circle")
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .foregroundStyle(.accent)
//                        .frame(width: 20)
                    Spacer()
                    Text("$\(String(Int(coffeeProduct.defaultPrice)))")
                        .font(Font.custom("Lato-Bold", size: 16))
                        .foregroundStyle(Color.Colors.Text.primary)
                }
            }
            .frame(height: 80)
            .padding(Spacing.xl)
        } else if let musicProduct = bagProduct.product as? MusicProduct {
            HStack {
                AsyncImage(url: URL(string: musicProduct.defaultImageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(Radius.lg)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 80, height: 80)

//                Spacer()

                VStack(alignment: .leading) {
                    Text(musicProduct.info.album)
                        .font(Font.custom("Lato-Regular", size: 12))
                        .foregroundStyle(Color.Colors.Text.primary)
                    Text(musicProduct.info.artist)
                        .font(Font.custom("Lato-Regular", size: 12))
                        .foregroundStyle(Color.Colors.Text.tertiary)

                    Spacer()

                    HStack {
                        Button {
                            if bagProduct.quantity > 1 {
                                bagProduct.quantity -= 1
                            }
                        } label: {
                            Image(systemName: "minus.square")
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        .foregroundStyle(Color.Colors.Brand.accent)
                        .disabled(bagProduct.quantity == 1 ? true : false)

                        Text(String(bagProduct.quantity))
                            .font(Font.custom("Lato-Regular", size: 14))
                            .frame(width: 30, height: 20)

                        Button {
                            if bagProduct.quantity < 15 {
                                bagProduct.quantity += 1
                            }
                        } label: {
                            Image(systemName: "plus.square")
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        .foregroundStyle(Color.Colors.Brand.accent)
                        .disabled(bagProduct.quantity == 15 ? true : false)
                    }
                }

                Spacer()

                VStack(alignment: .trailing) {
//                    Image(systemName: "x.circle")
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .foregroundStyle(.accent)
//                        .frame(width: 20)
                    Spacer()
                    Text("$\(String(Int(musicProduct.defaultPrice)))")
                        .font(Font.custom("Lato-Bold", size: 16))
                        .foregroundStyle(Color.Colors.Text.primary)
                }
            }
            .frame(height: 80)
            .padding(Spacing.xl)
        } else if let apparelProduct = bagProduct.product as? ApparelProduct {
            HStack {
                AsyncImage(url: URL(string: apparelProduct.defaultImageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(Radius.lg)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 80, height: 80)

                //                Spacer()

                VStack(alignment: .leading) {
                    Text(apparelProduct.info.name)
                        .font(Font.custom("Lato-Regular", size: 12))
                        .foregroundStyle(Color.Colors.Text.primary)
                    Text(apparelProduct.info.brand)
                        .font(Font.custom("Lato-Regular", size: 12))
                        .foregroundStyle(Color.Colors.Text.tertiary)

                    Spacer()

                    HStack {
                        Button {
                            if bagProduct.quantity > 1 {
                                bagProduct.quantity -= 1
                            }
                        } label: {
                            Image(systemName: "minus.square")
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        .foregroundStyle(Color.Colors.Brand.accent)
                        .disabled(bagProduct.quantity == 1 ? true : false)

                        Text(String(bagProduct.quantity))
                            .font(Font.custom("Lato-Regular", size: 14))
                            .frame(width: 30, height: 20)

                        Button {
                            if bagProduct.quantity < 15 {
                                bagProduct.quantity += 1
                            }
                        } label: {
                            Image(systemName: "plus.square")
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        .foregroundStyle(Color.Colors.Brand.accent)
                        .disabled(bagProduct.quantity == 15 ? true : false)
                    }
                }

                Spacer()

                VStack(alignment: .trailing) {
//                    Image(systemName: "x.circle")
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .foregroundStyle(.accent)
//                        .frame(width: 20)
                    Spacer()
                    Text("$\(String(Int(apparelProduct.defaultPrice)))")
                        .font(Font.custom("Lato-Bold", size: 16))
                        .foregroundStyle(Color.Colors.Text.primary)
                }
            }
            .frame(height: 80)
            .padding(Spacing.xl)
        }
    }
}
