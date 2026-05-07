# App Architecture

This document covers the Cove iOS app's architecture — how it's structured, how data flows, and how key systems work.

## Overview

Cove uses **MVVM (Model-View-ViewModel)** with SwiftUI. State is managed through a combination of `@StateObject`, `@EnvironmentObject`, and `@Published` properties. Firebase is the sole backend — Firestore for data, Firebase Auth for authentication, and Cloud Storage for images.

---

## Project Structure

```
Cove/
├── Supporting Files/     # App entry point (CoveApp.swift), Info.plist
├── Models/               # Data models and global state (AppState, Bag, Product types)
│                         #   Also defines Path, AuthState, AuthMethod enums (in AppState.swift)
├── View Models/          # Business logic and Firestore access
├── Views/                # SwiftUI views organized by feature
│   ├── Profile/          # ProfileHeaderView, StatsRowView, ProfileRowView
│   └── ...               # HomeView, BagView, ProductDetailView, auth views
├── Components/           # Reusable UI components (ProductCardView, LikeButton, etc.)
├── Styles/               # Custom button styles and shadow modifiers
├── Enums/                # ProductTypes
├── Constants/            # Design token constants (Spacing.swift, Radius.swift)
└── Resources/            # Assets, fonts (Gazpacho, Lato), Rive animations
```

---

## Authentication & Navigation

### Auth-Driven Routing

`CoveApp` is the root of the app. It reads `AppState.authState` to decide which UI to show:

```
CoveApp
├── authState == .loggedIn  →  MainView (tab bar)
└── authState == .loggedOut →  NavigationStack (auth flow)
    ├── network available   →  WelcomeView
    └── no network          →  SplashView
```

`AppState` holds `@Published var authState: AuthState` and `@Published var path: [Path]`. When a user successfully signs in, `authState` flips to `.loggedIn`, which triggers CoveApp to rebuild and show MainView. The navigation path is cleared automatically.

### Supported Auth Methods

| Method | Provider |
|--------|----------|
| Email/Password | Firebase Auth |
| Google | GoogleSignIn SDK → Firebase Auth |
| Facebook | FBSDKLoginKit → Firebase Auth |
| Apple | Planned, not yet implemented |

### Navigation Path Enum

```swift
enum Path: Hashable {
    case welcome
    case login
    case signup
    case main
    case home
    case product(id: String)   // Product detail navigation within tabs
}
```

---

## Tab Structure

`MainView` hosts a `TabView` with 5 tabs. Each tab is wrapped in a `TabNavigationStack` to support in-tab navigation (e.g., tapping a product from the Home tab pushes `ProductDetailView` without leaving the tab).

| Tab | View | Status |
|-----|------|--------|
| Home | `HomeView` | Implemented |
| Browse | Placeholder | Not implemented |
| Bag | `BagView` | Implemented |
| Favorites | `FavoritesView` | Implemented |
| Profile | `ProfileView` | Implemented |

---

## ViewModels

### HomeViewModel
Serves `HomeView`. Fetches all products and brands from Firestore on first load. After fetching products, it queries the current user's favorites subcollection and marks matching products with `isFavorite = true`. Results are cached in-memory — `fetchProducts()` early-returns if `products` is already populated.

### ProductDetailViewModel
Serves `ProductDetailView`. Initialized with a `productId`, it runs three async fetches on init: the product itself, its type-specific details, and up to 5 similar products (same `categoryId`). Also manages `detailSelection` — the currently active tab (Description / Origin / Tracklist / Specifications / About), which varies by product type.

### BagViewModel
Serves `BagView`. Fetches similar product recommendations based on the categories of items currently in the bag. Caches the last queried category list to avoid redundant Firestore calls.

### FavoritesViewModel
Serves `FavoritesView`. Fetches the current user's favorited products from Firestore in batches of 30 (Firestore `in` query limit). Reads the `users/{uid}/favorites` subcollection to get product IDs, then fetches the corresponding product documents and decodes them by `categoryId` into the correct concrete type. Publishes `favorites: [any Product]` and `isLoading`.

### ProfileViewModel
Serves `ProfileView`. Lightweight — all data is derived from `Auth.auth().currentUser` (display name, initials, photo URL, member since date). No Firestore reads, no local state mutations.

---

## Global State

### AppState
Injected at the root via `.environmentObject`. Owns:
- `authState` — drives the root UI split between auth flow and main app
- `path` — the NavigationStack path for the auth flow
- All sign-in/sign-out methods for every auth provider

### Bag
Injected into `MainView` and its children via `.environmentObject`. Owns:
- `bagProducts: [BagProduct]` — items in the cart with quantities
- `total: Int` — running total price
- `categories: [String]` — categoryIds of items in the bag, used to fetch recommendations

