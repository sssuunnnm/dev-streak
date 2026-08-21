# Daily Dev Draft — Product Specification

## 1. Overview

Daily Dev Draft는 개인 개발 블로그 작성 습관을 만들기 위한
iOS companion application이다.

이 앱의 핵심 목표는 블로그를 직접 관리하거나 배포하는 것이 아니라,

"하루에 최소 하나의 개발 관련 기록을 남기는 습관"

을 형성하는 것이다.

실제 글 작성, 검수 및 블로그 관리는 기존 Claude 기반 workflow를 유지한다.

Daily Dev Draft는 다음 역할에 집중한다.

- 오늘 작성 여부 추적
- 연속 작성일(Streak) 관리
- 작성 리마인드
- 글감(Idea) 저장
- Claude로 글쓰기 작업 Hand-off
- Widget을 통한 작성 현황 노출
- 향후 GitHub 활동을 이용한 작성 여부 자동 검증

---

# 2. Core Principles

## 2.1 Not a Blog CMS

이 앱은 블로그 CMS가 아니다.

앱에서 다음 기능을 구현하지 않는다.

- 블로그 직접 배포
- 블로그 콘텐츠 직접 수정
- GitHub repository write
- Pull Request 생성
- 블로그 디자인 관리

실제 블로그 관리는 기존 Claude workflow에서 수행한다.

## 2.2 Companion App

앱의 역할은 글을 직접 관리하는 것이 아니라

"오늘 글을 쓰도록 유도하는 것"

이다.

## 2.3 Local First

초기 버전은 외부 서버 없이 동작한다.

사용:

- SwiftUI
- SwiftData
- WidgetKit
- UserNotifications
- App Groups

GitHub 연동은 이후 버전에서 추가한다.

---

# 3. Target Platform

Platform:
- iOS

UI:
- SwiftUI

Persistence:
- SwiftData

Widget:
- WidgetKit

Notification:
- UserNotifications

Minimum iOS Version:
- 프로젝트 생성 시 확정

---

# 4. Main User Flow

## Morning

앱 또는 Widget에서 오늘 작성 상태를 확인한다.

Example:

Today
0 / 1

🔥 7 day streak

Write something today.

## During the Day

글감이 떠오르면 Idea Inbox에 기록한다.

Example:

Title:
SwiftData와 Widget 데이터 공유

Notes:
- App Group
- WidgetCenter.reloadTimelines
- 구현 중 발생한 문제

Tags:
swift, ios

## Writing

Idea를 선택하고 "Write with Claude"를 실행한다.

앱은 Claude에 전달할 Prompt를 생성한다.

Prompt에는 다음 정보가 포함될 수 있다.

- Topic
- Notes
- Tags
- 블로그 작성 목적
- repository conventions 준수 요청

Prompt example:

Dev Archive에 다음 주제로 글을 작성하려고 합니다.

주제:
{idea.title}

메모:
{idea.notes}

태그:
{idea.tags}

CONVENTIONS.md와 DESIGN_RULES.md의 규칙을 따라주세요.
기존 Dev Archive의 글 스타일과 구조도 참고해주세요.

Prompt를 Clipboard에 복사한 뒤 Claude로 이동한다.

## Completion

V1에서는 사용자가 직접:

"오늘 작성 완료"

버튼을 누른다.

완료되면 DailyRecord가 생성되고 Streak가 갱신된다.

---

# 5. Dashboard

Dashboard는 앱 실행 시 가장 먼저 표시되는 화면이다.

표시 정보:

- 오늘 날짜
- 오늘 목표 상태 (0/1 또는 1/1)
- 현재 Streak
- Best Streak
- 오늘 작성 버튼
- Idea Inbox shortcut
- 최근 활동

Example:

Daily Dev

Today

0 / 1

No writing activity yet.

[ Write Today ]

🔥 7 day streak
🏆 Best 14 days

Ideas
3 waiting

---

# 6. Daily Goal

기본 목표:

1 content activity / day

V1에서는 수동 완료를 지원한다.

DailyRecord status:

- pending
- manualCompleted
- githubVerified

manualCompleted:
사용자가 직접 작성 완료를 기록한 상태.

githubVerified:
향후 GitHub activity detector가 실제 콘텐츠 커밋을 확인한 상태.

---

# 7. Streak

Streak는 연속으로 Daily Goal을 달성한 날짜 수이다.

Example:

Aug 18 ✓
Aug 19 ✓
Aug 20 ✓
Aug 21 ✓

Current Streak = 4

Streak 계산은 local calendar date 기준으로 수행한다.

Timezone 변화와 날짜 경계를 고려해야 한다.

---

# 8. Calendar

월 단위 작성 기록을 표시한다.

Example:

M T W T F S S

