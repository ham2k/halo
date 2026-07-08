# Ham2K Logger Project Rules & Guidelines

This is a multi-platform app for Amateur Radio Logging, called "Ham2K Logger" (or "HaLo" for short). On desktop versions it identifies itself as "Ham2K Logger" while on mobile versions it uses "Ham2K Portable Logger".

## Design & Architecture
- [DESIGN.md](file:///Users/sd/Work/ham2k/app-halo/DESIGN.md) contains high-level design documentation.
- User interface conventions are listed in [user-interface.md](file:///Users/sd/Work/ham2k/app-halo/docs/design/user-interface.md) and branding is documented in [branding.md](file:///Users/sd/Work/ham2k/app-halo/docs/design/branding.md).
- The extension system and hooks are defined under `docs/extensions/`.

## Process Conventions
- Agents should make commits to the repository when relevant changes are made. If the agent is continuing during a session (such as making updates based on developer feedback), they may amend the previous commit if it is related.
- When working on a feature, the agent might want to run the mac or web versions in the background, and use hot reload to see changes without rebuilding the app.

## Tooling
- On the development environment, we use `mise` to manage dependencies and tool versions.
