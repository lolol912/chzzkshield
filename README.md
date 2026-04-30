# CHZZKShield iOS Tweak

`chzzk_tweak` is an independent iOS tweak project for CHZZK (치지직).
It does not require `twitch_tweak` at runtime.

## Features

- Block ad-related requests at URL request stage (before server response)
- Stub `/ad-polling/` endpoints with fixed JSON response
- Auto-click skip button in WKWebView when ad UI appears
- Build `.deb` and `.dylib` via Theos
- Inject `.dylib` into user-supplied IPA via GitHub Actions

## Core Behavior

### 1) Pre-response blocking

`NSURLProtocol` + `NSURLSessionConfiguration` hook inserts `CHZZKAdBlockURLProtocol`.
The protocol inspects URL host/path/query and:

- returns a fixed JSON response for `ad-polling`
- cancels known ad requests immediately

### 2) Auto skip button click

`WKWebView` hooks inject JavaScript that:

- repeatedly searches skip button selectors
- auto clicks `button[data-role='skipBtn']` and fallback selectors
- patches `fetch`/`XMLHttpRequest` for `/ad-polling/` in web contexts

## Build (Local)

```bash
export THEOS=/opt/theos
make clean
make package DEBUG=0 FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

or:

```bash
bash build.sh
```

## GitHub Actions

- `Build CHZZKShield iOS`
  - builds `.deb` + `.dylib`
  - uploads artifacts
  - creates release on push to `main/master`

- `Inject CHZZKShield into IPA`
  - downloads user IPA URL
  - builds tweak dylib
  - injects dylib into IPA
  - uploads generated IPA to draft release

## Bundle Filter

Substrate bundle targets are defined in `CHZZKShield.plist`.
If no log appears, check real app bundle identifier and add it there.

Expected log:

```bash
[CHZZKShield] Tweak loaded in bundle: ...
```

## File Layout

```text
chzzk_tweak/
├── Tweak.x
├── Makefile
├── control
├── CHZZKShield.plist
├── build.sh
└── .github/workflows/
    ├── build.yml
    └── inject_ipa.yml
```

## Notes

- CHZZK app updates can change ad endpoints/selectors; pattern updates may be required.
- This is an unofficial project and is not affiliated with NAVER or CHZZK.
- Users are responsible for complying with app terms and local law.
