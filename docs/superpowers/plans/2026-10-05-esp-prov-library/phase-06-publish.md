> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Part of the [esp_prov Library Implementation Plan](plan.md). Before any task,
read that file's **Global Constraints** (toolchain, `fvm` commands, names,
lint rules, commit trailers) and **Review Focus**. Spec:
`docs/superpowers/specs/2026-10-05-esp-prov-library-design.md`.

# Phase 6: Publish dry-run, verified publisher, CHANGELOGs

**Goal:** Release-ready packages: licenses, CHANGELOGs, clean publish dry-runs, 160/160 pana for `esp_prov_core`, a tag-triggered publish workflow, and the account setup handed to the user.

**Depends on:** Phase 5 (including the hardware matrix in Task 5.3).

---

### Task 6.1: Licenses and CHANGELOGs

**Files:**
- Create: `LICENSE`
- Create: `packages/*/LICENSE`
- Create: `packages/esp_prov_core/CHANGELOG.md`
- Create: `packages/esp_prov_ble_universal/CHANGELOG.md`
- Create: `packages/esp_prov/CHANGELOG.md`

**Interfaces:**
- Consumes: all packages from Phases 1-5.
- Produces: `LICENSE` at the root and in each package; `CHANGELOG.md` per package with the 0.1.0 entry.

License decision (not in the spec): Apache-2.0 is assumed because
the vendored Espressif protos are Apache-2.0 and the generated Dart is
derived from them, and `cryptography_plus` is Apache-2.0 too. pana scored
the core package 160/160 with this text. **Ask the user to confirm before
running Step 1.** If they choose MIT or BSD-3-Clause instead, keep
`third_party/espressif/proto/LICENSE.*` as they are and write the chosen
text to the four `LICENSE` files.

- [ ] **Step 1: Add the license files**

Run (from the repository root):

```bash
curl -fsSL -o LICENSE https://www.apache.org/licenses/LICENSE-2.0.txt
for pkg in packages/esp_prov_core packages/esp_prov_ble_universal packages/esp_prov; do
  cp LICENSE "$pkg/LICENSE"
done
head -3 packages/esp_prov_core/LICENSE
```

Expected: `Apache License`, `Version 2.0, January 2004`.

- [ ] **Step 2: Write the CHANGELOGs**

Create `packages/esp_prov_core/CHANGELOG.md`:

```markdown
## 0.1.0

- Initial release.
- `EspSession`: `proto-ver` parsing, security scheme selection from the
  firmware, serialised encrypted requests.
- Security 0, Security 1 (X25519 + AES-256-CTR + PoP) and Security 2
  (SRP-6a 3072-bit SHA-512 + AES-256-GCM, `sec_patch_ver` 0 and 1).
- Wi-Fi and Thread scan and provisioning, `prov-ctrl` commands, custom
  endpoints, QR payload parsing.
- Typed errors (`ProvException` hierarchy).
```

Create `packages/esp_prov_ble_universal/CHANGELOG.md`:

```markdown
## 0.1.0

- Initial release.
- `UniversalBleScanner` and `UniversalBleTransport` on `universal_ble` ^2.2.0:
  name-prefix scanning, MTU 512 on Android, 0x2901 endpoint discovery with
  UUID-table fallback, serialised write-then-read transactions, disconnect
  detection.
```

Create `packages/esp_prov/CHANGELOG.md`:

```markdown
## 0.1.0

- Initial release.
- `EspProvisioning.scan` / `findDevice` and `EspDevice.connect` on top of
  `esp_prov_core` and `esp_prov_ble_universal`.
- Example app: scan, QR payload, Wi-Fi scan and provisioning, custom data.
```

- [ ] **Step 3: Commit**