✓ ✓ ✓ ✓ ✓ ✓ ✓
✓ ✓ ✓ ✓ ✓ · ✓
✓ ✓ ✓ ✓ ●

표시:

✓ Goal completed
● Today completed
○ Today pending
· No activity

---

# 9. Idea Inbox

간단한 글감 저장 기능이다.

Idea model:

- id
- title
- notes
- tags
- createdAt
- updatedAt
- status

status:

- inbox
- used
- archived

기능:

- Idea 추가
- 수정
- 삭제
- Archive
- Claude Hand-off

---

# 10. Claude Hand-off

Claude API를 앱에 직접 통합하지 않는다.

기존 Claude mobile / desktop workflow를 유지한다.

앱에서는:

1. Prompt 생성
2. Clipboard 복사
3. 가능한 경우 Claude 실행
4. 사용자가 Claude에서 글 작성

방식을 사용한다.

---

# 11. Notifications

앱의 핵심 기능 중 하나이다.

오늘 Daily Goal이 완료되지 않은 경우에만
리마인드를 제공한다.

Notification 단계 예시:

Morning:
"오늘 하나 기록해볼까요?"

Evening:
"오늘 아직 기록이 없어요. 저장해둔 아이디어가 있어요."

Night:
"🔥 현재 Streak가 오늘 끊길 수 있어요."

목표 완료 후에는 해당 날짜의 추가 reminder를 취소한다.

사용자가 reminder 시간을 설정할 수 있도록 한다.

---

# 12. Widget

## Small Widget

표시:

- Today 0/1
- Current Streak
- Write shortcut

Example:

DAILY DEV

   0 / 1

🔥 7 days

Write →

## Completed

DAILY DEV

   ✓ 1 / 1

🔥 8 days

Widget과 main app은 App Group을 통해 필요한 상태를 공유한다.

Daily Goal 변경 후 Widget timeline을 reload한다.

---

# 13. GitHub Integration — Future Version

GitHub는 블로그 관리 목적이 아니라

"오늘 실제 콘텐츠 작성 활동이 있었는가"

를 검증하는 데이터 소스로 사용한다.

GitHub integration은 READ ONLY를 원칙으로 한다.

앱에서 repository를 수정하지 않는다.

---

# 14. GitHub Activity Detection

IMPORTANT:

다음 값을 작성 여부 판단에 사용하지 않는다.

- frontmatter `draft`
- frontmatter `date`
- branch naming convention
- PR 존재 여부만으로 판단
- main branch commit만으로 판단

작성 완료 판단의 핵심은:

"오늘 발생한 commit 중
콘텐츠 경로를 실제로 변경한 commit이 존재하는가?"

Target paths:

src/content/articles/**
src/content/projects/**
src/content/references/**
src/content/snippets/**

Detection 대상:

- main
- open Pull Requests
- relevant working branches

각 commit의 changed files를 확인한다.

---

# 15. GitHub Detection Rules

다음은 반드시 지켜야 한다.

## Rule 1

`draft` field를 기준으로 판단하지 않는다.

일부 content type에는 draft field가 존재하지 않는다.

## Rule 2

frontmatter `date`를 작성 날짜로 사용하지 않는다.

date는 publish 시점에 변경될 수 있다.

## Rule 3

main branch만 검사하지 않는다.

글 작업이 PR review 중일 수 있다.

## Rule 4

branch 이름으로 콘텐츠 작업 여부를 판단하지 않는다.

예:

feat/*
fix/*
claude/*

어떤 형태든 가능하다.

## Rule 5

PR 또는 branch 존재 자체로 완료 처리하지 않는다.

반드시 commit changed files를 검사한다.

---

# 16. GitHub Verification Result

GitHub에서 콘텐츠 활동이 확인되면:

DailyRecord.status = githubVerified

Example:

Today

✓ Writing detected

Article updated
21:14

🔥 8 day streak

수동 완료 후 GitHub activity가 나중에 발견된 경우:

manualCompleted
→ githubVerified

로 승격할 수 있다.

---

# 18. Development Phases

## Phase 1 — Foundation

- SwiftUI application
- SwiftData local persistence
- DailyRecord
- Dashboard
- Manual daily completion
- Current streak
- Best streak
- Unit tests for streak/date logic

## Phase 2 — Habit Tracking

- Calendar
- Monthly completion rate
- Notifications
- Reminder settings

## Phase 3 — Idea Inbox

- Idea CRUD
- Tags
- Claude hand-off
- Clipboard prompt generation

## Phase 4 — Widget

- Small Widget
- Today status
- Current streak
- Write shortcut
- App Group

## Phase 5 — GitHub Verification

- Read-only GitHub authentication
- Commit activity detection
- main + open PR inspection
- changed-file inspection
- githubVerified status
