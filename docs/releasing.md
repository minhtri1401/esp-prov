# Releasing

Packages are published in dependency order: `esp_prov_core`, then
`esp_prov_ble_universal`, then `esp_prov`. Each has its own version and
CHANGELOG. Each later package depends on the earlier ones with `^0.1.0`,
which only resolves once the dependency is on pub.dev.

Run every command through FVM (`fvm flutter ...`, `fvm dart ...`).

## Hardware gate

Before tagging 0.1.0, complete the checklist in
`docs/hardware-verification.md` (sections 4-5, builds A and B, Android and
iOS) and record the resulting matrix in that file. Do not tag until it is
filled in.

## One-time setup (repository owner)

1. Create the GitHub repository `https://github.com/minhtri1401/esp-prov`
   (the URL in every pubspec's `repository:`), then push `main`:

   ```bash
   git remote add origin git@github.com:minhtri1401/esp-prov.git
   git push -u origin main
   ```

   Confirm the `ci` workflow is green.
2. In the GitHub repository settings, create the environment `pub.dev`
   (optionally with required reviewers).
3. Create a verified publisher on pub.dev (needs a domain verified in
   Google Search Console) and note its name.
4. Publish 0.1.0 of each package manually from a laptop, in dependency
   order. Automated publishing can only be enabled on a package that
   already exists, so the first version cannot come from CI.

   ```bash
   (cd packages/esp_prov_core && fvm dart pub publish)
   (cd packages/esp_prov_ble_universal && fvm flutter pub publish)
   (cd packages/esp_prov && fvm flutter pub publish)
   ```

   Each ends with `Successfully uploaded package.` Wait for each package
   to appear on pub.dev before publishing the next.
5. On each package's pub.dev admin page: transfer it to the verified
   publisher, then enable "Automated publishing" from GitHub Actions with
   repository `minhtri1401/esp-prov`, tag pattern `<package>-v{{version}}`
   (for example `esp_prov_core-v{{version}}`), and "Require GitHub Actions
   environment" set to `pub.dev`.
6. After the dependencies are live, score the Flutter packages:
   `tool/pana.sh packages/esp_prov_ble_universal` and
   `tool/pana.sh packages/esp_prov`. Expected: `Points: 160/160.`
7. Ask the owner of the unrelated `flutter_esp_ble_prov` package (GitLab
   afshar-oss) to add a note pointing users to `esp_prov`.

## Every release

1. Bump `version:` in the package's `pubspec.yaml` and, if the change is
   breaking, the dependents' constraints. Add a CHANGELOG entry.
2. `tool/check.sh` passes. For releases touching BLE or provisioning
   behaviour, redo the relevant part of `docs/hardware-verification.md`.
3. `tool/pana.sh packages/<name>`: expected `Points: 160/160.`
4. Dry run: `(cd packages/esp_prov_core && fvm dart pub publish --dry-run)`
   and `fvm flutter pub publish --dry-run` in the two Flutter packages.
   Expected: `Package has 0 warnings.`
5. Commit, then tag and push one tag per package, in dependency order:

   ```bash
   git tag esp_prov_core-v0.1.1
   git push origin esp_prov_core-v0.1.1
   ```

   `.github/workflows/publish.yaml` publishes it through pub.dev automated
   publishing.
6. Watch the `publish` workflow in the Actions tab, then check the new
   version on pub.dev (page, score, and the example tab).

## Verify on first tag

Two parts of `publish.yaml` were written from documentation and have not
run. On the first real tag, check these in the workflow log; if either
fails, fix the workflow before the next release.

- OIDC token pickup. The workflow runs `flutter pub publish --force` after
  `dart-lang/setup-dart@v1`. dart.dev documents automated publishing for
  the Dart client and recommends its reusable workflow, which this repo
  does not use. Check that the Publish step authenticates through the
  GitHub OIDC token rather than asking for a browser login. If it does
  not, switch that step to `dart pub publish --force` or adopt the
  reusable workflow.
- `subosito/flutter-action@v2` inputs. Check that the step installs
  Flutter 3.47.5 on the stable channel (the log prints the resolved
  version) and that `flutter pub get` and the publish step run with it.
  Adjust `flutter-version`/`channel` if the action rejects the pair.

Also confirm the tag-to-package step resolved the right package name
(`esp_prov_core-v0.1.1` gives `esp_prov_core`) and that the job waited for
the `pub.dev` environment approval if reviewers are set.
