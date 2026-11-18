---
version: 2.0
name: BIG DUCK — Obsidian & Ivory Signal Vault
description: Quiet-luxury zero-knowledge encrypted Telegram cloud storage design system with liquid-glass Obsidian Dark and frosted-glass Ivory Light themes, Arabic RTL primary layout, and English LTR mirror.
colors:
  primary: "#D9D6CF"
  secondary: "#9A9CA6"
  tertiary: "#4ADE80"
  neutral: "#050506"
  destructive: "#F87171"
  warningFloodWait: "#C9B27C"
darkTheme:
  name: Obsidian Luxury
  canvas: "#050506"
  radialGlow: "#14151A"
  cardSolid: "#1A1A1C"
  glassSurface: "rgba(120, 124, 135, 0.14)"
  glassBorder: "rgba(255, 255, 255, 0.12)"
  textPrimary: "#F4F4F6"
  textSecondary: "#9A9CA6"
  textMuted: "#62646E"
  primaryCtaFill: "#D9D6CF"
  primaryCtaInk: "#050506"
  signalGreen: "#4ADE80"
lightTheme:
  name: Ivory Luxury
  canvas: "#F7F6F3"
  pearlGradientTop: "#FFFFFF"
  glassSurface: "rgba(255, 255, 255, 0.65)"
  glassBorder: "rgba(0, 0, 0, 0.06)"
  shadow: "rgba(20, 20, 30, 0.08)"
  textPrimary: "#111114"
  textSecondary: "#5E606A"
  textMuted: "#9A9CA6"
  primaryCtaFill: "#17181C"
  primaryCtaInk: "#F7F6F3"
  champagneMicroAccent: "#B89B5E"
  signalGreen: "#16A34A"
  destructive: "#DC2626"
typography:
  headline:
    latinFamily: IBMPlexSans
    arabicFamily: IBMPlexSansArabic
    sizes: [34, 28, 22]
  body:
    latinFamily: IBMPlexSans
    arabicFamily: IBMPlexSansArabic
    sizes: [16, 14]
    arabicLineHeight: 1.6
  mono:
    fontFamily: IBMPlexMono
    sizes: [11, 12]
    letterSpacingPercent: 8
shapes:
  tile: 14
  card: 26
  sheet: 32
  pill: 999
spacing:
  scale: [4, 8, 12, 16, 24, 32]
  screenHorizontal: 20
motion:
  stateTransitionMs: 250
  curve: ease-out
  lockBreathingLoopSec: 4
---

# BIG DUCK — Obsidian & Ivory Signal Vault

Quiet luxury mobile interface (`393×852` reference viewport, Arabic RTL primary with symmetrical English LTR mirror) for client-side zero-knowledge encrypted cloud storage over Telegram MTProto (`Argon2id + AES-256-GCM`).

## Design Tokens

### Palette
- **Primary (`#D9D6CF` Champagne-Platinum):** Primary action buttons (Dark), active floating nav circle, focus outline, active progress fill, and toggle knob. In **Ivory Light**, primary CTA surfaces invert to **Graphite (`#17181C`)** with `#F7F6F3` ivory text, while warm gold (`#B89B5E`) handles hairline accents and micro-indicators.
- **Secondary (`#9A9CA6` Cool Slate / `#5E606A` on Light):** Supporting descriptions, borders, inactive `1.5px` line icons, secondary glass buttons, queued & paused transfer fills.
- **Tertiary (`#4ADE80` Signal Green / `#16A34A` on Light):** Strictly functional: connected/synced dot, live transfer count badge, completed progress fill, icon-only green confirm button, and verified `AES-256-GCM` check. Never decorative or large fills.
- **Neutral (`#050506` Obsidian / `#F7F6F3` Ivory):** Deep canvas grounds paired with `24–40px` blur liquid-glass containers (`VaultSurface`). **Preview / Darkroom viewer (`PreviewScreen`) stays deep `#050506` black in both themes.**
- **Destructive (`#F87171` Coral / `#DC2626` on Light):** Delete actions and error states as small tinted pills, icons, or concise labels only.
- **Warning (`#C9B27C` Muted Amber-Gray):** Strictly `FLOOD_WAIT` countdown chips.

## Components (`lib/widgets/vault_surface.dart` & `floating_tab_bar.dart`)
- **4 Pill Button Variants (`VaultPillButton`):** `primary`, `secondary`, `inverted`, `outlined` (with default, pressed, disabled, and loading states).
- **Floating Bottom Nav (`FloatingTabBar`):** Detached `999`-radius liquid-glass pill anchored `16px` above the bottom safe area with 4 circular icon buttons (`Files`, `Transfers`, `Preview/Recent`, `Settings`), active circle in Champagne/Graphite, live green badge on `Transfers`, and full RTL mirroring.
- **Additional Primitives:** `VaultGlassSearchField`, `VaultProgressBar`, `VaultChunkTape`, `VaultQuickActionCircle`, `VaultConfirmSquareButton`, `VaultToggle`, `VaultMonoChip`, `VaultSegmentedControl`, `VaultStackedGlassCard`, `VaultSheetShell` (`32px`), and `VaultDialogShell` (`26px`).

## Interactive Style Board
Open [docs/design-board/index.html](docs/design-board/index.html) locally in any browser to inspect all tonal ramps, reusable components, motion specs, and side-by-side `393×852` iPhone 15 Pro frames across **Obsidian Dark** / **Ivory Light** and **Arabic RTL** / **English LTR**.
