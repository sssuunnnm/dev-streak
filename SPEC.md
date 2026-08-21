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

### Daily Status Rules

하루의 상태는 다음 네 가지로 해석한다.

1. completed

- 해당 날짜에 Daily Goal을 완료한 상태
- manualCompleted 또는 githubVerified 기록이 존재
- 단, 오늘보다 미래 날짜는 완료 기록이 존재하더라도 future로 취급한다.

2. missed

- 이미 종료된 과거 날짜인데 완료 기록이 없는 상태

3. pending

- 오늘 날짜이며 아직 완료 기록이 없는 상태
- 오늘은 아직 진행 중이므로 실패로 간주하지 않는다.

4. future

- 오늘보다 미래 날짜
- 완료 record가 존재하더라도 future로 취급
- monthly completion rate 분자/분모에서 항상 제외
- missed/pending으로 표시하지 않음

중요:

- 오늘 미작성 상태를 missed로 처리하지 않는다.
- 오늘 미작성 때문에 월간 달성률이 떨어지면 안 된다.
- 미래 날짜는 달성률 계산 대상이 아니다.
- 미래 날짜는 missed 또는 pending으로 처리하지 않는다.

### Monthly Completion Rate Rules

오늘이 아직 미완료라면:

- 오늘은 월간 달성률 계산에서 제외한다.
- 종료된 과거 날짜만 분모로 사용한다.

예:
8월 21일이고,
8월 1~20일 중 17일을 완료했으며
오늘 21일은 아직 미완료라면:

17 / 20 = 85%
Today = pending

오늘 21일을 완료하면:

- 오늘을 completed로 포함한다.
- 분모에도 오늘을 포함한다.

18 / 21 ≈ 85.7%
Today = completed

즉 현재 날짜는 완료된 경우에만 월간 달성률 계산에 포함한다.

미래 날짜는 항상 제외한다.

### Relationship with Streak

기존 Phase 1 규칙을 유지한다.

- 오늘 pending이라는 이유만으로 current streak를 끊지 않는다.
- 어제까지 연속 완료했다면 오늘 미완료 상태에서도 해당 streak를 유지한다.
- 날짜가 넘어가 이전 날짜가 missed로 확정되었을 때 streak가 끊긴다.

### Notification Rules

목적:
사용자가 하루에 최소 하나의 개발 기록을 남기도록 리마인드한다.

기본 Reminder 슬롯:

- Morning: 09:00
- Evening: 18:00
- Night: 22:00

각 reminder는:

- 개별 enable / disable 가능
- 사용자가 시간을 변경 가능
- local notification으로 동작
- 서버나 backend를 사용하지 않음

### Relationship with Daily Completion

오늘 Daily Goal을 완료한 경우:

- 오늘 날짜의 Morning / Evening / Night pending reminder notification만 제거한다.
- 미래 날짜 reminder는 유지한다.
- 이미 전달된 notification은 건드리지 않는다.
- 오늘 추가 reminder를 다시 예약하지 않는다.

다음 날이 되면:

- 이미 예약된 rolling notification schedule에 따라 enabled reminder가 정상적으로 동작한다.
- 앱이 다시 실행되거나 활성화되면 현재 설정 기준으로 rolling schedule을 다시 동기화한다.

오늘 미완료인 경우:

- enabled reminder는 설정된 시간에 동작한다.

### Permission Rules

- 앱이 처음 실행되자마자 notification permission을 요청하지 않는다.
- Settings 화면에 notification authorization 상태를 명확히 표시한다.
- notDetermined 상태에서는 "알림 허용하기" action을 제공한다.
- 사용자가 해당 action을 명시적으로 눌렀을 때 requestAuthorization을 실행한다.
- permission이 denied된 경우 앱이 crash하거나 반복 요청하지 않는다.
- denied 상태에서는 알림이 시스템 설정에서 비활성화되어 있음을 명확히 표시한다.
- denied 상태에서는 가능한 경우 iOS Settings로 이동할 수 있는 action을 제공한다.
- authorized / provisional / ephemeral 상태에서는 현재 reminder preferences를 기준으로 notification을 예약한다.
- reminder preference enabled 값과 notification authorization 상태는 서로 독립적으로 유지한다.
- permission이 없어도 reminder preference 변경은 저장할 수 있지만 실제 notification은 예약하지 않는다.

### Scheduling Rules

- UNUserNotificationCenter를 사용한다.
- local notification만 사용한다.
- 오늘 날짜와 timezone을 명시적으로 고려한다.
- 기본 scheduling horizon은 오늘을 포함하여 앞으로 14일이다.
- Morning / Evening / Night가 모두 활성화되어 있으면 최대 3 * 14 = 42개의 notification request를 관리한다.
- identifier는 날짜 기반 구조를 사용한다.
- 예: devstreak.reminder.morning.2026-08-22
- 이미 지난 시간의 오늘 reminder는 예약하지 않는다.
- 미래 날짜는 enabled reminder를 정상 예약한다.
- 오늘 Daily Goal이 completed이면 오늘 reminder는 예약하지 않는다.
- 미래 날짜 reminder는 오늘 완료 여부와 관계없이 유지한다.
- 오늘 goal을 완료하면 오늘 날짜 identifier만 취소한다.
- 미래 날짜 notification은 취소하지 않는다.
- 중복 notification request를 만들지 않는다.
- 설정 변경 시 DevStreak가 관리하는 pending reminder를 정리하고 새 설정 기준으로 14일 rolling horizon을 다시 채운다.
- 앱 실행/활성화 시 필요한 경우 현재 설정 기준으로 14일 rolling schedule을 동기화한다.
- 사용자가 다음 날 앱을 실행하지 않아도 이미 예약된 notification이 정상적으로 동작해야 한다.

### Notification Content

Morning 예시:
"오늘 하나 기록해볼까요?"

Evening 예시:
"오늘 아직 기록이 없어요. 짧게라도 하나 남겨볼까요?"

Night 예시:
"오늘의 기록이 아직 없어요. Streak가 끊기기 전에 하나 남겨보세요."

문구는 Phase 2B에서는 고정 문자열로 두어도 된다.
디자인/카피 refinement는 추후 수행한다.

### Reminder Settings

Settings 화면에서 다음을 관리한다.

- Morning reminder enabled
- Morning reminder time
- Evening reminder enabled
- Evening reminder time
- Night reminder enabled
- Night reminder time

초기 기본값:

- Morning: enabled, 09:00
- Evening: enabled, 18:00
- Night: enabled, 22:00

설정은 local persistence를 사용한다.

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
