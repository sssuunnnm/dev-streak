# DevStreak — Product Specification

## 1. Overview

DevStreak는 개인 GitHub 기록 습관을 유지하기 위한 iOS companion app이다.

이 앱의 핵심 목표는 블로그를 직접 관리하거나 배포하는 것이 아니라,

"하루에 최소 하나의 개발 관련 기록을 남기는 습관"

을 눈에 보이게 만들고 이어가도록 돕는 것이다.

실제 글 작성, 검수, 블로그 관리는 기존 Claude 기반 workflow와 블로그 repository workflow에서 수행한다. DevStreak는 다음 역할에 집중한다.

- 오늘 작성 여부 추적
- 연속 작성일 streak 관리
- 월간 작성 현황 표시
- 작성 리마인드
- 글감 idea 저장
- Claude로 글쓰기 작업 hand-off
- Widget을 통한 작성 현황 노출
- GitHub 활동을 이용한 read-only 작성 여부 검증

## 2. Core Principles

### 2.1 Not a Blog CMS

DevStreak는 블로그 CMS가 아니다.

앱에서 다음 기능을 구현하지 않는다.

- 블로그 직접 배포
- 블로그 콘텐츠 직접 수정
- GitHub repository write
- Pull Request 생성 또는 수정
- GitHub Actions 실행
- 블로그 디자인 관리

실제 블로그 관리는 기존 Claude workflow와 repository workflow에서 수행한다.

### 2.2 Companion App

앱의 역할은 글을 직접 관리하는 것이 아니라 "오늘 글을 쓰도록 유도하는 것"이다.

### 2.3 Local First

DevStreak는 외부 backend 없이 동작한다.

사용 기술:

- SwiftUI
- SwiftData
- WidgetKit
- UserNotifications
- App Groups
- Security / Keychain

앱 자체 backend, server-side scheduler, analytics SDK, tracking SDK는 사용하지 않는다.

### 2.4 Privacy First

DevStreak 개발자는 사용자의 작성 기록, idea, reminder 설정, GitHub token을 수집하거나 서버로 전송하지 않는다.

개인 데이터 처리 원칙:

- DailyRecord와 Idea는 기기 내 SwiftData에 저장한다.
- Reminder 설정은 기기 내 UserDefaults에 저장한다.
- Widget 공유 상태는 App Group UserDefaults에 최소 snapshot만 저장한다.
- GitHub token은 선택 사항이며 Keychain에만 저장한다.
- GitHub token은 read-only GitHub API request의 Authorization header에만 사용한다.
- token을 source code, log, error message, UserDefaults에 저장하거나 노출하지 않는다.
- Claude API를 직접 호출하지 않는다.
- 사용자가 작성한 idea/prompt를 앱 개발자 서버로 보내지 않는다.

## 3. Target Platform

Platform:

- iOS

Current project settings:

- Xcode with iOS 26.5 SDK
- iOS deployment target: 17.0

Targets:

- DevStreak
- DevStreakWidget
- DevStreakTests
- DevStreakUITests

Bundle identifiers:

- App: `com.sssuunnnm.DevStreakApp`
- Widget: `com.sssuunnnm.DevStreakApp.DevStreakWidget`

App Group:

- `group.com.sssuunnnm.DevStreakApp`

## 4. Main User Flow

### Morning

사용자는 앱 또는 Widget에서 오늘 작성 상태를 확인한다.

Example:

```text
Today
0 / 1

7 day streak

Write something today.
```

### During the Day

글감이 떠오르면 Idea Inbox에 기록한다.

Idea example:

```text
Title:
SwiftData와 Widget 데이터 공유

Notes:
- App Group
- WidgetCenter.reloadTimelines
- 구현 중 발생한 문제

Tags:
swift, ios
```

### Writing

사용자는 Idea를 선택하고 "Claude로 글쓰기"를 실행할 수 있다.

앱은 Idea의 title, notes, tags를 기반으로 prompt를 생성하고 clipboard에 복사한다. 가능한 경우 `https://claude.ai/` 열기를 시도한다.

Claude로 넘기는 행위만으로 Idea를 used 처리하지 않는다. 사용자가 명시적으로 "사용함" action을 수행했을 때만 Idea 상태를 used로 변경한다.

### Completion

사용자는 "오늘 기록 완료" action으로 수동 완료를 기록할 수 있다.

GitHub verification이 콘텐츠 경로 변경을 확인하면 해당 날짜의 DailyRecord를 `githubVerified`로 생성하거나 승격한다.

## 5. Dashboard

Dashboard는 앱 실행 시 가장 먼저 표시되는 중심 화면이다.

