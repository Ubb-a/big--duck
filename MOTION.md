---
version: 2.0
name: BIG DUCK — Obsidian & Ivory Signal Vault Motion System
tokenPrefix: vaultMotion
baseCurve: cubic-bezier(0.2, 0.0, 0.0, 1.0)
emphasizedCurve: cubic-bezier(0.16, 1.0, 0.3, 1.0)
exitCurve: cubic-bezier(0.4, 0.0, 1.0, 1.0)
reduceMotionFallback: 150ms opacity fade, loops stopped
targetFps: 60
---

# BIG DUCK — Motion & Micro-Interactions Specification

Quiet luxury motion language for **BIG DUCK — Signal Vault** (`393×852` reference viewport · Obsidian Luxury Dark & Ivory Luxury Light · Arabic RTL primary & English LTR mirror).

> **Interactive Motion Spec & Playable Prototypes:** Open [`docs/design-board/motion.html`](docs/design-board/motion.html) in a browser to inspect interactive cubic-Bézier curves, test **Reduce Motion** (`150ms` fade) and **0.25× Slow-Mo**, and click through all 7 flows in Dark/Light × AR RTL/EN LTR.

---

## 1. Motion Principles

1. **Quiet luxury:** Slow, soft, precise deceleration (`standard` / `emphasized`). Nothing bouncy or playful; only subtle `1.0 → 1.06 → 1.0` settlement on toggle knobs.
2. **State over decoration:** Every movement communicates system state (encrypting, queued, streaming, `FLOOD_WAIT`, verified, synced).
3. **Reactive liquid glass:** Specular sheen tracks scroll offset (`0–12px` parallax via `VaultScrollParallax`), borders brighten on press (`0.12 → 0.22`), and surfaces scale subtly to `0.97`.
4. **Full RTL symmetry:** Slide directions, progress fills, chunk tapes, navigation capsules, and directional chevrons invert cleanly between Arabic RTL and English LTR (`vaultMotion.directionalDx`).
5. **Strict Reduce Motion compliance:** When `MediaQuery.disableAnimationsOf(context)` (or `accessibleNavigationOf`) is active, all slides/scales downgrade to `150ms` fades and `vaultMotion.allowLoops(context)` stops all looping tickers.
6. **60fps Discipline:** Animate only `opacity`, `Transform` (`translate` / `scale` / `rotate`), and bounded blur transitions inside isolated `RepaintBoundary` layers.

---

## 2. `vaultMotion` Tokens ([`lib/theme/app_theme.dart`](lib/theme/app_theme.dart))

### Durations

| Token | Value | Flutter API | Usage |
|---|---:|---|---|
| `instant` | `90ms` | `vaultMotion.instant` | Press scale down (`0.97`), long-press lift (`1.02`) |
| `reducedFade` | `150ms` | `vaultMotion.reducedFade` | Reduce-Motion universal cross-fade fallback |
| `fast` | `180ms` | `vaultMotion.fast` | Release scale, toggles, focus ring, chips, icon swaps, toast exit |
| `base` | `250ms` | `vaultMotion.base` | Segmented capsule, progress bar glide, stroke check draw, language cross-fade |
| `slow` | `400ms` | `vaultMotion.slow` | Splash glow, Auth step tape, circular theme reveal, sheets, route fades |
| `ambient` | `4000ms` | `vaultMotion.ambient` | Breathing Lock orb (`5000ms` on Auth duck float & Transfers empty ring) |

### Curves

| Token | CSS / Cubic-Bézier | Flutter API | Usage |
|---|---|---|---|
| `standard` | `cubic-bezier(0.2, 0.0, 0.0, 1.0)` | `vaultMotion.standard` | Default deceleration for state changes, toggles, scroll bars |
| `emphasized` | `cubic-bezier(0.16, 1.0, 0.3, 1.0)` | `vaultMotion.emphasized` | Modal sheets, dialogs, segmented capsule, toast entry, Splash |
| `exit` | `cubic-bezier(0.4, 0.0, 1.0, 1.0)` | `vaultMotion.exit` | Quick dismissal, toast exit, screen leave slides |
| `linear` | `linear` | `vaultMotion.linear` | Progress highlight sweep (`1800ms`), decrypt sweep, skeleton shimmer (`1400ms`) |

### Distances & Stagger

