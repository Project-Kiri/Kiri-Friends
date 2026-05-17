# Distribution

The Apple-platform binaries (Watch app, iPhone companion, Widgets, Mac
Buddy, and their supporting libraries) are AGPL-3.0 because they bundle
or render assets and runtime semantics from
[Clawd on Desk](https://github.com/rullerzhou-afk/clawd-on-desk). See
[license-boundaries.md](license-boundaries.md) for the full rationale.

Under that license, **public App Store and external TestFlight are not
part of the current distribution plan**. The AGPL-3.0
source-availability requirement is not compatible with the App Store
agreement's "additional terms" clause in the way Apple binds end
users. Pursuing public distribution would require either re-licensing
or replacing the AGPL assets with originals under a permissive
license.

This document describes what we actually support.

## Self-build (default)

Anyone with the source checkout and Xcode can produce a personal build:

```bash
make dev-iphone   # builds + installs the iPhone companion in Simulator
make dev-watch    # builds + installs the Watch app in Watch Simulator
make dev-mac      # builds and launches Mac Buddy locally
```

These targets generate `KiriFriends.xcodeproj` via XcodeGen when
needed. Self-builds run on the developer's machine and the connected
simulator; no signing or upload is involved.

## Internal TestFlight (Apple Developer team only)

Builds shared with internal QA testers go through Apple Developer
Program internal TestFlight test groups. Internal TestFlight is
limited to the project's own Apple Developer team members; it does not
make the binary available to the general public.

To publish an internal TestFlight build:

1. Archive the iPhone companion or Watch app target in Xcode under a
   Release configuration.
2. Upload the archive to App Store Connect via the Organizer.
3. Add the build to an **Internal Testing** test group only. Do not
   create an External Testing group.
4. Distribute the AGPL source alongside the build link. Recipients
   must be able to fetch the corresponding source either from this
   repository or from an explicit `git clone` URL paired with the
   build.

External TestFlight groups (which allow up to 10,000 public testers
via a public link) are out of scope.

## Ad hoc provisioning

For one-off installs onto specific hardware (the maintainer's own
phone or a small set of test devices), use Xcode's "Distribute App" →
"Ad Hoc" flow with the device UDIDs registered in the Apple Developer
account. Same AGPL source-distribution obligation applies.

## Build Versioning

Use semantic versioning:

- `MAJOR.MINOR.PATCH`
- Increment `MAJOR` for significant feature releases
- Increment `MINOR` for new features
- Increment `PATCH` for bug fixes

Tag releases in git with the same version. The tag commit must point
to source that exactly matches the binary distributed to AGPL
recipients.

## Re-licensing path (if public App Store ever becomes a goal)

If the project decides to publish on the public App Store, the Apple
surfaces need to drop the AGPL boundary. The cleanest way is:

1. Replace `Resources/Themes/clawd|calico|cloudling/` with original
   art that the project can ship under MIT.
2. Re-derive the Mac Buddy state machine semantics without copying
   upstream source patterns verbatim (or arrange relicensing with the
   upstream maintainers).
3. Restore the previous MIT layout for `KiriFriendsWatchKit`,
   `KiriFriendsWatchApp`, `KiriFriendsBridge`, `KiriFriendsPhoneApp`,
   and `KiriFriendsWidgets`.

This is a major effort and is intentionally not on the current roadmap.
