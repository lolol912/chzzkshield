# CHZZKShield iOS Tweak

Repository: <https://github.com/lemonflare/chzzkshield>

CHZZKShield is an iOS tweak for the CHZZK (치지직) iOS app. It blocks ad-related requests at the native networking layer, returns a fixed response for CHZZK ad-polling endpoints, and auto-clicks skip buttons when ad UI appears.

CHZZK iOS is not guaranteed to be a pure web userscript path. Because of that, this project focuses on native Objective-C hook points such as `NSURLSessionConfiguration`, `NSURLSession`, and `NSURLProtocol`, with `WKWebView` injection used as a best-effort helper.

## Features

- Native URL request pre-blocking for known ad patterns
- Fixed `/ad-polling/` JSON stub response
- Best-effort skip button auto click (`WKWebView` path)
- GitHub Actions workflow for IPA injection

## Limits

- This is not a full app reverse-engineering based blocker.
- If CHZZK changes endpoint paths/selectors, updates may be required.
- `WKWebView` auto-click works only where webview-based UI exists.
- This repository does not provide IPA files.

## Quick Start

### Korean

가장 쉬운 사용 방법은 GitHub Actions의 IPA 인젝터를 사용하는 것입니다.

1. CHZZK IPA를 직접 준비합니다.
2. 이 레포의 `Actions` 탭으로 이동합니다.
3. `Inject CHZZKShield into IPA` 워크플로를 선택합니다.
4. `Run workflow`를 누릅니다.
5. `ipa_url`에 본인이 준비한 복호화 IPA의 다운로드 URL을 넣습니다.
6. `bundle_id`는 특별한 이유가 없으면 비워둡니다.
7. 워크플로가 끝나면 draft Release에 생성된 IPA가 올라갑니다.

`bundle_id`를 임의로 바꾸면 로그인, 채팅, 키체인, app group 상태가 깨질 수 있습니다.

### English

The easiest way to use this project is the GitHub Actions IPA injector.

1. Prepare your own CHZZK IPA.
2. Open the `Actions` tab in this repository.
3. Select the `Inject CHZZKShield into IPA` workflow.
4. Click `Run workflow`.
5. Put the download URL of your decrypted IPA into `ipa_url`.
6. Leave `bundle_id` empty unless you intentionally need to override it.
7. When the workflow finishes, the generated IPA will be attached to a draft Release.

If you change the `bundle_id`, CHZZK login, chat, keychain, and app-group state can break.

## Step-by-Step Usage

### Korean

#### 1. 필요한 것

- GitHub 계정
- 직접 구한 CHZZK IPA
- IPA를 설치할 방법
  - TrollStore
  - Sideloadly
  - AltStore

#### 2. GitHub에서 IPA 생성하기

1. 레포 페이지를 엽니다.
   - <https://github.com/lemonflare/chzzkshield>
2. 상단의 `Actions` 탭을 누릅니다.
3. 왼쪽 목록에서 `Inject CHZZKShield into IPA`를 선택합니다.
4. `Run workflow` 버튼을 누릅니다.
5. 항목을 입력합니다.
   - `ipa_url`: 직접 준비한 복호화 IPA 주소
   - `app_name`: 보통 기본값 그대로 사용
   - `bundle_id`: 보통 비워둠
   - `display_name`: 생성될 IPA 이름
6. 실행 후 완료될 때까지 기다립니다.
7. draft Release에서 결과 IPA를 받습니다.

#### 3. 생성된 IPA 설치하기

- TrollStore 사용 시: 생성된 IPA를 기기에 옮긴 뒤 TrollStore로 설치
- Sideloadly / AltStore 사용 시: PC에서 생성된 IPA를 불러와 설치

#### 4. 설치 후 확인하기

- CHZZK 앱을 실행합니다.
- 라이브를 열어 광고 동작과 재생 상태를 확인합니다.
- 문제가 있으면 아래 디버깅 로그를 확인합니다.

### English

#### 1. What you need

- A GitHub account
- Your own CHZZK IPA
- A way to install the generated IPA
  - TrollStore
  - Sideloadly
  - AltStore

#### 2. Generate the IPA on GitHub

1. Open the repository.
   - <https://github.com/lemonflare/chzzkshield>
2. Click the `Actions` tab.
3. Select `Inject CHZZKShield into IPA` from the left sidebar.
4. Click `Run workflow`.
5. Fill the fields.
   - `ipa_url`: URL to your decrypted IPA
   - `app_name`: usually keep the default
   - `bundle_id`: usually leave empty
   - `display_name`: output IPA name