표시 정보:

- 오늘 날짜
- 오늘 Daily Goal 상태 (`0 / 1` 또는 `1 / 1`)
- 현재 streak
- best streak
- GitHub verification 상태
- 오늘 기록 완료 action
- Idea Inbox shortcut 및 대기 개수
- 이번 달 calendar
- 월간 completion rate

수동 완료는 confirmation alert를 거친 뒤 저장한다.

오늘이 아직 미완료인 상태는 missed로 처리하지 않으며, 오늘 pending이라는 이유만으로 어제까지 이어진 streak를 끊지 않는다.

## 6. Daily Goal and Records

기본 목표:

- 1 content activity / day

DailyRecord는 SwiftData `@Model`로 저장한다.

```swift
@Model
final class DailyRecord {
    @Attribute(.unique) var dateKey: String
    var statusRawValue: String
    var completedAt: Date?
    var createdAt: Date
}
```

DailyRecord status:

- `pending`
- `manualCompleted`
- `githubVerified`

Completed day로 계산되는 상태:

- `manualCompleted`
- `githubVerified`

`manualCompleted`는 사용자가 직접 작성 완료를 기록한 상태이다.

`githubVerified`는 GitHub verification이 실제 콘텐츠 경로 변경 commit을 확인한 상태이다.

수동 완료 후 GitHub activity가 나중에 발견된 경우 `manualCompleted`에서 `githubVerified`로 승격할 수 있다.

## 7. Streak

Streak는 연속으로 Daily Goal을 달성한 날짜 수이다.

계산 원칙:

- local calendar date 기준으로 계산한다.
- 오늘 완료 상태면 오늘부터 역방향으로 계산한다.
- 오늘 미완료라도 어제가 완료 상태면 어제까지의 streak를 유지한다.
- 과거 날짜가 missed로 확정되었을 때 streak가 끊긴다.
- timezone 변화와 날짜 경계를 명시적으로 고려한다.

Example:

```text
Aug 18 completed
Aug 19 completed
Aug 20 completed
Aug 21 completed

Current Streak = 4
```

## 8. Calendar and Monthly Rate

월 단위 작성 기록을 표시한다.

하루의 상태는 다음 네 가지로 해석한다.

1. `completed`

- 해당 날짜에 Daily Goal을 완료한 상태
- `manualCompleted` 또는 `githubVerified` 기록이 존재
- 단, 오늘보다 미래 날짜는 완료 기록이 존재하더라도 `future`로 취급

2. `missed`

- 이미 종료된 과거 날짜인데 완료 기록이 없는 상태

3. `pending`

- 오늘 날짜이며 아직 완료 기록이 없는 상태
- 오늘은 아직 진행 중이므로 실패로 간주하지 않음

4. `future`

- 오늘보다 미래 날짜
- 완료 record가 존재하더라도 `future`로 취급
- monthly completion rate 분자/분모에서 항상 제외
- `missed` 또는 `pending`으로 표시하지 않음

Monthly completion rate rules:

- 오늘이 pending이면 오늘은 분모에서 제외한다.
- 종료된 과거 날짜만 분모로 사용한다.
- 오늘을 완료하면 오늘을 분자와 분모에 포함한다.
- 미래 날짜는 항상 제외한다.

중요:

- 오늘 미작성 상태를 missed로 처리하지 않는다.
- 오늘 미작성 때문에 월간 달성률이 떨어지면 안 된다.
- 미래 날짜는 달성률 계산 대상이 아니다.

## 9. Reminder Notifications

Reminder는 UserNotifications 기반 local notification으로 동작한다.

기본 reminder slot:

- Morning: 09:00
- Evening: 18:00
- Night: 22:00

각 reminder는:

- 개별 enable / disable 가능
- 사용자가 시간 변경 가능
- 시간 또는 enable 상태 변경 후 사용자가 확인 action을 눌렀을 때 저장 및 scheduling 적용
- local notification으로 동작
- 서버나 backend를 사용하지 않음

Permission rules:

- 앱이 처음 실행되자마자 notification permission을 요청하지 않는다.
- Settings 화면에 notification authorization 상태를 명확히 표시한다.
- `notDetermined` 상태에서는 "알림 허용하기" action을 제공한다.
- 사용자가 해당 action을 명시적으로 눌렀을 때 requestAuthorization을 실행한다.
- permission이 denied된 경우 crash하거나 반복 요청하지 않는다.
- denied 상태에서는 알림이 시스템 설정에서 비활성화되어 있음을 명확히 표시한다.
- denied 상태에서는 가능한 경우 iOS Settings로 이동할 수 있는 action을 제공한다.
- authorized / provisional / ephemeral 상태에서는 현재 reminder preferences를 기준으로 notification을 예약한다.
- reminder preference enabled 값과 notification authorization 상태는 독립적으로 유지한다.
- permission이 없어도 reminder preference 변경은 저장할 수 있지만 실제 notification은 예약하지 않는다.

