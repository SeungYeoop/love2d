# STRUCTURE

## 현재 구조
```text
.
|-- main.lua              # 진입점 — 씬 등록 + LÖVE 콜백 위임만
|-- conf.lua              # 창 크기, 타이틀, vsync, MSAA 설정
|-- play.cmd              # 한 번 실행 (Ctrl+Shift+B)
|-- watch.cmd             # 파일 변경 감지 + 자동 재실행
|-- AI_WORKFLOW.md
|-- PROJECT_RULES.md
|-- STRUCTURE.md
|-- TASK.md
|-- SESSION_SUMMARY.md
|-- README.md
|-- .vscode/
|   `-- tasks.json        # Ctrl+Shift+B → play.cmd 연결
|-- scripts/
|   |-- relaunch-love.ps1 # 비-ASCII 경로 우회 미러 + PID 관리
|   `-- watch-love.ps1    # FileSystemWatcher + debounce
|-- src/
|   |-- scenes/
|   |   |-- scene_manager.lua  # switch / register + 모든 콜백 위임
|   |   |-- title.lua          # 타이틀 화면
|   |   `-- game.lua           # 게임 화면 (예시: 별 수집)
|   `-- utils/
|       `-- vector.lua         # 2D 벡터 (new, +, -, *, normalize, lerp …)
|-- assets/
|   |-- fonts/            # .ttf / .otf
|   |-- images/           # .png / .jpg
|   `-- sounds/           # .ogg / .wav
`-- prompts/
    |-- one_shot.md
    |-- iterate.md
    |-- plan.md
    |-- refactor.md
    |-- debug.md
    `-- ui.md
```

## 현재 파일 역할
- `main.lua`: 씬 등록과 LÖVE 콜백 위임만. 로직 없음.
- `conf.lua`: 창 설정 (800×600, vsync, MSAA 4).
- `src/scenes/scene_manager.lua`: `register` / `switch` / 모든 LÖVE 콜백 프록시.
- `src/scenes/title.lua`: 타이틀 화면. SPACE → game 씬 전환.
- `src/scenes/game.lua`: 별 수집 예시 게임. WASD/화살표, R 재시작, ESC → title.
- `src/utils/vector.lua`: 2D 벡터 — `V(x,y)`, `+`, `-`, `*`, `normalize`, `lerp`, `dist`, `fromAngle`.
- `assets/`: 폰트, 이미지, 사운드 보관 폴더.
- `scripts/relaunch-love.ps1`: 비-ASCII 경로 우회(C:\love2drun 미러) + PID 기반 프로세스 교체.
- `scripts/watch-love.ps1`: FileSystemWatcher + 500 ms debounce.
- `prompts/*.md`: 시작용, 반복 개선용, 계획용, 디버그용 AI 요청 템플릿.

## 운영 구조 원칙
- 시작 요청은 `AI_WORKFLOW.md` + `prompts/one_shot.md` 조합을 기본으로 쓴다.
- 코드 수정 후에는 `play.cmd` 또는 `watch.cmd` 흐름으로 바로 결과를 확인한다.
- 세션이 바뀌어도 운영 문서만 읽으면 다음 AI가 맥락을 이어받을 수 있어야 한다.
- 프롬프트는 "처음부터 무엇을 만들지"와 "다음 라운드에 무엇을 개선할지"를 분리한다.

## 기능별 분리 원칙
- LÖVE2D 진입점 파일은 얇게 유지한다.
- 기능이 늘어나면 역할별 파일로 분리한다.
- 입력 처리, 상태 관리, 렌더링, 설정, 유틸은 가능하면 분리한다.
- 하나의 파일이 초기화 + 상태 + 입력 + 렌더링 + 데이터 저장까지 모두 맡지 않게 한다.
- 장면 전환이 생기면 scene/state 단위 분리를 우선 검토한다.
- 사운드, 충돌, UI/HUD, 적 AI도 커지면 별도 모듈로 뺀다.

## 권장 방향
```text
.
|-- main.lua              # 진입점
|-- README.md             # 시작 안내
|-- conf.lua              # 창 설정, 타이틀, 해상도
|-- src/
|   |-- game/             # 전체 게임 상태, 루프 보조
|   |-- input/            # 입력 처리
|   |-- render/           # 그리기 관련
|   |-- entities/         # 플레이어, 적, 오브젝트
|   |-- scenes/           # 타이틀, 플레이, 결과 화면 등
|   |-- ui/               # HUD, 버튼, 텍스트
|   |-- systems/          # 충돌, 스폰, 카메라 등
|   `-- utils/            # 공통 유틸
`-- prompts/
```

## LÖVE2D 기준 책임 분리
- `love.load`: 초기화, 리소스 준비, 시작 상태 설정
- `love.update`: 시간 기반 상태 업데이트
- `love.draw`: 화면 출력만 담당
- `love.keypressed` 등 입력 콜백: 입력 이벤트 전달
- 콜백 내부 로직이 커지면 관련 모듈에 위임

## 분리 판단 기준
- 같은 파일이 150~250줄 이상으로 커질 때
- 하나의 파일에서 책임이 2개 이상 섞일 때
- 특정 기능만 따로 테스트/수정하고 싶을 때
- 재사용 가능한 코드가 생길 때
- `love.update`나 `love.draw`가 길어져 한눈에 안 읽힐 때

## 주의
- 위 권장 구조는 바로 적용하지 않는다.
- 실제 분리는 사용자 승인 후, 최소 수정 단위로 진행한다.
- 템플릿이 자동 실행 스크립트를 포함하더라도, 게임 구조 변경은 여전히 작은 단위로 진행한다.

## TODO
- 실제 폴더 구조는 사용자 승인 후 적용
- `assets/`, `conf.lua`, `tests/` 필요 여부 확인
- 씬 관리 방식을 직접 구현할지 간단한 상태 테이블로 둘지 결정
