# Operations Documentation

App bundle integration, TestFlight distribution, and release management.

## Documents

- [local-development.md](local-development.md) — monorepo workspaces, test commands, and end-to-end slice order.
- [app-store-distribution.md](app-store-distribution.md) — TestFlight beta testing and App Store submission process.

## Operations Principles

1. **Automated Builds**: Use `make` and `fastlane` for reproducible builds.
2. **Beta First**: All releases go through TestFlight before App Store submission.
3. **Version Tagging**: Use semantic versioning for releases.
4. **Artifact Retention**: Keep build artifacts and dSYM files for crash analysis.
