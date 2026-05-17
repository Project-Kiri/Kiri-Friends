# License Boundaries

Kiri Friends ships under two licenses simultaneously:

- **MIT** for the shared domain library, the legacy CLI scaffold, the
  Cloud Relay server, CLI plugins, fixtures, and documentation.
- **AGPL-3.0** for every Apple-platform surface (watchOS app, iPhone
  companion, complication widgets, supporting libraries, and the macOS
  desktop buddy) because they all bundle or render assets and runtime
  semantics from
  [Clawd on Desk](https://github.com/rullerzhou-afk/clawd-on-desk).

This document explains where the line is drawn, why the watch surfaces
also turned AGPL, what distribution channels are open under that
license, and what changes if you want to redistribute Kiri Friends
without the AGPL surfaces.

## What is AGPL-licensed

The AGPL-licensed surfaces are downstream consumers of Clawd on Desk's
hook protocol, agent registry, permission bubble flow, and pixel art
theme assets (Clawd, Calico, Cloudling). The following directories are
AGPL-3.0:

- `apps/apple/Sources/KiriFriendsWatchKit/` — Watch UI library; bundles
  the three theme packs (`Resources/Themes/`).
- `apps/apple/Sources/KiriFriendsWatchApp/` — Watch app executable.
- `apps/apple/Sources/KiriFriendsWidgets/` — Watch/iPhone WidgetKit
  complication library; ships inside the Watch bundle.
- `apps/apple/Sources/KiriFriendsBridge/` — iPhone companion support
  code; forwards manifests and assets to the Watch via Watch
  Connectivity.
- `apps/apple/Sources/KiriFriendsPhoneApp/` — iPhone companion
  executable.
- `apps/apple/Sources/KiriFriendsMacBuddyKit/` — Mac Buddy domain
  library (already AGPL).
- `apps/apple/Sources/KiriFriendsBuddyMac/` — Mac Buddy SwiftUI
  executable (already AGPL).
- `apps/apple/Tests/KiriFriendsMacBuddyKitTests/` — Mac Buddy test
  suite (already AGPL).
- Any resources copied verbatim from the upstream project (theme
  packs, sounds, icons) that end up under any of the above targets.

The AGPL text is checked in at each directory's root LICENSE file.

## What stays MIT

Everything not listed above stays MIT:

- `apps/apple/Sources/KiriFriendsCore/` — cross-platform domain
  library; consumed by both MIT and AGPL surfaces.
- `apps/apple/Sources/KiriFriendsCLI/` — legacy headless CLI scaffold;
  depends only on Core.
- `apps/apple/Tests/KiriFriendsCoreTests/` — MIT test target (depends
  on Core, WatchKit, and Bridge; the AGPL dependencies do not change
  the test target's license since the artifacts are tests, not
  redistributable software).
- `server/` — Cloud Relay TypeScript server.
- `plugins/` — TypeScript CLI plugin lifecycle mappers.
- `fixtures/` — Shared golden JSON contracts.
- `docs/` — Documentation.

AGPL surfaces depend on `KiriFriendsCore`; `KiriFriendsCore` never
depends on an AGPL target. AGPL composes MIT cleanly, so this direction
is safe.

## Distribution

The current distribution plan is **self-build and internal
distribution only**:

- Build `.app` / `.ipa` artifacts locally via `make dev-mac`,
  `make dev-iphone`, `make dev-watch`, or `swift build`.
- Install on managed devices via the project's Apple Developer team
  using ad hoc provisioning or internal TestFlight test groups.
- Publish source-with-changes alongside any binary distribution to
  satisfy the AGPL.

**Apple App Store and external TestFlight are out of scope for this
plan.** The interaction between AGPL-3.0 (specifically the
source-availability requirement and "additional terms" clause) and the
Apple Developer Program License Agreement is contested. Pursuing
public App Store distribution would require a separate license review
and likely either (a) re-architecting to keep Apple-platform binaries
MIT or (b) using non-AGPL replacement assets.

If you fork Kiri Friends and want a public App Store path, follow the
"How to redistribute without the AGPL surfaces" section below.

## Why everything Apple-side went AGPL

The watch app intentionally renders the same pixel art the Mac Buddy
shows so the experience stays consistent across devices. Once the
watch bundle carries those upstream assets the binary itself becomes a
combined AGPL work; the same applies to the iPhone companion (it
forwards manifests and asset packs over Watch Connectivity) and the
Widgets library (it ships inside the Watch app bundle).

We considered three alternatives before flipping the watch surfaces:

1. **Avoid the assets on the watch.** Ship SF Symbols only. This is
   the original MIT layout but it fails the "Watch shows buddy art"
   product requirement.
2. **Re-create the assets under MIT.** Requires new artwork that
   matches the upstream visual identity; deferred until someone can
   produce equivalent originals.
3. **Bundle assets as a separately downloaded pack.** Possible via
   `BuddyAssetLibrary` and Watch Connectivity, but defaulting to "no
   art until the user installs a pack" makes the watch app feel
   broken on first launch.

We picked the AGPL flip because it preserves the upstream
contributors' copyleft promise and removes ambiguity from the
contributor's perspective. The dual-licensing of the previous plan
still works for downstream forks that strip out the AGPL surfaces.

## How to redistribute without the AGPL surfaces

If you need an AGPL-free distribution of Kiri Friends (for example for
public App Store submission):

1. Skip every target listed under "What is AGPL-licensed" when
   building. The MIT surfaces (`KiriFriendsCore`, `KiriFriendsCLI`,
   `server/`, `plugins/`) continue to build and run on their own.
2. Do not bundle any file from those directories into your release
   artifact.
3. Replace the watch / iPhone / widget surfaces with originals you can
   ship under MIT (or a license compatible with your distribution
   channel).
4. Update `NOTICE.md` and this document for your fork to remove the
   AGPL surfaces.

Optionally delete the AGPL directories outright in your fork; the
remaining monorepo continues to build under MIT.

## Adding new code

When adding code that is conceptually part of an AGPL surface, put it
in one of the AGPL directories listed above. Do not move
domain-shared types into those directories; cross-cutting types
belong in `KiriFriendsCore`.

When adding code in an MIT directory that an AGPL surface will
consume:

- Keep the MIT code free of any direct dependency on AGPL files; the
  dependency must always point AGPL → MIT, never the reverse.
- Do not copy AGPL upstream code into an MIT directory and rename it.
  When the behavior is identical, move the file to the AGPL directory
  that already imports it.
- If your change pulls in additional third-party code or assets, list
  them in `NOTICE.md` with their upstream license.
