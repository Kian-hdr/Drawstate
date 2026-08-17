# Privacy

Drawstate processes power and battery telemetry locally on the Mac where it runs.

When a compatible USB HID/UPS power bank is connected, Drawstate may read its locally published battery status and public USB identity descriptors. This information is displayed on the Mac and is not stored as a history or transmitted.

Drawstate does not collect, transmit, sell, or share personal data. It has no analytics, advertising, account system, cloud service, or network client. Preferences are stored in the app's local `UserDefaults` domain.

Drawstate Direct's optional experimental charge-limit control invokes an on-device macOS Smart Charge service. No charge information leaves the Mac. The sandboxed Mac App Store edition does not contain this control or its bridge.

Privacy questions can be filed through the public [Drawstate issue tracker](https://github.com/Kian-hdr/Drawstate/issues) without including logs or device details you do not want to share.