### FavoritesStore
Injected at the root (`CoveApp`) via `.environmentObject` and available throughout the entire app. Owns:
- `favoriteIds: Set<String>` — the set of favorited product IDs for the current user
- `isTogglingFavorite: Bool` — prevents concurrent toggle operations
- Listens to `Auth.auth().addStateDidChangeListener` to load favorites on sign-in and clear them on sign-out
- `toggle(_:categoryId:)` — optimistically updates `favoriteIds` locally, then syncs to Firestore
- Used by `LikeButton` to read and mutate favorite state across all views

---

## Product Type System

Products in Firestore share a common `categoryId` field. The app uses this to decode into the correct Swift type at runtime.

### Type Mapping

```swift
enum ProductTypes: String {
    case coffee  = "8JbKssVf2zw8ryq1pace"
    case music   = "JzzwWDRpp2B5zG4TNdWx"
    case apparel = "s97tOnvbfrNtoe2VaNRQ"
}
```

### Protocol Hierarchy

```
Product (protocol)
├── CoffeeProduct   → info: CoffeeInfo  { name, roastery }
├── MusicProduct    → info: MusicInfo   { artist, album }
└── ApparelProduct  → info: ApparelInfo { brand, name }

ProductDetails (protocol)
├── CoffeeProductDetails   → description, about, origin: [OriginInfo]
├── MusicProductDetails    → description, about, tracklist: [Track]
└── ApparelProductDetails  → description, about, specifications: [Specification]
```

### Decoding Strategy

ViewModels read the raw `categoryId` from each Firestore document before decoding:

```swift
let categoryId = document["categoryId"] as? String
if categoryId == ProductTypes.coffee.rawValue {
    let product = try document.data(as: CoffeeProduct.self)
} else if categoryId == ProductTypes.music.rawValue {
    let product = try document.data(as: MusicProduct.self)
} // ...
```

`ProductDetailView` and `ProductCardView` then type-cast `any Product` back to the concrete type to access type-specific fields (e.g., `(product as? CoffeeProduct)?.info.roastery`).

---

## Firebase Data Model

### Collections

| Collection | Purpose |
|------------|---------|
| `products` | All product listings |
| `product_details` | Type-specific product details (keyed by `productDetailsId`) |
| `brands` | Brand/store info shown in the Home "Stores" section |
| `users/{uid}/favorites` | Per-user favorited product IDs |

### Product Document Structure

```
products/{productId}
  ├── categoryId: String          // Maps to ProductTypes enum
  ├── defaultPrice: Float
  ├── defaultImageURL: String     // Firebase Storage URL
  ├── productDetailsId: String    // Foreign key to product_details
  ├── isFavorite: Bool?           // Set client-side after favorites query
  ├── createdAt: Timestamp
  └── info: { ... }              // Type-specific nested object
```

### Image Loading

Product images are stored in Firebase Storage. `ProductCardView` fetches them asynchronously via `Storage.storage().reference(forURL:).getData(maxSize:)`, storing the result in a `@State var uiImage`. No caching library is used — images re-fetch on each view appearance.

---

## Key Data Flows

### App Launch → Products Displayed

```
1. CoveApp checks authState → .loggedIn
2. MainView shown with HomeView in first tab
3. HomeView.onAppear → viewModel.fetchProducts()
4. Firestore query: collection("products").getDocuments()
5. Each doc decoded by categoryId → CoffeeProduct / MusicProduct / ApparelProduct
6. Favorites query: users/{uid}/favorites where productId in fetchedIds
7. Matching products marked isFavorite = true
8. products array published → HomeView renders ProductCardView grid
```

### Product Tap → Detail View

```
1. User taps ProductCardView
2. NavigationLink(value: Path.product(id:)) fires
3. TabNavigationStack routes to ProductDetailView(productId:)
4. ViewModel init → async fetch: product + details + similar products
5. UI renders with type-specific tabs
```

### Add to Bag

```
1. User taps "Add to Bag" in ProductDetailView
2. Check if product already in bag.bagProducts
   ├── Yes → increment existing BagProduct.quantity
   └── No  → append new BagProduct
3. bag.categories updated with product's categoryId
4. BagView onChange → BagViewModel.fetchSimilarProducts(categories:)
```

### Sign Out

```
1. User taps "Log Out" in ProfileView → confirmation dialog
2. appState.logOut() called
3. Provider-specific cleanup (GIDSignIn.signOut() / LoginManager().logOut())
4. Firebase Auth signOut()
5. authState = .loggedOut → CoveApp rebuilds → WelcomeView shown
```

---

## Not Yet Implemented

| Feature | Location |
|---------|----------|
| Browse tab | Placeholder `Text` in MainView |
| Search | TextField in HomeView is present but not connected |
| Checkout | "Proceed to checkout" button in BagView has no action |
| Reviews | NavigationLink exists in ProductDetailView but no destination |
| Profile editing | ProfileRowView items are not wired up |
| Notifications | Bell icon in HomeView has no action |
| Apple Sign-In | Auth method referenced but not implemented |
