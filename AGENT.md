This is a multi-platform app for Amateur Radio Logging.

It's the next generation of Ham2K Portable Logger, implemented as a Flutter app that runs on Android, iOS, web, Windows, macOS and Linux.

It's called "Ham2K Logger", or "HaLo" for short. On desktop versions it identifies itself as "Ham2K Logger" while on mobile versions it uses "Ham2K Portable Logger".

# Design & Architecture

* /DESIGN.md has high-level design documentation
* User interface conventions are listed in /docs/design/user-interface.md, branding is documented in /docs/design/branding.md
* The extension system and hooks are defined in /docs/extensions/*

# Process Conventions

* Agents should make commits to the repository when relevant changes are made. If the agent is continuing during a session, such as making further updates based on developer feedback, they may ammend the previous commit if it is still related to the changes.

# Tooling

* On the development environment, we use `mise` to manage dependencies and tool versions.
