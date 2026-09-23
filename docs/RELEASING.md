# Releasing Drawstate Direct

This procedure is for the GitHub Releases and Homebrew **Drawstate Direct** edition. Public binaries must be Developer ID signed, hardened, timestamped, notarized, and stapled. Never publish an ad-hoc signed app. The intended downloadable artifact is a DMG containing `Drawstate.app`; the ZIP is an optional secondary download.

The separate sandboxed Mac App Store workflow is documented in [APP-STORE-RELEASE.md](APP-STORE-RELEASE.md). Do not create an App Store record, upload a build, publish, or submit for review without Kian's explicit approval immediately before the external action.

## Prerequisites

- Apple Developer Program membership
- A `Developer ID Application` certificate installed in the signing keychain
- A validated `notarytool` Keychain profile, or Apple ID notarization credentials
- A clean, reviewed source commit with a matching `vX.Y.Z` tag for a CI run

## Local release

```sh
export DRAWSTATE_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export DRAWSTATE_NOTARY_PROFILE='DrawstateNotary'
./Scripts/notarize-release.sh VERSION
```

Create the local Keychain profile once with `xcrun notarytool store-credentials DrawstateNotary`. The password remains in Keychain and is not passed through scripts or shell history.

CI can instead provide credentials through environment variables:

```sh
export DRAWSTATE_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export APPLE_ID='developer@example.com'
export APPLE_TEAM_ID='TEAMID'
export APPLE_APP_SPECIFIC_PASSWORD='app-specific-password'
./Scripts/notarize-release.sh VERSION
```

The script packages the Direct edition, builds a universal app, signs it with hardened runtime, submits it to Apple's notary service, staples and validates the ticket, and performs a Gatekeeper assessment. It writes `build/Drawstate-VERSION.dmg` and `build/Drawstate-VERSION.dmg.sha256`; it also writes the corresponding ZIP and checksum. The Mac App Store compile condition does not affect this path. Verify the final DMG itself before distribution, then install from the mounted DMG and launch the installed app.

The GitHub Actions workflow runs only when manually dispatched with an existing tagged version. It tests, signs, notarizes, verifies checksums, and stores the resulting files as workflow artifacts for review. Pushing a tag does not trigger a release. The workflow does not create a GitHub Release, publish a download, or update the Homebrew tap.

Configure these repository secrets before tagging a release:

- `DEVELOPER_ID_APPLICATION_P12`
- `DEVELOPER_ID_APPLICATION_PASSWORD`
- `DEVELOPER_ID_APPLICATION_IDENTITY`
- `RELEASE_KEYCHAIN_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

## Review and publication

1. Verify the DMG signature, notarization ticket, Gatekeeper assessment, hash, mounted contents, install, and launch. Record the exact tested version and hash.
2. Prepare release notes and a GitHub draft release with the versioned DMG, its `.sha256` file, and any optional ZIP. Creating even a draft release or uploading its assets requires Kian's explicit approval immediately before the external action.
3. Review the draft, then obtain separate approval before making it public. Download the published DMG and confirm its SHA-256 matches the approved file.
4. Render the Homebrew Cask from the published DMG's SHA-256 and audit/install it against the public URL. For example, `Scripts/render-homebrew-cask.sh VERSION HASH /path/to/drawstate.rb`. Push the cask to `Kian-hdr/homebrew-drawstate` within the authorized release scope.

The cask template points to the versioned DMG. Its checksum must match the bytes downloaded from GitHub, not merely an earlier local build. Record the published asset URL and checksum in the release handoff.