| Token | Value | Flutter API | Notes |
|---|---:|---|---|
| `shiftSmall` | `8px` | `vaultMotion.shiftSmall` | Toast subtle slide, list tile rise |
| `shiftMedium` | `16px` | `vaultMotion.shiftMedium` | Screen enter vertical drift, toast entry offset |
| `shiftPage` | `24px` | `vaultMotion.shiftPage` | Auth step slide, folder drill-down horizontal transition |
| `staggerStep` | `30ms` | `vaultMotion.staggerStep` | Per-row entrance delay (caps at `maxStaggerItems = 8`) |

### Haptics Mapping (`VaultHaptics`)

| Trigger | Method | Events |
|---|---|---|
| Subtle UI tap | `VaultHaptics.light()` | Floating tab switch, `VaultToggle`, Chrome toggle |
| Choice change | `VaultHaptics.selection()` | Segmented control, Theme tile, Filter chip, Storage chat selection |
| Physical confirmation | `VaultHaptics.medium()` | Pause/Resume task, Long-press multi-select entry, Create vault submit, Logout confirm |
| Positive milestone | `VaultHaptics.success()` | Biometric enabled/unlocked, Backup/Index synced, Copy SHA-256 |
| Validation / auth error | `VaultHaptics.error()` | Wrong OTP digit, Biometric failed, Task failed |

---

## 3. Global Micro-Interactions

1. **Press feedback (`VaultTap` / `VaultSurface`):** `90ms` scale to `0.97`, top specular brightness `+6%`, inner border opacity `0.12 → 0.22`, release in `180ms` `standard`. Primary `VaultPillButton` also dims fill `8%` on press and swaps label to a `1.5px` ring or `VaultAnimatedDrawCheck` on `loading` / `completed`.
2. **Scroll specular parallax (`VaultScrollParallax`):** List/grid scroll offset shifts the top-edge highlight `0–12px` horizontally (mirrored in RTL).
3. **Focus ring (`VaultGlassInputContainer`):** Border animates `1px` slate → `1.5px` champagne in `180ms` with a `blur 12` champagne glow at `20%` opacity.
4. **Liquid glass toggle (`VaultToggle`):** Track fills champagne in `180ms`, knob translates with subtle `1.0 → 1.06 → 1.0` settle pulse.
5. **Sliding capsule (`VaultSegmentedControl` & `FloatingTabBar`):** Capsule glides across options in `250ms` `emphasized` while typography/icons cross-fade in `180ms`.
6. **Toast banner (`main.dart`):** Enters top `16px` + fade in `250ms` `emphasized`, stays `2.5s` (with inline `Undo` pill on destructive actions), exits in `180ms` `exit`.

---

## 4. Flutter Implementation Handoff Table