6. Wait for the workflow to finish.
7. Download the IPA from the draft Release.

#### 3. Install the generated IPA

- With TrollStore: transfer the IPA to the device and install it
- With Sideloadly / AltStore: load the IPA from your PC and install it

#### 4. Verify after install

- Open the CHZZK app.
- Start a stream and check ad behavior and playback.
- If something breaks, use the debug steps below.

## Local Build

This repository also includes a normal Theos build for `.deb` packaging.

### Korean

`deb` 패키지가 필요한 경우:

1. macOS 또는 Linux/WSL 환경을 준비합니다.
2. Theos와 iOS SDK를 설치합니다.
3. 아래 명령을 실행합니다.

```bash
export THEOS=/opt/theos
make clean
make package DEBUG=0 FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

또는:

```bash
bash build.sh
```

### English

If you want a `.deb` package:

1. Prepare macOS or Linux/WSL.
2. Install Theos and an iOS SDK.
3. Run:

```bash
export THEOS=/opt/theos
make clean
make package DEBUG=0 FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

Or:

```bash
bash build.sh
```

The package version starts at `1.0.0` and is read from `control`.

## Debugging

On device:

```bash
log stream --predicate 'eventMessage CONTAINS "CHZZKShield"' --level debug
```

Expected logs:

- `[CHZZKShield] Tweak loaded in bundle: ...`
- `[CHZZKShield] Stubbed ad-polling response: ...`
- `[CHZZKShield] Blocked ad request: ...`

## Troubleshooting

### Korean

- 광고가 계속 보이면 CHZZK 앱 업데이트로 엔드포인트/패턴이 변경되었을 수 있습니다.
- 로그가 전혀 없으면 `CHZZKShield.plist`의 bundle ID가 실제 앱과 다른지 확인합니다.
- 웹뷰 기반 화면이 아닌 경우 skip 버튼 자동 클릭 훅은 동작하지 않을 수 있습니다.
- `bundle_id`를 변경했다면 로그인/채팅 문제가 먼저 발생할 수 있습니다.

### English

- If ads still appear, CHZZK may have changed endpoint paths/patterns.
- If no logs appear, verify real app bundle ID against `CHZZKShield.plist`.
- Skip auto-click may not run on non-webview paths.
- If you changed `bundle_id`, check login/chat state first.

## Project Layout

```text
chzzkshield/
├── Tweak.x                          # Native Objective-C hook implementation
├── Makefile                         # Theos build configuration
├── control                          # Debian package metadata
├── CHZZKShield.plist                # Substrate filter
├── build.sh                         # Local DEB build helper
├── .github/workflows/build.yml      # Build DEB/dylib release artifacts
└── .github/workflows/inject_ipa.yml # GitHub Actions IPA injection workflow
```

## Disclaimer

### English

- This project is provided for educational and research purposes only.
- You are solely responsible for any consequences, including account suspension, access restrictions, bans, or legal liability, that may arise from using this tool in violation of CHZZK terms or any applicable law.
- This repository is not affiliated with NAVER Corporation or CHZZK.
- This repository does not provide, host, or distribute modified app packages (`.ipa` files), decrypted app binaries, or CHZZK copyrighted/trademark assets.
- The GitHub IPA injector workflow requires a user-supplied IPA URL and creates user-generated draft output. Do not publish generated IPA releases unless you have the legal right to distribute them.
- The software is provided "as is", without warranty of any kind.

### Korean

- 이 프로젝트는 교육 및 연구 목적으로만 작성되었습니다.
- 이 도구를 사용하면서 발생하는 계정 정지, 차단, 접근 제한, 법적 책임은 전적으로 사용자 본인에게 있습니다.
- 이 레포지토리는 NAVER Corporation 또는 CHZZK와 관련이 없습니다.
- 이 레포지토리는 변조된 `.ipa`, 복호화 앱 바이너리, CHZZK 저작권 자료 또는 상표 자산을 배포하지 않습니다.
- GitHub IPA 인젝터 워크플로는 사용자가 제공한 IPA URL을 바탕으로 draft 결과물을 생성합니다. 배포 권한이 없는 IPA를 공개하지 마세요.
- 이 소프트웨어는 어떠한 보증도 없이 제공됩니다.

## References

- Theos: <https://theos.dev>

## License

MIT