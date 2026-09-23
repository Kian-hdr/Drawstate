# Privacy

Drawstate processes power and battery telemetry locally on the Mac where it runs.

When a compatible USB HID/UPS power bank is connected, Drawstate may read its locally published battery status and public USB identity descriptors. This information is displayed on the Mac and is not stored as a history or transmitted.

Drawstate does not collect, transmit, sell, or share personal data. It has no analytics, advertising, account system, cloud service, or network client. Preferences are stored in the app's local `UserDefaults` domain.

Power readings are used for the current display and short-lived local estimates; Drawstate does not keep a telemetry history. Preferences remain on the Mac until the user removes the app's local settings. Drawstate has no server-held data to request or delete, and no data-collection consent to revoke. Users can turn off optional launch at login in Drawstate Settings or macOS Login Items. For help removing local preferences, contact support through the issue tracker below without posting private device details.

Drawstate Direct's optional experimental charge-limit control invokes an on-device macOS Smart Charge service. No charge information leaves the Mac. The sandboxed Mac App Store edition does not contain this control or its bridge.

Privacy questions can be filed through the public [Drawstate issue tracker](https://github.com/Kian-hdr/Drawstate/issues) without including logs or device details you do not want to share.
