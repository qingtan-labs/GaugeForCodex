# Gauge for Codex Launcher

The launcher is a small, non-resident companion for Gauge for Codex:

- It first asks the configured per-user LaunchAgent to start Gauge for Codex.
- If the LaunchAgent is unavailable, it opens a registered installation or checks `~/Applications` and `/Applications`.
- It never starts Codex itself or the retired standalone pet.
- It uses the same language-neutral gauge icon and supports English, Simplified Chinese, Japanese, and Spanish error messages.

Build output: `build/Gauge for Codex Launcher.app`.