| Screen / Element | Trigger | Flutter Widget / API | Animated Properties | Duration | Curve | Delay / Stagger | Loop | Haptic | Reduce-Motion Fallback |
|---|---|---|---|---:|---|---:|---|---|---|
| **Global Press & Surface** | Pointer down / up | `VaultTap` + `VaultSurface` | `scale` (`1→0.97`), border alpha (`0.12→0.22`), brightness | `90ms` / `180ms` | `standard` | `0ms` | No | — | Border highlight only (`150ms`) |
| **Scroll Specular Sheen** | List / grid scroll | `VaultScrollParallax` + `VaultSurface` | Highlight `translateX` (`0..12px` RTL-aware) | Live scroll | Linear | `0ms` | No | — | Static top highlight |
| **Input Focus Ring** | TextField focus | `VaultGlassInputContainer` | Border width (`1→1.5`), champagne glow `blur 12` | `180ms` | `standard` | `0ms` | No | — | Instant border color change |
| **Glass Toggle** | Tap switch | `VaultToggle` | Knob `translateX`, track color, `1.0→1.06→1.0` | `180ms` | `standard` | `0ms` | No | `light` | `150ms` cross-fade, no overshoot |
| **Segmented Capsule / Bottom Tab** | Select option / tab | `VaultSegmentedControl` / `FloatingTabBar` | Active capsule `AlignmentDirectional`, label color | `250ms` / `180ms` | `emphasized` | `0ms` | No | `light` / `selection` | `150ms` fade swap |
| **Floating Nav Scroll-Hide** | Vertical scroll delta | `FloatingTabBar` (`navHiddenByScroll`) | `translateY` + `opacity` | `180ms` | `standard` / `exit` | `0ms` | No | — | Remains pinned visible |
| **Top Toast + Undo** | Action result / delete | `main.dart` Toast overlay | `translateY` (`-16→0`), `opacity`, dot pulse (`1.0→1.45`) | `250ms` in / `180ms` out | `emphasized` / `exit` | `2500ms` hold | No | `success` / `error` | `150ms` fade only |
| **Bottom Sheet / Centered Dialog** | Open sheet / modal | `showVaultBottomSheet` / `showVaultDialog` | Sheet `translateY`, Dialog `scale` (`0.94→1.0`) + backdrop blur | `400ms` / `250ms` | `emphasized` / `exit` | `0ms` | No | — | `150ms` fade, static scrim |
| **Theme Switch Circular Reveal** | Tap Light / Dark / Auto | `VaultCircularRevealClipper` (`main.dart`) | Clip circle radius (`0 → maxDiagonal`) from tapped tile | `400ms` | `emphasized` | `0ms` | No | `selection` | `150ms` cross-fade |
| **Language Mirror Switch** | Toggle `العربية / English` | `AnimatedSwitcher` (`main.dart`) | Opacity cross-fade + RTL/LTR layout mirror | `250ms` | `standard` | `0ms` | No | `selection` | `150ms` cross-fade |
| **Auth Splash & Duck Float** | Mount `AuthScreen` | `AuthScreen` `AnimationController` | Card `translateY` (`24→0`), duck `translateY` (`±4px`) | `400ms` / `5000ms` | `emphasized` / sine | `0ms` | Yes (float) | — | `150ms` fade, float stopped |
| **Auth 4-Step Tape & OTP Shake** | Step change / OTP submit | `AuthScreen` + `VaultHorizontalShake` | Step `translateX` (`±24px`), tape `widthFactor`, `3×±6px` shake | `250ms` / `400ms` / `300ms` | `standard` / `exit` | `0ms` | No | `error` on fail | `150ms` fade, coral outline |
| **Lock Screen Orb & Unlock** | Mount / Bio result | `LockScreen` + `VaultAnimatedDrawCheck` | Breathing ring (`1→1.06`), stroke check (`PathMetric`), `1→1.4` exit | `4000ms` / `250ms` / `400ms` | `emphasized` | `0ms` | Yes (orb) | `success` / `error` | `150ms` fade, coral chip on fail |
| **Files Stagger & Sticky Bar** | Mount / Scroll `FilesScreen` | `VaultStaggeredSlideFade` + top header | Title `8px`, search `+60ms`, crumbs `+120ms`, rows `30ms` step | `250ms` per item | `standard` | `30ms` (cap 8) | No | — | Single `150ms` group fade |
| **Files Folder Nav & Hero Grid** | Tap folder / Grid toggle | `FilesScreen` + `Hero('vault_item_...')` | `±24px` directional slide, shared-element grid/list morph | `250ms` / `400ms` | `standard` / `emphasized` | `0ms` | No | `light` | `150ms` fade |
| **Files `+` FAB Speed-Dial & Multi-Select** | Tap `+` / Long-press file | `FilesScreen` fan-out / selection bar | `+` rotates `45°`, 2 pills fan out (`40ms`), `1.02` lift, rolling count | `180ms` | `emphasized` | `40ms` per pill | No | `medium` | Instant pill list, `150ms` fade |
| **Empty Vault Door & Skeletons** | Empty dir / loading | `VaultEmptyDoorIllustration` / Shimmer | Stroke draw `pathLength` (`0→1`), linear sweep highlight | `1200ms` / `1400ms` | `standard` / `linear` | `0ms` | Yes (skeleton) | — | Static doorway / flat bone |
| **Preview Darkroom & Info Sheet** | Open file / tap / swipe down | `PreviewScreen` + `showVaultBottomSheet` | `Hero` expand, `±16px` chrome toggle (`3s` auto-hide), swipe scale | `400ms` / `180ms` | `emphasized` / `standard` | `40ms` Info rows | Dec. line | `light` / `success` | `150ms` fade, no parallax |
| **Transfers Live Progress & `FLOOD_WAIT`** | Task events / Pause / Fail | `TransfersScreen` + `VaultChunkTape` | Rolling `%`, bar `1.8s` shimmer, chunk flip, `FLOOD_WAIT` ring, shake | `250ms` / `1800ms` / `200ms` | `standard` / `linear` | `0ms` | Active only | `medium` / `error` | Static fill + rolling text only |
| **Settings Sections, Bio & Theme Tilt** | Tab enter / Bio / Theme tile | `SettingsScreen` + `_ThemePreviewTile` | Sections `50ms` (`12px`), `3D` touch tilt (`±0.05rad`), backup sweep | `620ms` / `180ms` / `480ms` | `standard` | `50ms` step | No | `success` / `error` / `selection` | `150ms` fade, no tilt |
| **Storage Destination Sheet** | Open / Filter / Create group | `showStorageDestinationSheet` + `_ChatRow` | Sheet rise (`400ms`), rows `30ms`, check draw, `600ms` champagne glow | `400ms` / `220ms` / `600ms` | `emphasized` / `standard` | `30ms` step | No | `selection` / `medium` | `150ms` fade, immediate pop |

