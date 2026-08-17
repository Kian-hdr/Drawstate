# Mac App Store Release Procedure

This procedure prepares an uploadable package. It does not create an App Store record, upload a build, publish a release, or submit for review automatically. Obtain Kian's confirmation immediately before any of those external actions.

## Required Apple assets

- An App Store Connect app record whose bundle identifier matches `com.kiankonradtajbakhsh.drawstate.appstore`
- An Apple Distribution certificate in the signing keychain
- A Mac Installer Distribution certificate in the signing keychain
- A Mac App Store provisioning profile for the Store bundle identifier
- App metadata, screenshots, privacy answers, support URL, and review notes

## Local validation build

An ad-hoc signed sandbox build is sufficient for local code and entitlement validation:

```sh
swift test -Xswiftc -DAPP_STORE
./Scripts/package-app-store.sh release
codesign -d --entitlements - build/Drawstate-AppStore.app
```

Run the complete two-edition regression check with:

```sh
./Scripts/validate-editions.sh
```

## Distribution-signed package

Keep signing material in Keychain and the provisioning profile outside the repository. Then run:

```sh
export DRAWSTATE_APP_STORE_SIGNING_IDENTITY='Apple Distribution: Kian Konrad Tajbakhsh (HZWY8HT54D)'
export DRAWSTATE_APP_STORE_INSTALLER_IDENTITY='3rd Party Mac Developer Installer: Kian Konrad Tajbakhsh (HZWY8HT54D)'
export DRAWSTATE_APP_STORE_PROVISIONING_PROFILE='/absolute/path/Drawstate_App_Store.provisionprofile'
./Scripts/build-app-store-package.sh 1.0.1 2
```

The script builds a universal `APP_STORE` application, embeds the provisioning profile, signs it with the sandbox entitlement, creates a signed installer package, and checks the package signature. It does not upload the package.

Certificate display names can differ by account generation. Use `security find-identity -v -p codesigning` and Keychain Access to copy the exact installed identities.

## Upload and release

After explicit approval to perform the external action:

1. Create or verify the App Store Connect record and version metadata.
2. Upload the signed package using Xcode or Transporter.
3. Wait for App Store Connect processing and inspect any validation warnings.
4. Select the processed build for the version.
5. Add the final review notes from [APP-REVIEW-NOTES.md](APP-REVIEW-NOTES.md).
6. Ask again before submitting for App Review if that action was not included in the current approval.
7. After approval, ask before manually releasing the version if automatic release was not authorized.

Mac App Store distribution is separate from Developer ID notarization. The Direct release procedure remains in [RELEASING.md](RELEASING.md).