Scheduling rules:

- UNUserNotificationCenter를 사용한다.
- 기본 scheduling horizon은 오늘을 포함하여 앞으로 14일이다.
- Morning / Evening / Night가 모두 활성화되어 있으면 최대 42개의 notification request를 관리한다.
- identifier는 날짜 기반 구조를 사용한다.
- 예: `devstreak.reminder.morning.2026-08-22`
- 이미 지난 시간의 오늘 reminder는 예약하지 않는다.
- 오늘 Daily Goal이 completed이면 오늘 reminder는 예약하지 않는다.
- 미래 날짜 reminder는 오늘 완료 여부와 관계없이 유지한다.
- 오늘 goal을 완료하면 오늘 날짜 identifier만 취소한다.
- 미래 날짜 notification은 취소하지 않는다.
- 중복 notification request를 만들지 않는다.
- 사용자가 변경사항 적용을 확인하면 DevStreak가 관리하는 pending reminder를 정리하고 새 설정 기준으로 14일 rolling horizon을 다시 채운다.
- 앱 실행/활성화 시 필요한 경우 현재 설정 기준으로 14일 rolling schedule을 동기화한다.
- 사용자가 다음 날 앱을 실행하지 않아도 이미 예약된 notification이 정상적으로 동작해야 한다.

Notification content는 고정 문자열로 둘 수 있으며, 디자인/카피 refinement는 후속 작업에서 진행한다.

## 10. Idea Inbox

Idea Inbox는 기술 글감을 빠르게 저장하기 위한 lightweight local store이다.

Idea는 SwiftData `@Model`로 저장한다.

```swift
@Model
final class Idea {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var tagsRawValue: String
    var statusRawValue: String
    var createdAt: Date
    var updatedAt: Date
}
```

Idea status:

- `inbox`
- `used`
- `archived`

필수 동작:

- 새 Idea 추가
- Idea 수정
- Idea 삭제
- archived 처리
- archived 복구
- used 상태 처리
- 생성일/수정일 유지

Tag rules:

- 하나의 Idea에 여러 tag 저장 가능
- tag는 간단한 문자열 목록
- 별도 Tag entity/table을 만들지 않음
- 중복 tag 저장 금지
- 앞뒤 공백 제거
- 빈 tag 저장 금지
- 입력 순서 유지

Idea 생성만으로 Daily Goal을 완료 처리하지 않는다. Idea는 글쓰기 준비 단계일 뿐이다.

## 11. Claude Hand-off

Claude API를 앱에 직접 통합하지 않는다.

Idea에서 "Claude로 글쓰기"를 실행하면:

1. 해당 Idea의 title / notes / tags를 기반으로 prompt 생성
2. prompt를 clipboard에 복사
3. 가능한 경우 Claude 앱 또는 웹으로 이동할 수 있는 action 제공

Prompt 기본 구조:

```text
Dev Archive에 다음 주제로 글을 작성하려고 합니다.

주제:
{title}

메모:
{notes}

태그:
{tags}

CONVENTIONS.md와 DESIGN_RULES.md의 규칙을 따라주세요.
기존 Dev Archive의 글 스타일과 구조도 참고해주세요.
```

중요:

- 앱은 Claude에게 prompt를 전달하는 역할만 한다.
- Claude API 호출은 하지 않는다.
- 블로그 repository를 직접 수정하지 않는다.
- GitHub write는 하지 않는다.
- Write with Claude 실행만으로 자동 used 처리하지 않는다.

## 12. Widget

Widget은 WidgetKit 기반으로 구현한다.

지원 family:

- `systemSmall`
- `systemMedium`
- `accessoryCircular`
- `accessoryRectangular`
- `accessoryInline`

Widget 표시 정보:

- Today `0 / 1` 또는 `1 / 1`
- Current streak
- Write shortcut / dashboard deep link
- 지원 family에 따라 pending idea count 등 최소 snapshot 정보

Widget과 main app은 App Group을 통해 최소 상태만 공유한다.

Widget이 main app의 SwiftData store 전체를 직접 읽지 않는다.

공유 snapshot은 다음 정보를 포함한다.

