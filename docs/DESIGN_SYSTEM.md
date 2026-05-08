# Design System

This document is the authoritative reference for Cove's design system. It maps Figma design tokens and components to their Swift equivalents so that all UI work — by humans or agents — stays consistent.

**Figma file:** [Cove](https://www.figma.com/design/PQWPBacMcEeXzDyi7aalZY/Cove)

---

## Figma File Structure

| Page | Purpose |
|---|---|
| Cover | Title page |
| Styles | Raw swatches and style references |
| Components | All component definitions (source of truth for UI components) |
| Views | Full screen mockups using component instances |
| Color | Color token reference sheet |
| Typography | Type scale reference sheet |
| Spacing & Radius | Spacing and corner radius token reference sheet |
| Playground | Experimental / scratch area |

### Variable Collections

| Collection | Purpose |
|---|---|
| `Primitives` | Raw values — hex colors, not used directly in UI |
| `Color` | Semantic color tokens aliased from Primitives |
| `Spacing` | 4pt-grid spacing tokens |
| `Radius` | Corner radius tokens |

---

## Color System

Colors live in two places that must stay in sync:

- **Figma:** `Color` variable collection (semantic tokens aliased from `Primitives`)
- **Swift:** Asset catalog at `apps/ios/Cove/Resources/Assets.xcassets/Colors/`

The asset catalog folder structure maps directly to Swift: `Colors/Fills/primary.colorset` → `Color.Colors.Fills.primary`.

> **Rule:** Always use semantic tokens. Never hardcode hex values or use `Color(.black)` / `Color(.white)`.

> **Dark mode note:** All color tokens have light and dark variants in the asset catalog. Dark mode values are currently placeholders — they will be updated once the dark palette is defined in Figma. The semantic token structure means no Swift code changes will be needed when that happens.

> **Open question — `Fills.inverse` vs `Fills.surface`:** `Fills.inverse` currently serves two roles: (1) the elevated component surface on a light background (input fields, cards), and (2) white foreground elements on dark fills (white text/icons on a brown button). These are semantically different and may need to be split into separate tokens (`Fills.surface` and `Fills.inverse`) when the dark palette is designed — in dark mode they would require different values. Defer this decision until dark mode is defined in Figma, as the right split will be obvious then.

### Fills

Surface colors for UI components (buttons, cards, chips, sheets, overlays) that sit on top of a background. Use `Fills.*` when coloring the surface of an element, not the canvas behind it.

| Figma variable | Swift | Value / Meaning |
|---|---|---|
| `fills/primary` | `Color.Colors.Fills.primary` | `#52331F` — dark brown, primary surface |
| `fills/secondary` | `Color.Colors.Fills.secondary` | `#2B2627` — charcoal, secondary surface |
| `fills/inverse` | `Color.Colors.Fills.inverse` | `#FFFFFF` — white, on-dark surfaces |
| `fills/tertiary` | `Color.Colors.Fills.tertiary` | Charcoal 60% opacity |
| `fills/quaternary` | `Color.Colors.Fills.quaternary` | Charcoal 30% opacity |
| `fills/quinary` | `Color.Colors.Fills.quinary` | Charcoal 10% opacity |

### Text

Used for foreground text colors.

| Figma variable | Swift | Value / Meaning |
|---|---|---|
| `text/primary` | `Color.Colors.Text.primary` | `#52331F` — dark brown, primary text |
| `text/secondary` | `Color.Colors.Text.secondary` | `#2B2627` — charcoal text |
| `text/inverse` | `Color.Colors.Text.inverse` | `#FFFFFF` — white text on dark backgrounds |
| `text/tertiary` | `Color.Colors.Text.tertiary` | Charcoal 60% opacity |
| `text/quaternary` | `Color.Colors.Text.quaternary` | Charcoal 30% opacity |
| `text/quinary` | `Color.Colors.Text.quinary` | Charcoal 10% opacity |

### Strokes

Used for borders and dividers.

| Figma variable | Swift | Value / Meaning |
|---|---|---|
| `strokes/primary` | `Color.Colors.Strokes.primary` | `#52331F` — dark brown border |
| `strokes/secondary` | `Color.Colors.Strokes.secondary` | `#2B2627` — charcoal border |

### Brand

Brand palette colors used for identity, accents, and category expression.

| Figma variable | Swift | Value / Meaning |
|---|---|---|
| `brand/primary` | `Color.Colors.Brand.primary` | `#52331F` — dark brown |
| `brand/secondary` | `Color.Colors.Brand.secondary` | `#FFFFFF` — white |
| `brand/accent` | `Color.Colors.Brand.accent` | `#E29547` — amber, interactive accent |
| `brand/coral` | `Color.Colors.Brand.coral` | `#FF8181` — coral |
| `brand/amber` | `Color.Colors.Brand.amber` | `#FFB557` — amber |
| `brand/yellow` | `Color.Colors.Brand.yellow` | `#FFFAA0` — yellow |
| `brand/sage` | `Color.Colors.Brand.sage` | `#8BA96A` — sage green |
| `brand/blue` | `Color.Colors.Brand.blue` | `#6CA8D0` — blue |
| `brand/violet` | `Color.Colors.Brand.violet` | `#D3C6FF` — violet |

### Backgrounds

Page-level canvas colors. Use for the outermost `.background()` of a screen or major section — the surface everything else sits on. If you're coloring a component rather than the canvas behind it, use `Fills.*` instead.

| Figma variable | Swift | Value / Meaning |
|---|---|---|
| `backgrounds/primary` | `Color.Colors.Backgrounds.primary` | Off-white warm background |
| `backgrounds/secondary` | `Color.Colors.Backgrounds.secondary` | `#FFFFFF` — white, used as a secondary canvas surface |

### Category

Used to tint the coffee category tiles.

| Figma variable | Swift | Value / Meaning |
|---|---|---|
| `category/fruity` | `Color.Colors.Category.fruity` | Warm pink-red |
| `category/choco` | `Color.Colors.Category.choco` | Warm brown |
| `category/citrus` | `Color.Colors.Category.citrus` | Golden yellow |
| `category/earthy` | `Color.Colors.Category.earthy` | Muted green-grey |
| `category/floral` | `Color.Colors.Category.floral` | Soft lavender |

### Feedback

| Figma variable | Swift | Value / Meaning |
|---|---|---|
| `feedback/star` | `Color.Colors.Feedback.star` | `#FFC107` — star rating yellow |

### Support

Used for alerts, banners, and status indicators. Each state has three roles:

- **`fill`** — the solid indicator color itself (icon fill, badge background, border highlight)
- **`fg`** — foreground text or icon color used *on top of* the surface, darker for contrast
- **`surface`** — a light tinted background for the alert container or banner

> **Naming note:** The Figma variable is named `support/*/default` but Swift's `default` is a reserved keyword. The Swift colorset uses `fill` instead.

| Figma variable | Swift | Value |
|---|---|---|
| `support/success/default` | `Color.Colors.Support.Success.fill` | `#8BA96A` — sage |
| `support/success/fg` | `Color.Colors.Support.Success.fg` | `#4A6B35` — dark sage |
| `support/success/surface` | `Color.Colors.Support.Success.surface` | `#EEF5E8` — light sage |
| `support/warning/default` | `Color.Colors.Support.Warning.fill` | `#FFB557` — amber |
| `support/warning/fg` | `Color.Colors.Support.Warning.fg` | `#8C5E00` — dark amber |
| `support/warning/surface` | `Color.Colors.Support.Warning.surface` | `#FFF4E0` — light amber |
| `support/error/default` | `Color.Colors.Support.Error.fill` | `#FF8181` — coral |
| `support/error/fg` | `Color.Colors.Support.Error.fg` | `#B83232` — dark coral |
| `support/error/surface` | `Color.Colors.Support.Error.surface` | `#FFF0F0` — light coral |

### Shadow color

| Swift | Value |
|---|---|
| `Color.Colors.shadow` | `#1F1F1F` at 10% opacity |

---

## Typography

Font files live in `apps/ios/Cove/Resources/`. Always use `Font.custom()` — never use system fonts for content text.

### Type Scale

| Figma style | Font | Size | Swift usage |
|---|---|---|---|
| Gazpacho/Display | Gazpacho-Black | 34pt | `Font.custom("Gazpacho-Black", size: 34)` |
| Gazpacho/Heading XL | Gazpacho-Black | 28pt | `Font.custom("Gazpacho-Black", size: 28)` |
| Gazpacho/Heading LG | Gazpacho-Black | 22pt | `Font.custom("Gazpacho-Black", size: 22)` |
| Gazpacho/Heading MD | Gazpacho-Black | 18pt | `Font.custom("Gazpacho-Black", size: 18)` |
| Gazpacho/Heading SM | Gazpacho-Black | 15pt | `Font.custom("Gazpacho-Black", size: 15)` |
| Lato/Body LG | Lato-Bold | 16pt | `Font.custom("Lato-Bold", size: 16)` |
| Lato/Body MD | Lato-Regular | 14pt | `Font.custom("Lato-Regular", size: 14)` |
| Lato/Body SM | Lato-Regular | 12pt | `Font.custom("Lato-Regular", size: 12)` |
| Lato/Caption | Lato-Regular | 10pt | `Font.custom("Lato-Regular", size: 10)` |

### Rules

- **Headings / display text:** Gazpacho-Black
- **Body / UI text:** Lato-Regular (default) or Lato-Bold (emphasis)
- **Poppins is removed** — do not use `Poppins-Regular` or `Poppins-SemiBold` anywhere

---

## Spacing

Based on a **4pt grid**. Defined in `apps/ios/Cove/Constants/Spacing.swift` — use the named constants instead of raw values.

| Figma token | Swift constant | Value | Primary use |
|---|---|---|---|
| `spacing/xs` | `Spacing.xs` | 4pt | Icon/label gap, tight component internals |
| `spacing/sm` | `Spacing.sm` | 8pt | Label → input gap, icon margins, badge padding |
| `spacing/md` | `Spacing.md` | 12pt | Between components in a group, cell padding |
| `spacing/lg` | `Spacing.lg` | 16pt | Screen edge inset, row vertical padding, card internals |
| `spacing/xl` | `Spacing.xl` | 20pt | Between form fields, button vertical padding |
| `spacing/2xl` | `Spacing.xxl` | 24pt | Card-to-card gap, section breathing room |
| `spacing/3xl` | `Spacing.xxxl` | 32pt | Major section separators, modal padding |
| `spacing/4xl` | `Spacing.xxxxl` | 48pt | Hero spacing, top-of-screen clearance |

```swift
.padding(.horizontal, Spacing.lg)
.padding(.bottom, Spacing.xxl)
VStack(spacing: Spacing.md) { ... }
```

---

## Corner Radius

Based on a **2pt step** at smaller sizes. Defined in `apps/ios/Cove/Constants/Radius.swift` — use the named constants instead of raw values.

| Figma token | Swift constant | Value | Primary use |
|---|---|---|---|
| `radius/none` | `Radius.none` | 0pt | Dividers, full-width elements |
| `radius/xs` | `Radius.xs` | 2pt | Tags, badges, small chips |
| `radius/sm` | `Radius.sm` | 4pt | Input fields, tooltips |
| `radius/md` | `Radius.md` | 8pt | Buttons, list rows, image thumbnails |
| `radius/lg` | `Radius.lg` | 10pt | Cards, sheets, action menus |
| `radius/xl` | `Radius.xl` | 16pt | Large cards, modals, featured banners |
| `radius/full` | `Radius.full` | 9999pt | Pills, avatar chips, toggle tracks |

```swift
.cornerRadius(Radius.md)  // buttons, list rows
.cornerRadius(Radius.lg)  // cards, sheets
```

---

## Shadow

A 5-layer compound shadow defined in `apps/ios/Cove/Styles/CustomShadow.swift`. Apply with the `.customShadow()` modifier.

**Figma:** Effect style `Shadow/Custom`

```swift
SomeView()
    .customShadow()
```

The shadow layers (outermost to innermost):

| Opacity | Radius | Y offset |
|---|---|---|
| 0% | 5 | 16 |
| 1% | 4 | 10 |
| 2% | 3 | 6 |
| 3% | 3 | 3 |
| 4% | 1 | 1 |

---

## Components

All components are defined in the **Components page** of the Figma file. Views should use instances of these components, not detached copies.

| Figma component | Swift file(s) | Notes |
|---|---|---|
| Buttons / Primary | `apps/ios/Cove/Styles/PrimaryButton.swift` | `PrimitiveButtonStyle`, uses `fills/primary` + `fills/inverse` |
| Buttons / Secondary | `apps/ios/Cove/Styles/SecondaryButton.swift` | Outlined style, uses `strokes/primary` |
| Buttons / Banner | `apps/ios/Cove/Components/BannerButton.swift` | Used inside promotional banners |
| Buttons / Social Login | `apps/ios/Cove/Components/` | Google, Facebook, Apple variants |
| Text Field | `apps/ios/Cove/Components/` | Email, password, search, text area variants |
| Section Header | `apps/ios/Cove/Components/` | Title + optional "See all →" in `brand/accent` |
| Divider | `apps/ios/Cove/Components/` | Plain line and "OR" variants |
| Card / Product | `apps/ios/Cove/Components/ProductCardView.swift` | Product image, name, roaster, price |
| Card / Category | `apps/ios/Cove/Components/CoffeeCategoryButton.swift` | Uses `category/*` fill colors |
| Bag Item | `apps/ios/Cove/Components/` | Quantity stepper in `brand/accent`, price in `text/primary` |
| Store Card | `apps/ios/Cove/Components/` | Circular logo + store name |
| Promotional Banner | `apps/ios/Cove/Components/` | Two variants: full-bleed image and compact |
| Hero Art | `apps/ios/Cove/Resources/` | Illustrative identity tiles — fixed colors by design |
| Tiles | `apps/ios/Cove/Resources/` | Decorative loading indicator tiles — fixed colors by design |
| Icons | `apps/ios/Cove/Resources/` | Social auth icons — third-party brand colors, intentionally fixed |

---

## Rules & Anti-Patterns

### Always

- Use `Color.Colors.*` for all colors
- Use `Font.custom("Gazpacho-Black" / "Lato-Bold" / "Lato-Regular", size:)` for all text
- Use `.customShadow()` for card/sheet elevation
- Use spacing values from the 4pt grid
- Use corner radius values from the token scale
- Use component instances from the Figma Components page, not detached copies

### Never

- Hardcode hex values: `Color(hex: "#52331F")` ✗
- Use system fonts for content: `.font(.body)` or `.font(.headline)` ✗
- Use Poppins: `Font.custom("Poppins-Regular", ...)` ✗
- Use pure black or white: `Color.black` / `Color.white` ✗ — use `fills/primary` and `fills/inverse`
- Detach Figma component instances before implementing

---

## Roadmap & Known Gaps

| Area | Status | Notes |
|---|---|---|
| Spacing constants | ✅ Done | `apps/ios/Cove/Constants/Spacing.swift` |
| Radius constants | ✅ Done | `apps/ios/Cove/Constants/Radius.swift` |
| Support colors | ✅ Done | `apps/ios/Cove/Resources/Assets.xcassets/Colors/Support/` |
| Color naming drift | ✅ Done | Asset catalog renamed to match Figma variable names |
| Codebase realignment | ✅ Done | All Views and Components use `Color.Colors.*`, `Spacing.*`, `Radius.*`, and `Lato` fonts |
| `BagView` realignment | ⏳ Pending | Excluded from realignment pass — scheduled for full rework |
