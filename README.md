# LÖVE2D Vibe Coding Template

LÖVE2D 프로젝트를 AI와 함께 빠르게 만들기 위한 템플릿이다. 목표는 짧은 게임 설명 하나로도 구조 잡힌 프로토타입을 먼저 만들고, 이후 AI가 다음 개선안을 추천하거나 꼭 필요한 질문만 하도록 작업 루프를 고정하는 것이다.

## 빠른 시작
1. 이 폴더를 VS Code로 연다.
2. 자동 미리보기를 원하면 터미널에서 `.\watch.cmd`를 실행한다.
3. AI에게 `AI_WORKFLOW.md`, `PROJECT_RULES.md`, `TASK.md`, `STRUCTURE.md`, `SESSION_SUMMARY.md`를 먼저 읽게 한다.
4. 첫 요청은 `prompts/one_shot.md` 템플릿을 복사해서 게임 설명만 채운다.
5. 후속 개선은 `prompts/iterate.md`를 사용한다.

## 추천 사용 흐름
1. `.\watch.cmd`를 한 번 켜 둔다.
2. AI에게 짧게 게임 설명과 현재 명령을 준다.
3. AI는 먼저 구조 잡힌 playable prototype을 만든다.
4. 코드 저장이 일어나면 watcher가 LÖVE2D를 자동 재실행한다.
5. 각 라운드가 끝나면 AI가 다음 개선 3개를 추천하거나, 꼭 필요한 질문만 짧게 한다.

## 실행 명령
- `.\watch.cmd`: 파일 변경을 감지하고 현재 프로젝트를 자동 재실행
- `.\play.cmd`: 지금 상태를 한 번만 다시 실행

## AI에게 보여줄 문서
- `AI_WORKFLOW.md`: AI가 따라야 하는 전체 제작 루프
- `PROJECT_RULES.md`: 협업 규칙과 변경 원칙
- `TASK.md`: 현재 템플릿의 작업 범위
- `STRUCTURE.md`: 운영 구조와 권장 코드 구조
- `SESSION_SUMMARY.md`: 다음 세션이 빠르게 이어받을 맥락
- `prompts/`: 시작용, 반복 개선용, 디버그용 프롬프트 템플릿

## 한 번에 시작하는 추천 프롬프트
아래 문장을 그대로 시작점으로 써도 된다.

```text
먼저 `AI_WORKFLOW.md`, `PROJECT_RULES.md`, `TASK.md`, `STRUCTURE.md`, `SESSION_SUMMARY.md`를 읽고 시작해줘.
짧은 설명만으로도 만족도 높은 LÖVE2D 프로토타입을 만들고 싶어.
필요 이상으로 묻지 말고, 막히지 않으면 합리적인 가정을 적고 바로 구조 잡힌 playable prototype부터 구현해줘.
작업이 끝나면 `.\play.cmd`를 실행하거나 watcher 기준으로 결과가 반영됐는지 확인해줘.
마지막에는 다음 개선 3개를 추천해주고 내가 직접 플레이할 수 있도록 게임 실행해줘.
```

## 메모
- 첫 결과물은 단순 이동 데모보다 "짧게라도 재미가 있는 vertical slice"를 목표로 하는 편이 좋다.
- 큰 구조 변경이 필요하면 바로 실행시키기보다 계획을 먼저 받는 편이 안전하다.
