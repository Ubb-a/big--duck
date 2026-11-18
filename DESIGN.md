---
version: alpha
name: BIG DUCK
description: Personal end-to-end encrypted Telegram cloud vault built around archival precision and the bold Duck Amber & Sky Cobalt identity of BIG DUCK.
colors:
  ground: "#F4F5F7"
  surface: "#FFFFFF"
  surfaceAlt: "#E9ECF1"
  rule: "#D3D9E3"
  ink: "#0B1220"
  muted: "#525C6E"
  signal: "#FFAE00"
  signalInk: "#0B1220"
  cobalt: "#005FE0"
  danger: "#D93B00"
darkColors:
  ground: "#0A0F18"
  surface: "#121926"
  surfaceAlt: "#1B2436"
  rule: "#253045"
  ink: "#F2F5FA"
  muted: "#96A2B8"
  signal: "#FFC400"
  signalInk: "#0A0F18"
  cobalt: "#4DA3FF"
  danger: "#FF6B4A"
typography:
  display:
    fontFamily: IBMPlexSans
    arabicFamily: IBMPlexSansArabic
    fontSize: 26
    fontWeight: 700
    letterSpacing: -0.6
  body:
    fontFamily: IBMPlexSans
    arabicFamily: IBMPlexSansArabic
    fontSize: 15
    lineHeight: 1.4
  mono:
    fontFamily: IBMPlexMono
    fontSize: 12
rounded:
  xs: 6
  sm: 10
  md: 14
  pill: 999
spacing:
  xs: 4
  sm: 8
  md: 16
  lg: 24
components:
  button-primary:
    backgroundColor: "{colors.signal}"
    textColor: "{colors.signalInk}"
    rounded: "{rounded.sm}"
    padding: "10px 14px"
---

## Overview

BIG DUCK turns a personal Telegram account into a private, locally AES-256-GCM encrypted file vault. Its visual language pairs the bold yellow duck and sky-blue horizon of the app icon (`assets/icon.png`) with the disciplined legibility of an archival shipping manifest: matte surfaces separated by crisp 1px hairlines, tabular file metrics aligned to a clean column, and zero decorative blur or ambient glow.

## Colors

- **Ground (`#F4F5F7` light / `#0A0F18` dark):** Matte archival stone in daylight; deep vault navy in dark mode.
- **Surface (`#FFFFFF` light / `#121926` dark):** Flat ledger containers and bottom sheets with 1px `rule` hairlines (`#D3D9E3` / `#253045`).
- **Ink (`#0B1220` light / `#F2F5FA` dark):** >14:1 contrast against ground and surface.
- **Muted (`#525C6E` light / `#96A2B8` dark):** >=6.0:1 contrast (exceeds WCAG AA 4.5:1) for secondary timestamps and byte totals.
- **Signal (`#FFAE00` light / `#FFC400` dark):** Derived from the BIG DUCK mascot; reserved strictly for the primary Upload CTA, the vault seal, and active upload indicators, paired with `#0B1220` ink (>9:1 contrast).
- **Cobalt (`#005FE0` light / `#4DA3FF` dark):** Derived from the icon sky; used for folders, active navigation selection, and secondary links.
- **Danger (`#D93B00` light / `#FF6B4A` dark):** Derived from the duck beak; used for destructive actions and failure states.

## Typography

- **Faces:** `IBMPlexSans` (weights 400, 600, 700) for Latin copy and `IBMPlexSansArabic` (weights 400, 600, 700) for Arabic copy, bundled directly in `assets/fonts/`. `IBMPlexMono` is used strictly for cryptographic SHA-256 checksums.
- **Numeric discipline:** File sizes, timestamps, and transfer percentages use `FontFeature.tabularFigures()` so columns line up cleanly without `·` middle-dot separators.
- **Casing:** Sentence case for interface labels and buttons; never reflexive ALL-CAPS eyebrows.

## Layout

- **Structure:** Full-width flat masthead bar (`VaultMasthead`) integrated with a signature `3px` Proportional Manifest Tape, recessed search field, baseline-indexed filter strip (active `2px` underline bar on a `1px` rule instead of pill boxes), and unified hairline ledgers grouped by generous `24px` section rhythm instead of stacked bordered cards (`K2`).
- **Spacing rhythm:** Tight `1px` divided rows inside unified ledgers (`12px` vertical padding), `24px` vertical separation between typographic sections.

## Elevation & Depth

- Surfaces stay flat by default, defined by `1px` `rule` borders and clean tonal contrast between `ground` and `surface`.
- Only floating chrome (the docked bottom bar, active toast banner, and bottom sheets) elevates above content with a crisp border and tight surface shadow — no pervasive `BackdropFilter` blur or ambient radial orbs.

## Shapes

- **6px (`xs`):** Compact format tags (`PDF`, `JPG`, `ZIP`) and inline checksum boxes.
- **10px (`sm`):** Inputs, primary buttons, and segmented controls.
- **14px (`md`):** Unified ledger containers (one per logical section, never box-in-box).
- **20px–24px:** Bottom sheets and floating dock container.

## Components

- **VaultDock:** Single flat-elevated bottom dock with a crisp `2px` Signal/Cobalt indicator bar and zero bounce easing. Respects `MediaQuery.disableAnimationsOf(context)`.
- **VaultSurface:** Clean container with `1px` hairline border, varied radius by role, and zero nested box-within-box clutter.
- **VaultProportionalTape:** Signature `3px` multi-segment storage tape (`Signal` images, `Danger` PDFs, `Cobalt` video/audio, `Ink` other) anchoring the vault masthead and settings storage ledger.
- **ManifestRow:** Folder rows marked by a crisp `3px` Cobalt leading index edge; file rows showing a compact format tag, name, folder/timestamp subtitle, and trailing tabular byte size + AES seal (never joined with `·` or `—`).

## Do's and Don'ts

- Do reuse `AppPalette`, `VaultText`, `VaultSurface`, `VaultSectionHeader`, `VaultProportionalTape`, and `FloatingTabBar` on every screen verbatim.
- Do respect `MediaQuery.disableAnimationsOf(context)` on all transitions.
- Don't change: `IBMPlexSans` / `IBMPlexSansArabic`, Duck Amber (`#FFAE00` / `#FFC400`), Sky Cobalt (`#005FE0` / `#4DA3FF`), or the `BIG DUCK` icon.
- Don't use: stacked card walls (`K2`), tinted icon-in-rounded-square badges (`K6`), `WORD — fragment` status strings (`SD4w`), glassmorphism on static cards (`K3`), ambient radial glow orbs (`M3`), `·` middle-dot joins (`SD4d`), bounce easing (`Curves.easeOutBack`, `M4`), emerald fallback (`SD8`), or decorative `01/02/03` (`SD6`).
