# Releasing MarkDone

Releases are signed with a Developer ID certificate, notarized by Apple, and published as a `.dmg` and `.zip` on [GitHub Releases](https://github.com/bholdman/markdone/releases). `scripts/package.sh` automates everything except the one-time Apple credential setup.

## One-time setup

**1. Install a Developer ID Application certificate.**
In Xcode: **Settings → Accounts** → your Apple Developer team → **Manage Certificates…** → **+** → **Developer ID Application**. Confirm it's in your keychain:

```sh
security find-identity -v -p codesigning   # look for "Developer ID Application: … (TEAMID)"
```

**2. Store notarization credentials.**
Create an app-specific password at appleid.apple.com (Sign-In & Security), then:

```sh
xcrun notarytool store-credentials MarkDoneNotary \
  --apple-id "you@example.com" --team-id TEAMID
```

## Cutting a release

1. Bump `MARKETING_VERSION` in `scripts/genproj.py` and commit.
2. Run the packager (Team ID is auto-detected from the certificate if omitted):

   ```sh
   ./scripts/package.sh
   ```

   This regenerates the project, builds Release with hardened runtime, notarizes and staples the app, then builds, signs, notarizes, and staples the DMG. Output lands in `dist/`.

3. Verify a clean Mac would accept both artifacts:

   ```sh
   spctl -a -vvv -t install build-release/Build/Products/Release/MarkDone.app
   spctl -a -vvv -t open --context context:primary-signature dist/MarkDone-<version>.dmg
   ```

   Both should report `accepted` with `source=Notarized Developer ID`.

4. Tag and publish:

   ```sh
   git tag v<version> && git push --tags
   gh release create v<version> dist/MarkDone-<version>.dmg dist/MarkDone-<version>.zip \
     --title "MarkDone <version>" --notes "..."
   ```

Environment overrides for `package.sh`: `DEV_ID` (full identity string), `TEAM_ID`, `NOTARY_PROFILE` (default `MarkDoneNotary`), and `SKIP_NOTARIZE=1` for a signed-but-not-notarized test build.

## Gotchas learned the hard way

- **`get-task-allow` breaks notarization.** Xcode injects this debug entitlement by default; the script passes `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` and refuses to continue if it's present.
- **The DMG needs its own notarization.** A disk image is a separate artifact with its own hash. Sign it, notarize it, then staple it, in that order. Stapling alone gives "Record not found".
- **Ad-hoc builds trigger Gatekeeper.** A Debug build or a `SKIP_NOTARIZE=1` build will show "can't be checked for malicious software" on other Macs. Right-click → Open, or `xattr -dr com.apple.quarantine MarkDone.app`, gets past it for local testing.
