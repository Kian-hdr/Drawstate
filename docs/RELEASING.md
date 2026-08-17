# Releasing Drawstate Direct

This procedure is for the GitHub Releases and Homebrew **Drawstate Direct** edition. Public binaries must be Developer ID signed, hardened, timestamped, notarized, and stapled. Never publish an ad-hoc signed app.

The separate sandboxed Mac App Store workflow is documented in [APP-STORE-RELEASE.md](APP-STORE-RELEASE.md). Do not create an App Store record, upload a build, publish, or submit for review without Kian's explicit approval immediately before the external action.

## Prerequisites

- Apple Developer Program membership
- A `Developer ID Application` certificate installed in the signing keychain
- A validated `notarytool` Keychain profile, or Apple ID notarization credentials

## Local release

```sh
export DRAWSTATE_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export DRAWSTATE_NOTARY_PROFILE='DrawstateNotary'
./Scripts/notarize-release.sh 1.0.1
```

Create the local Keychain profile once with `xcrun notarytool store-credentials DrawstateNotary`. The password remains in Keychain and is not passed through scripts or shell history.

CI can instead provide credentials through environment variables:

```sh
export DRAWSTATE_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export APPLE_ID='developer@example.com'
export APPLE_TEAM_ID='TEAMID'
export APPLE_APP_SPECIFIC_PASSWORD='app-specific-password'
./Scripts/notarize-release.sh 1.0.1
```

The script explicitly packages the Direct edition, builds a universal app, signs it with hardened runtime, submits it to Apple's notary service, staples and validates the ticket, performs a Gatekeeper assessment, and creates a checksummed ZIP. The Mac App Store compile condition does not affect this path.

GitHub Actions performs the same process for tags matching `v*` after the repository secrets documented in `.github/workflows/release.yml` are configured.

Configure these repository secrets before tagging a release:

- `DEVELOPER_ID_APPLICATION_P12`
- `DEVELOPER_ID_APPLICATION_PASSWORD`
- `DEVELOPER_ID_APPLICATION_IDENTITY`
- `RELEASE_KEYCHAIN_PASSWORD`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `HOMEBREW_TAP_TOKEN`, scoped to update `Kian-hdr/homebrew-drawstate`

After publishing the notarized GitHub asset, the workflow renders a checksummed cask and pushes it to the Homebrew tap automatically.