```bash
git add \
  packages/esp_prov_core/CHANGELOG.md \
  packages/esp_prov_ble_universal/CHANGELOG.md \
  packages/esp_prov/CHANGELOG.md \
  LICENSE \
  packages/esp_prov_core/LICENSE \
  packages/esp_prov_ble_universal/LICENSE \
  packages/esp_prov/LICENSE
git commit -m "chore: licenses and 0.1.0 changelogs" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 6.2: Publish dry-runs, pana score and the publish workflow

**Files:**
- Create: `tool/pana.sh`
- Create: `.github/workflows/publish.yaml`

**Interfaces:**
- Consumes: committed packages (6.1).
- Produces: `tool/pana.sh <package dir>`; `.github/workflows/publish.yaml` (tag `<package>-v<version>` publishes that package via pub.dev OIDC).

`pub publish --dry-run` checks the committed tree, so run it on a clean
working copy, before writing this task's files. pana scores a package the
way pub.dev does, so `tool/pana.sh` copies the package alone and removes
`resolution: workspace`. That only resolves for packages whose dependencies
are already on pub.dev, so before the first release only `esp_prov_core`
can be scored (success criterion 3). `pana --project-root` was tried for
the Flutter packages and fails while `esp_prov_core` is unpublished.

The publish workflow follows pub.dev's automated publishing model: GitHub
OIDC, `id-token: write`, `dart-lang/setup-dart@v1` configures the token, and
then `flutter pub publish --force` for the Flutter packages. Before the
first tag, verify it against https://dart.dev/tools/pub/automated-publishing
(in particular that `flutter pub publish` picks up the token that
`setup-dart` configured).

- [ ] **Step 1: Dry-run all three packages on a clean tree**

Run (from the repository root):

```bash
git status --porcelain   # must print nothing
(cd packages/esp_prov_core && fvm dart pub publish --dry-run)
(cd packages/esp_prov_ble_universal && fvm flutter pub publish --dry-run)
(cd packages/esp_prov && fvm flutter pub publish --dry-run)
```

Expected: `Package has 0 warnings.` three times. The adapter and `esp_prov` dry-runs pass even though `esp_prov_core` is not on pub.dev yet.

- [ ] **Step 2: Add the pana script and score esp_prov_core**

Create `tool/pana.sh`:

```bash
#!/usr/bin/env bash
# Scores one workspace package with pana the way pub.dev sees it: the
# package directory alone, with `resolution: workspace` removed so its
# dependencies resolve from pub.dev.
#
# Requirements: fvm dart pub global activate pana
# Usage: tool/pana.sh packages/esp_prov_core
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="${1:?usage: tool/pana.sh packages/<name>}"
NAME="$(basename "$PKG")"
SDK="$ROOT/.fvm/flutter_sdk"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cp -R "$ROOT/$PKG" "$TMP/$NAME"
rm -rf "$TMP/$NAME/.dart_tool" "$TMP/$NAME/build"
sed -i.bak '/^resolution: workspace$/d' "$TMP/$NAME/pubspec.yaml"
rm "$TMP/$NAME/pubspec.yaml.bak"

PATH="$SDK/bin:$PATH" "$SDK/bin/dart" pub global run pana \
  --no-warning --flutter-sdk "$SDK" "$TMP/$NAME"
```

Run: `chmod +x tool/pana.sh && fvm dart pub global activate pana && tool/pana.sh packages/esp_prov_core`

Expected: `Supports 6 of 6 possible platforms (**iOS**, **Android**, **Web**, **Windows**, **macOS**, **Linux**)` and `Points: 160/160.`
Before the GitHub repository exists the pubspec section shows `[~]` with "Repository URL doesn't exist"; it does not cost points.

- [ ] **Step 3: Add the publish workflow**

Create `.github/workflows/publish.yaml`:

```yaml
# Publishes one package when a tag `<package>-v<version>` is pushed, using
# pub.dev automated publishing (GitHub OIDC). Each package must have
# automated publishing enabled on its pub.dev admin page with the tag
# pattern `<package>-v{{version}}` and the `pub.dev` environment.
name: publish

on:
  push:
    tags:
      - 'esp_prov_core-v[0-9]+.[0-9]+.[0-9]+*'
      - 'esp_prov_ble_universal-v[0-9]+.[0-9]+.[0-9]+*'
      - 'esp_prov-v[0-9]+.[0-9]+.[0-9]+*'

jobs:
  publish:
    runs-on: ubuntu-latest
    environment: pub.dev
    permissions:
      id-token: write
    steps:
      - uses: actions/checkout@v4
      # Configures the pub.dev OIDC token for the dart/flutter pub client.
      - uses: dart-lang/setup-dart@v1
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 3.47.5
          channel: stable
      - name: Package from tag
        id: pkg
        run: echo "name=${GITHUB_REF_NAME%-v*}" >> "$GITHUB_OUTPUT"
      - run: flutter pub get
      - name: Publish
        working-directory: packages/${{ steps.pkg.outputs.name }}
        run: flutter pub publish --force