- `dateKey`
- `isTodayCompleted`
- `currentStreak`
- `pendingIdeaCount`
- `updatedAt`

Widget snapshot은 Codable local data로 저장한다.

DailyRecord, Idea 전체 모델을 Widget target에 불필요하게 공유하지 않는다.

Widget refresh rules:

- manual completion 후 Widget timeline reload를 요청한다.
- GitHub verification 후 Widget timeline reload를 요청한다.
- app launch 또는 app active 시 날짜 변경 감지 후 필요한 경우 snapshot을 갱신한다.
- 필요한 경우 Idea 변경 후 snapshot을 갱신한다.
- iOS Widget refresh는 실시간 동기화를 보장하지 않는다.
- Widget은 마지막으로 저장된 snapshot을 기준으로 안전하게 표시되어야 한다.

Widget navigation:

- Widget tap은 `devstreak://dashboard` deep link로 app을 연다.
- Widget에서 복잡한 interactive action은 현재 MVP 범위에 포함하지 않는다.

Stale snapshot policy:

- snapshot의 `dateKey`가 Widget의 현재 local dateKey와 다르면 오늘 완료 상태로 표시하지 않는다.
- 오래된 snapshot으로 어제 완료를 오늘 완료처럼 보여주지 않는다.
- 오래된 snapshot의 streak를 임의로 증가시키지 않는다.

## 13. GitHub Verification

GitHub integration은 블로그 관리 목적이 아니라 "오늘 실제 콘텐츠 작성 활동이 있었는가"를 검증하는 데이터 소스로 사용한다.

GitHub integration은 read-only를 원칙으로 한다.

검증 대상 repository:

- `sssuunnnm/dev-archive`

앱은 다음 동작을 하지 않는다.

- repository content write
- commit 생성
- branch 생성 또는 수정
- Pull Request 생성 또는 수정
- merge
- GitHub Actions 실행
- file edit

Daily Goal 완료로 인정하는 변경 경로:

- `src/content/articles/**`
- `src/content/projects/**`
- `src/content/references/**`
- `src/content/snippets/**`

작성 여부 판단에 다음 값은 사용하지 않는다.

- frontmatter `draft`
- frontmatter `date`
- branch naming convention
- PR 존재 여부만
- main branch commit 존재 여부만
- branch 존재 여부만

반드시 commit changed files를 확인한다.

현재 검증 대상:

- `main`
- open Pull Requests의 commits

Working branch 직접 등록/검사는 현재 MVP에 포함하지 않는다. 후속 버전에서 추가할 수 있도록 GitHub API client와 verification service는 ref 기반 조회를 유지한다.

Timestamp rules:

- commit timestamp는 timezone-aware Date로 해석한다.
- 앱의 DateService를 통해 local calendar dateKey로 변환한다.
- frontmatter date는 작성 날짜로 사용하지 않는다.

Persistence rules:

- 콘텐츠 활동이 확인되면 해당 local dateKey의 DailyRecord를 `githubVerified` 상태로 저장한다.
- record가 없으면 `githubVerified` DailyRecord를 생성한다.
- pending이면 `githubVerified`로 변경한다.
- `manualCompleted`이면 `githubVerified`로 승격할 수 있다.
- 이미 `githubVerified`이면 중복 record를 만들지 않는다.
- GitHub verification 실패, offline, rate limit, auth 실패는 missed로 기록하지 않는다.
- manual completion은 GitHub verification 이후에도 계속 지원한다.

Authentication and security rules:

- Dashboard GitHub verification은 Fine-grained PAT가 Keychain에 저장된 뒤에만 실행한다.
- GitHub 연결 전에는 Dashboard에 연결 필요 상태를 표시하고 자동 확인을 실행하지 않는다.
- Token이 있으면 `Authorization: Bearer <token>` header를 사용한다.
- Token은 Keychain에만 저장한다.
- Token이 저장되어 있으면 GitHub 연결 설정 화면에서 token 입력칸은 숨기고 연결 테스트와 삭제 action만 제공한다.
- Token을 UserDefaults에 평문 저장하지 않는다.
- Token을 hardcode하지 않는다.
- Token을 error나 log에 노출하지 않는다.
- GitHub 권한은 read-only 최소 권한을 사용한다.
- OAuth는 현재 MVP에 포함하지 않는다.
- Backend infrastructure를 추가하지 않는다.

API rules:

