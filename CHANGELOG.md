# Changelog

## [0.2.0](https://github.com/Hedgehogovich/getup/compare/v0.1.0...v0.2.0) (2026-05-29)


### Features

* B1 configurable snooze duration (5–30 min picker in Settings) ([4e716b4](https://github.com/Hedgehogovich/getup/commit/4e716b4cb09b9ad12f375dd6a616441338ba9087))
* B2 configurable reminder interval (5–120 min, anchored) ([6b8e876](https://github.com/Hedgehogovich/getup/commit/6b8e876a8855e845406237ca0349eb0bd620aa00))


### Bug Fixes

* fix VideoMediaView observer leak and wizard preview process leak ([b8dd9c5](https://github.com/Hedgehogovich/getup/commit/b8dd9c5cf2ba06dc1404c0fbf993f0498b558126))

## 0.1.0 (2026-05-26)


### Features

* app icon, native menu-bar SF Symbol, modal icons, Getup brand ([08543cc](https://github.com/Hedgehogovich/getup/commit/08543ccbaac7798647d67a2af299d6128c52558b))
* build universal binary (arm64 + x86_64) by default ([390cbf7](https://github.com/Hedgehogovich/getup/commit/390cbf7a3bef0fc79de04e41ad591534eac58ec0))
* Copy logs button in Settings → About for bug reports ([9d28986](https://github.com/Hedgehogovich/getup/commit/9d289860255df8e9763f36afd2dfef4d70ac6c7e))
* custom audio file picker in Settings → Audio ([de975c8](https://github.com/Hedgehogovich/getup/commit/de975c841ef43c78d0f574a4a9b4bda47eb7ce96))
* CustomMedia helper + Settings overlay-media fields ([2552ab4](https://github.com/Hedgehogovich/getup/commit/2552ab42f7731a8d8f33a6fcc34a180a9c58c97c))
* initial getup app — menu-bar hourly stand reminder ([2f17ee8](https://github.com/Hedgehogovich/getup/commit/2f17ee88b293d08ccf77c42aa0d443a19bd42c01))
* launch-time log rotation; rewrite saveLoopIfMissing comment ([12b32da](https://github.com/Hedgehogovich/getup/commit/12b32da0eac400551fa4b5dc80fdfb7a755b20ca))
* overlay auto-dismiss after configurable delay ([f596de9](https://github.com/Hedgehogovich/getup/commit/f596de90e045894b80f213b1c928dfd996f7350e))
* overlay restyle (glass + typography) + focus restoration + privacy toggle ([bff1844](https://github.com/Hedgehogovich/getup/commit/bff1844603437685eccd3a2be5139b9ff4d8c4ff))
* quiet hours — skip scheduled reminders in user-defined window ([3675cc4](https://github.com/Hedgehogovich/getup/commit/3675cc46638631f57c7b0420734107322b953637))
* render custom overlay media — image / GIF / video ([31be1e3](https://github.com/Hedgehogovich/getup/commit/31be1e31e1aeb7058136f7cc3e43c367d158edd2))
* snooze button on overlay (10 min) + 'S' keyboard shortcut ([1b3520d](https://github.com/Hedgehogovich/getup/commit/1b3520d694ff75d76313d07cb060aebc4a6fbd62))
* stoppable Preview button; stop on Settings close, app quit, and reminder fire ([68e7227](https://github.com/Hedgehogovich/getup/commit/68e722712a7d93570bd1e9ddb56ab3d3e3b660a8))
* translate el/ja/zh-Hans wizard step 3 + loop phrase ([0437cbc](https://github.com/Hedgehogovich/getup/commit/0437cbcc0d023e08a2e3dadf465e3ef806e28895))


### Bug Fixes

* keep Settings window open when toggling Show-in-Dock off ([6426bae](https://github.com/Hedgehogovich/getup/commit/6426bae83aa063787ca3ba3a58b9b3de91803d63))
* nonisolated StretchScheduler pure helpers for Swift 6 strict mode ([10e9915](https://github.com/Hedgehogovich/getup/commit/10e9915366910389fce617c3df8144fb37b3b15a))
* parseVoices comment + tab handling; tighten test seams for CI ([f2442b0](https://github.com/Hedgehogovich/getup/commit/f2442b0cddac0fb8be25c9c12aa2939dc3968b26))
* reschedule on fireMinute change (Combine willSet race) ([4562f21](https://github.com/Hedgehogovich/getup/commit/4562f2105ccf15af0ac0037ad81206e71cbd8b6d))
* skip stale scheduler + snooze fires beyond 5-min grace ([2c4b3da](https://github.com/Hedgehogovich/getup/commit/2c4b3dacb61e9520749a56124edfe2cd3f68b8ba))


### Miscellaneous Chores

* bootstrap release-please configs + version source-of-truth ([d6b5150](https://github.com/Hedgehogovich/getup/commit/d6b5150888dc34944645d9c62241b584d41f259c))