```

- [ ] **Step 4: Commit**

```bash
git add \
  tool/pana.sh \
  .github/workflows/publish.yaml
git commit -m "ci: pana script and tag-triggered publish workflow" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---

### Task 6.3: Verified publisher, first release and the release procedure

**Files:**
- Create: `docs/releasing.md`

**Interfaces:**
- Consumes: everything; the user owns the GitHub and pub.dev accounts.
- Produces: `docs/releasing.md`; packages live on pub.dev under a verified publisher with automated publishing enabled.

Most of this task is account work only the user can do. The implementer
writes `docs/releasing.md`, commits it, then hands Steps 2-5 to the user
and waits. Assumption to confirm with the user: the GitHub repository is
`https://github.com/MinhTri1401/esp_prov`, as written in every pubspec's
`repository`/`issue_tracker`. If it differs, update those fields first,
re-run the Task 6.2 dry-runs, and commit.

- [ ] **Step 1: Write the release procedure**

Create `docs/releasing.md`:

```markdown
# Releasing

Packages are published in dependency order: `esp_prov_core`, then
`esp_prov_ble_universal`, then `esp_prov`. Each has its own version and
CHANGELOG.

## Every release

1. `tool/check.sh` passes and `docs/hardware-verification.md` sections 4-5
   are done for builds A and B on Android and iOS.
2. Bump `version:` in the package's `pubspec.yaml`, add a CHANGELOG entry,
   and update dependents' constraints if the change is breaking.
3. Dry runs: `(cd packages/esp_prov_core && fvm dart pub publish --dry-run)`,
   and `fvm flutter pub publish --dry-run` in the two Flutter packages.
   Expected: `Package has 0 warnings.`
4. `tool/pana.sh packages/<name>`: expected `Points: 160/160.` (the Flutter
   packages can only be scored after their dependencies are on pub.dev).
5. Commit, then push one tag per package:
   `git tag esp_prov_core-v0.1.1 && git push origin esp_prov_core-v0.1.1`.
   `.github/workflows/publish.yaml` publishes it through pub.dev automated
   publishing.

## One-time setup (done by the repository owner)

1. Create the GitHub repository named in the pubspecs'
   `repository:` fields and push `main`.
2. Create a verified publisher on pub.dev (needs a domain verified in
   Google Search Console) and note its name.
3. Publish 0.1.0 of each package manually, in order, with
   `fvm dart pub publish` / `fvm flutter pub publish`. Automated
   publishing cannot create a package.
4. On each package's pub.dev admin page: transfer it to the verified
   publisher, enable "Automated publishing" from GitHub Actions with the
   repository, tag pattern `<package>-v{{version}}` (for example
   `esp_prov_core-v{{version}}`), and required environment `pub.dev`.
5. In GitHub repository settings create the environment `pub.dev`
   (optionally with required reviewers).
6. Ask the owner of the unrelated `flutter_esp_ble_prov` package
   (GitLab afshar-oss) to add a note pointing users to `esp_prov`.
```

- [ ] **Step 2: MANUAL (user): create the repository and push**

Create the GitHub repository, then:

```bash
git remote add origin git@github.com:MinhTri1401/esp_prov.git
git push -u origin main
```

Expected: the `ci` workflow run on `main` is green.

- [ ] **Step 3: MANUAL (user): verified publisher and first publish**

Follow `docs/releasing.md` "One-time setup" steps 2-3: publish
`esp_prov_core`, then `esp_prov_ble_universal`, then `esp_prov`. Expected:
each `pub publish` ends with `Successfully uploaded package.`

- [ ] **Step 4: MANUAL (user): automated publishing and post-publish scores**

Do "One-time setup" steps 4-5. Then run
`tool/pana.sh packages/esp_prov_ble_universal` and
`tool/pana.sh packages/esp_prov`. Expected: `Points: 160/160.` for both
(or the pub.dev score pages show 160 once analysis finishes).

- [ ] **Step 5: MANUAL (user): ask the old package owner for a pointer**

Do "One-time setup" step 6 (spec section 2 follow-up).

- [ ] **Step 6: Commit**

```bash
git add \
  docs/releasing.md
git commit -m "docs: release procedure" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014gxDHNxF3eTEzoig5VhMXn"
```

---
