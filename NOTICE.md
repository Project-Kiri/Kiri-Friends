# Notices and Licenses

Kiri Friends is a monorepo with two distinct license boundaries.

## MIT — default

The top-level `LICENSE` (MIT) applies to the shared domain library, the
legacy CLI scaffold, the Cloud Relay server, CLI plugins, fixtures, and
documentation:

- `apps/apple/Sources/KiriFriendsCore/`
- `apps/apple/Sources/KiriFriendsCLI/`
- `apps/apple/Tests/KiriFriendsCoreTests/`
- `server/`
- `plugins/`
- `fixtures/`
- `docs/`

## AGPL-3.0 — Apple-platform surfaces and Mac Buddy

Every Apple-platform binary in this monorepo bundles assets and runtime
semantics ported verbatim from
[Clawd on Desk](https://github.com/rullerzhou-afk/clawd-on-desk), which
is AGPL-3.0. To keep redistribution legally clean, the following
directories are AGPL-3.0:

- `apps/apple/Sources/KiriFriendsMacBuddyKit/` — Mac Buddy domain library.
- `apps/apple/Sources/KiriFriendsBuddyMac/` — Mac Buddy SwiftUI executable.
- `apps/apple/Sources/KiriFriendsWatchKit/` — Watch UI library; bundles
  the Clawd / Calico / Cloudling theme packs.
- `apps/apple/Sources/KiriFriendsWatchApp/` — Watch app executable.
- `apps/apple/Sources/KiriFriendsWidgets/` — Watch / iPhone widget
  library (ships inside the Watch bundle).
- `apps/apple/Sources/KiriFriendsBridge/` — iPhone companion support
  code that forwards manifests and asset packs.
- `apps/apple/Sources/KiriFriendsPhoneApp/` — iPhone companion executable.
- `apps/apple/Tests/KiriFriendsMacBuddyKitTests/` — Mac Buddy tests.

Each directory carries its own `LICENSE` file containing the full
AGPL-3.0 text.

For the rationale, the distribution channels we plan to use, and the
process for stripping the AGPL surfaces in a downstream fork, see
[docs/operations/license-boundaries.md](docs/operations/license-boundaries.md).

## Distribution

Distribution is **self-build and internal only**. Public App Store and
external TestFlight are intentionally not pursued under the current
license layout, because the AGPL-3.0 source-availability requirement
is not compatible with how Apple wants to bind end users via the App
Store agreement. Anyone publishing binaries that include the AGPL
surfaces (including via Apple Developer team internal TestFlight) must
make the corresponding source available to recipients along with the
AGPL notice.

The project maintainers have explicitly accepted this trade-off so the
watch and iPhone surfaces can render the same buddy art as the Mac
Buddy without re-creating the artwork under a permissive license.

## Third-Party Asset Notices

Theme assets under
`apps/apple/Sources/KiriFriendsBuddyMac/Resources/Themes/` and
`apps/apple/Sources/KiriFriendsWatchKit/Resources/Themes/` are
derivative of the Clawd-on-Desk theme packages and remain AGPL-3.0.
The Clawd, Calico, and Cloudling theme artwork is © the Clawd-on-Desk
authors; see the upstream
[NOTICE](https://github.com/rullerzhou-afk/clawd-on-desk/blob/main/NOTICE.md)
for the original attributions.