- GitHub API 호출은 async/await 기반으로 수행한다.
- rate limit과 pagination을 고려한다.
- 동일 commit은 중복 처리하지 않는다.
- network 실패는 사용자에게 재시도 가능한 상태로 표시한다.
- Dashboard verification 기본 lookback은 최근 7일이다.
- 사용자가 명시적으로 실행하는 history sync는 최근 30일을 확인한다.
- 오늘 DailyRecord가 이미 `githubVerified`이면 앱 실행/활성화 시 자동 verification을 다시 실행하지 않는다.
- background polling 또는 server-side scheduler는 구현하지 않는다.

GitHub verification으로 오늘 완료가 확인되면:

- DailyRecord.status = `githubVerified`
- 오늘 남은 reminder notification을 취소한다.
- Widget snapshot을 갱신한다.
- Widget timeline reload를 요청한다.

Widget은 GitHub API를 직접 호출하지 않는다.

## 14. Architecture

DevStreak는 큰 Repository/ViewModel layer를 두지 않고, SwiftUI `@Query`와 `ModelContext`를 우선 사용한다. 복잡한 계산과 side effect는 작은 service로 분리한다.

```text
DevStreak/
├── DevStreak/
│   ├── DevStreakApp.swift
│   ├── Models/
│   │   ├── DailyRecord.swift
│   │   ├── Idea.swift
│   │   ├── ReminderSettings.swift
│   │   └── ReminderSlot.swift
│   ├── Features/
│   │   ├── Dashboard/
│   │   ├── Ideas/
│   │   └── Settings/
│   ├── Services/
│   │   ├── DateService.swift
│   │   ├── StreakService.swift
│   │   ├── HabitCalendarService.swift
│   │   ├── ReminderNotificationService.swift
│   │   ├── GitHubAPIClient.swift
│   │   ├── GitHubVerificationService.swift
│   │   ├── GitHubCredentialStore.swift
│   │   ├── GitHubDailyRecordUpdater.swift
│   │   ├── IdeaPromptService.swift
│   │   ├── TagNormalizer.swift
│   │   └── WidgetSnapshotService.swift
│   ├── Shared/
│   │   ├── WidgetSnapshot.swift
│   │   ├── WidgetSnapshotStore.swift
│   │   ├── WidgetDisplayState.swift
│   │   └── WidgetConstants.swift
│   └── Design/
├── DevStreakWidget/
├── DevStreakTests/
└── DevStreakUITests/
```

## 15. Data Flow

Manual completion:

```text
Dashboard confirmation
-> DailyRecord manualCompleted 생성/갱신
-> ModelContext.save()
-> WidgetSnapshot refresh
-> 오늘 reminder cancel
```

GitHub verification:

```text
Dashboard refresh
-> GitHubVerificationService.verify()
-> GitHub REST API read-only requests
-> content path matching
-> GitHubDailyRecordUpdater
-> DailyRecord githubVerified 생성/승격
-> ModelContext.save()
-> WidgetSnapshot refresh
-> 오늘 verified인 경우 오늘 reminder cancel
```

Widget:

```text
App SwiftData state
-> WidgetSnapshotService.makeSnapshot()
-> App Group UserDefaults
-> WidgetSnapshotStore.load()
-> WidgetDisplayState
-> WidgetKit timeline
```

Reminder scheduling:

```text
ReminderSettingsView / app activation
-> ReminderSettingsStore.load()
-> authorization status 확인
-> 14일 rolling schedule 계산
-> managed pending requests 정리
-> enabled reminder request 추가
```

## 16. Deferred Scope

현재 MVP 범위에 포함하지 않는다.

- Blog CMS features
- Blog deployment
- GitHub write operations
- Pull Request creation or update
- Claude API integration
- Backend infrastructure
- Server-side scheduler
- Analytics/tracking SDK
- Widget-side SwiftData access
- OAuth-based GitHub login
- Working branch management UI
- Complex interactive widget actions
- Complex Idea search/filtering

## 17. Testing Expectations

테스트는 Swift Testing과 XCTest UI Tests로 구성한다.

주요 coverage:

- DateService timezone/dateKey/month logic
- StreakService current/best streak
- HabitCalendarService completed/missed/pending/future status
- Monthly completion rate
- Reminder settings persistence
- 14일 rolling notification schedule
- Reminder race condition generation guard
- Widget snapshot save/load/fallback
- Stale widget snapshot display state
- Idea model/status/tag normalization
- Claude prompt generation
- GitHub API response/error mapping
- GitHub credential handling
- GitHub content path matching
- GitHub verification budget/dedupe/cache/lookback
- GitHub DailyRecord update/backfill persistence
- Manual completion confirmation

Before release:

- Build the app target.
- Build the widget target.
- Run available tests.
- Verify notification, widget, App Group, Keychain, deep link, and GitHub verification on a real device.
