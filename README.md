# NX Games Launcher

[nxnative](https://github.com/seedds/nxnative)로 변환한 Switch 게임 여러 개를 **iPhone/iPad 앱 하나**에 담아, 런처에서 골라 실행하는 프로젝트입니다. 무료 개인 팀(Personal Team)은 앱 개수 제한이 있는데, 게임마다 앱을 따로 설치하지 않아도 됩니다.

변환은 nxnative가 그대로 합니다. 이 저장소에는 다음만 들어 있습니다.

- 런처 앱 (SwiftUI)
- nxnative를 git submodule로 가져와 쓰는 스크립트
- 런처에 필요한 nxnative 수정분 (`patches/nxnative.patch`)

> 게임, 키, 게임에서 뽑아낸 파일은 이 저장소에 없습니다. 본인이 소유한 게임과 본인 기기에서 덤프한 `prod.keys`만 사용하세요. Nintendo나 게임 배급사와는 관계없는 프로젝트입니다.

## 기능

- 게임 목록: 리스트 또는 그리드(아이콘·이름·버전). 이름은 기기 언어에 맞춰 표시됩니다.
- 게임별 설정: nxnative 게임 설정 화면과 같은 항목을 실행 전에 바꿀 수 있습니다.
- 버튼 배열: Nintendo / Xbox 배열 선택. 터치와 패드를 통합해서 쓰거나 따로 설정할 수 있습니다.
- 컨트롤러 조작: 런처와 옵션 화면 모두 컨트롤러로 다룰 수 있습니다.
- 인게임 터치 버튼 편집: 2D/3D 버튼을 길게 누르면 버튼을 옮기고(드래그) 크기를 바꿀 수 있습니다(핀치). 게임별로 저장됩니다.
- 언어(한국어/English), 라이트/다크 모드.
- 코드만 업데이트: 게임 데이터(romfs, DLC 등)는 앱 데이터 영역에 한 번만 보냅니다. 재서명이나 코드 수정 때는 앱 부분만 다시 설치하므로 데이터와 세이브가 유지됩니다.

## 구조

```
nxnative/            원본 nxnative (submodule, 고정 커밋)
patches/             런처용 nxnative 수정분 (setup.sh가 적용)
app/                 런처 앱 소스 (XcodeGen)
stub/                서명 프로파일을 받기 위한 빈 앱
tools/               빌드·조립·서명·설치 스크립트
env/                 게임별 추가 설정 (예: botw.txt)
config.example.sh    → config.sh (팀 ID, 서명 ID, 기기 UDID, 키 경로)
games.example.tsv    → games.tsv (게임 이름, 게임 폴더, 빌드 옵션)
```

nxnative 패치의 주요 내용:

- 게임을 프레임워크(dylib)로 빌드하는 모드 (`DM_AS_DYLIB`, `dm_framework_boot`)
- 게임별 설정 저장
- 터치 버튼 편집과 Xbox 배열
- 통합 NSP(본편+업데이트+DLC 한 파일) 지원
- BotW 프레임 제한 옵션(`DM_FPS_KEEP60`, `DM_FPS_HOLD_MAX`)
- 동시 빌드 잠금

## 준비

macOS, Xcode 26, iOS/iPadOS 26 이상(A17 Pro / M1 이상 기기)이 필요합니다.

```bash
brew install xcodegen zstd glslang
```

```bash
brew install --cask dotnet-sdk
```

```bash
git clone --recursive https://github.com/songhj0728/nxgames-launcher.git && cd nxgames-launcher && ./setup.sh
```

`config.sh`와 `games.tsv`를 채웁니다. 게임 폴더에는 그 게임의 NSP(본편, 업데이트, DLC)를 넣어 둡니다.

## 사용

```bash
tools/renew_profile.sh
```

```bash
tools/build_launcher.sh
```

```bash
tools/build_game.sh botw
```

```bash
tools/assemble.sh botw=build/botw.ipa
```

- 여러 게임: `tools/assemble.sh botw=build/botw.ipa acnh=build/acnh.ipa`
- 코드만 수정: `CODE_ONLY=1 tools/build_game.sh botw` → `tools/assemble.sh botw=build/botw.app`. 기기의 게임 데이터는 그대로 둡니다.
- 재서명(무료 팀은 7일마다): `tools/renew_profile.sh` → `tools/assemble.sh` (인자 없이)
- iPad: 각 명령 앞에 `DEVICE=ipad`

`assemble.sh`는 서명 전에 `verify_fw.py`로 각 프레임워크의 코드가 그 게임의 빌드와 일치하는지 확인합니다. 빌드가 섞이면 서명을 멈춥니다.

## nxnative 버전 올리기

```bash
git -C nxnative stash && git -C nxnative fetch && git -C nxnative checkout <커밋> && git -C nxnative stash pop
```

충돌이 없으면 수정분을 다시 저장합니다.

```bash
git -C nxnative diff > patches/nxnative.patch && git add nxnative patches
```

## 라이선스

MIT. nxnative도 MIT입니다 (© seedds).
