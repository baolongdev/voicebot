# Changelog - main

## 2026-01-30
- Updated CI build workflow to publish only Android/Windows/Linux and create Releases on tags.
- Added Linux build dependencies and GCC/G++ toolchain settings in CI.
- Removed macOS, iOS, and Web build jobs from CI workflow.

## 2026-01-29
- Latest commit summary: added PR template, branch-name/build workflows, and docs updates (AGENTS.md, CONTRIBUTING.md, README.md).
- Added branch naming convention section to AGENTS.md.
- Added CONTRIBUTING.md with branch naming rules.
- Added PR template for selecting change type and checklist.
- Added branch name enforcement workflow for PRs.
- Added build workflow for Android (APK + AAB), Windows, Linux, macOS, iOS (no codesign), and Web.
- Added README.md link to CONTRIBUTING.md.
- Added changelog folder placeholder.
- Updated OTA test mock method channel usage and added @override annotations for HttpClientRequest fields.
- Removed unused fields/imports and TODO lint markers across audio/chat/ota/form components.
- Wired ChatController to enqueue response audio bytes into playback pipeline.
- Fixed null-aware operator warning in FormRepositoryImpl.

## Notes
- GitHub rulesets for branch naming were not enabled due to repo plan limits; enforced via workflow instead.
- Labels created on GitHub: feat, fix, chore, refactor, perf, test, docs, ci, build, hotfix.