---

## 5. Looping Animations CPU / GPU Cost Audit

> All infinite `.repeat()` loops are gated by `vaultMotion.allowLoops(context)`, which disables loops when `MediaQuery.disableAnimationsOf(context)` is true (and inside `flutter test` widget bindings).

| Animation Name | Screen | Animated Properties | `RepaintBoundary` / Layering | Blur Cost Flag | Idle FPS Target | Reduce-Motion Stop Behavior |
|---|---|---|---|---|---|---|
| **Auth Duck Vertical Float & Ambient Glow** | `AuthScreen` | `Transform.translate` (`±4px`) + radial glow scale | Wrapped in `RepaintBoundary`; pre-baked radial gradient (no dynamic `ImageFilter.blur` animation) | **Low** (no animated sigma) | `60 fps` | `.stop()` + `Value = 0` (`dy = 0`) |
| **Lock Screen Biometric Breathing Orb** | `LockScreen` | `Transform.scale` (`1.0→1.06`) + hairline border opacity (`0.2→0.5`) | Isolated inside `RepaintBoundary` above static canvas | **Flagged — Static Glass Sigma Only:** Orb sits on frosted glass (`blur 24px`); blur sigma is never animated—only transform/border opacity repaint inside the boundary | `60 fps` | `.stop()`, static ring at `0.35` alpha |
| **Connected / Live Transfers Dot Pulse** | `FloatingTabBar`, `SettingsScreen` | Circle `scale` (`1.0→1.45`) + alpha (`0.65→0.0`) via `VaultStatusDotAnimated` | Single `10×10` `RepaintBoundary` (`FadeTransition` / `ScaleTransition`) | **Low** (zero blur; sits atop already-rasterized tab glass) | `60 fps` | Solid dot, no pulse |
| **Active Transfer Progress Highlight Sweep** | `TransfersScreen` | Horizontal gradient shader / `FractionallySizedBox` `translateX` (`1800ms linear`) | Runs ONLY while a task has `TaskState.running`; clips to `4px` capsule track | **Low** | `60 fps` | Solid fill at `progress` fraction |
| **Active Chunk Tape Pulse & Completion Flip** | `TransfersScreen` | Opacity (`0.45→1.0`, `1200ms`) on active chunk index only | `4px` micro-bar row; `AnimatedContainer` stops immediately on chunk complete | **Low** | `60 fps` | Static champagne chip for active chunk |
| **Preview Top Indeterminate Decrypt Line** | `PreviewScreen` | Horizontal `translateX` (`-100% → +100%`) along `2px` top hairline | Runs ONLY while `_isLoadingMedia == true`; disposes when file bytes resolve | **Low** | `60 fps` | Thin static `2px` champagne indicator |
| **Vault Loading Skeleton Shimmer** | `FilesScreen` | Linear gradient `Alignment` sweep (`1400ms`) on rounded skeleton rows | Shown ONLY while initial `snapshot` loads | **Flagged — Blur Adjacent:** Cards use static solid `#1A1A1C` / `#EFECE6` base fills during loading instead of `BackdropFilter` so linear shimmer stays below `1.2ms`/frame | `60 fps` | Flat matte skeleton opacity `0.45` |
