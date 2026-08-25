# DevStreak

DevStreak는 개인 GitHub 기록 습관을 유지하기 위한 iOS companion app입니다.

블로그 CMS나 배포 도구가 아니라, 하루에 최소 하나의 개발 기록을 남겼는지 확인하고 이어갈 수 있도록 돕는 로컬 우선 생산성 앱입니다.

## What It Does

- 오늘의 기록 상태를 `0 / 1` 또는 `1 / 1`로 표시
- 수동 완료와 GitHub 활동 검증을 기반으로 Daily Goal 기록
- 현재 연속 기록과 최고 연속 기록 계산
- 월간 캘린더와 월간 달성률 표시
- 아침, 저녁, 밤 리마인더 설정 및 14일 rolling local notification 예약
- 글감 메모를 저장하는 Idea Inbox
- Claude로 넘길 글쓰기 prompt 생성 및 clipboard 복사
- Home Screen / Lock Screen Widget으로 오늘 상태 확인
- `sssuunnnm/dev-archive` GitHub repository의 콘텐츠 변경을 read-only로 확인

## Product Principles

DevStreak는 다음 원칙을 기준으로 구현되어 있습니다.

- Local-first
- SwiftUI first
- SwiftData 기반 로컬 persistence
- Widget과 app은 최소 snapshot만 공유
- GitHub integration은 read-only
- GitHub write operation 없음
- Claude API 직접 연동 없음
- Backend infrastructure 없음
- Analytics / tracking SDK 없음
- Token은 source code나 UserDefaults에 저장하지 않고 Keychain에만 저장
- 작성 기록, 아이디어, 리마인더 설정, GitHub token을 개발자 서버로 수집하지 않음
- 날짜와 timezone 처리는 `DateService`에서 명시적으로 처리

## Core User Flow

1. Dashboard에서 오늘 기록 상태와 streak를 확인합니다.
2. 오늘 GitHub 기록을 남겼다면 `오늘 기록 완료`로 수동 완료 처리할 수 있습니다.
3. DevStreak가 저장된 Fine-grained PAT로 최근 GitHub 콘텐츠 활동을 read-only로 확인합니다.
4. 글감은 `아이디어 메모`에 저장하고, 필요할 때 Claude prompt로 복사해 넘깁니다.
5. Widget과 알림은 앱을 열지 않아도 오늘 기록 상태를 계속 상기시킵니다.

## Features

### Dashboard

Dashboard는 앱의 중심 화면입니다.

- 오늘 날짜
- 오늘 Daily Goal 상태
- 현재 연속 기록
- 최고 기록
- GitHub 기록 확인 상태
- Idea Inbox 대기 개수
- 이번 달 calendar와 completion rate

수동 완료는 confirmation alert를 거친 뒤에만 저장됩니다. 오늘이 아직 미완료인 상태는 실패로 처리하지 않으며, 어제까지 이어진 streak도 오늘 pending이라는 이유만으로 끊지 않습니다.

### Daily Records

DailyRecord는 SwiftData `@Model`로 저장됩니다.

```swift
@Model
final class DailyRecord {
    @Attribute(.unique) var dateKey: String
    var statusRawValue: String
    var completedAt: Date?
    var createdAt: Date
}
```

지원 상태:

- `pending`
- `manualCompleted`
- `githubVerified`

`manualCompleted` 또는 `githubVerified`는 completed day로 계산됩니다.

### Streak

`StreakService`가 current streak와 best streak를 계산합니다.

Current streak는 다음 규칙을 따릅니다.

- 오늘 완료 상태면 오늘부터 역방향으로 계산
- 오늘 미완료라도 어제가 완료 상태면 어제까지의 streak 유지
- 과거 날짜가 missed로 확정되었을 때 streak가 끊김

이 규칙 덕분에 오늘이 아직 진행 중인 상태만으로 streak가 즉시 0이 되지 않습니다.

### Calendar

`HabitCalendarService`는 날짜를 네 가지 상태로 해석합니다.

- `completed`: 완료 기록이 있는 날짜
- `missed`: 이미 지난 날짜인데 완료 기록이 없는 날짜
- `pending`: 오늘이며 아직 완료 기록이 없는 날짜
- `future`: 오늘보다 미래 날짜

월간 달성률은 completed와 missed만 분모로 사용합니다. 오늘이 pending이면 월간 달성률 분모에서 제외되며, 오늘 완료 시에만 분자와 분모에 포함됩니다. 미래 날짜는 항상 제외됩니다.

### Reminder Notifications

Reminder는 UserNotifications 기반 local notification으로 동작합니다.

기본 slot:

- 아침 09:00
- 저녁 18:00
- 밤 22:00

각 slot은 개별 enable/disable과 시간 변경을 지원합니다. 변경된 설정은 사용자가 `변경사항 적용`을 확인한 뒤 `ReminderSettingsStore`를 통해 UserDefaults에 저장됩니다.

Scheduling 정책:

- 14일 rolling horizon
- 최대 3 slot * 14일 = 42개 request
- 오늘 이미 지난 시간은 예약하지 않음
- 오늘 완료 상태면 오늘 reminder는 예약하지 않음
- 미래 날짜 reminder는 유지
- 오늘 완료 시 오늘 날짜의 pending reminder만 취소
- notification permission과 reminder preference는 독립적으로 관리

Race condition 방지를 위해 scheduling generation을 사용합니다. 오래된 sync 작업이 최신 cancel/sync 결과를 덮어쓰지 못하도록 `ReminderScheduleState`에서 최신 generation만 request를 추가할 수 있게 관리합니다.

### Idea Inbox

Idea Inbox는 기술 글감을 빠르게 저장하는 lightweight local store입니다.

Idea는 SwiftData `@Model`로 저장됩니다.

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

지원 상태:

- `inbox`
- `used`
- `archived`

지원 기능:

- 메모 생성
- 수정
- 삭제
- 사용함 처리
- 보관
- 보관 해제
- 태그 저장

태그는 별도 entity 없이 문자열 배열을 JSON으로 저장합니다. `TagNormalizer`가 앞뒤 공백 제거, 빈 태그 제거, 중복 제거, 입력 순서 유지를 담당합니다.

### Claude Hand-off

DevStreak는 Claude API를 직접 호출하지 않습니다.

`Claude로 글쓰기`를 실행하면:

1. Idea 메모를 기반으로 prompt를 생성
2. prompt를 clipboard에 복사
3. `https://claude.ai/` 열기를 시도

Claude로 넘기는 행위만으로 Idea가 `used` 상태가 되지는 않습니다. 사용자가 명시적으로 `사용함으로 표시`를 눌렀을 때만 상태가 변경됩니다.

### Widget

Widget은 WidgetKit 기반으로 구현되어 있습니다.

지원 family:

- `systemSmall`
- `systemMedium`
- `accessoryCircular`
- `accessoryRectangular`
- `accessoryInline`

Widget은 SwiftData store를 직접 열지 않습니다. App target이 현재 상태를 `WidgetSnapshot`으로 만들어 App Group UserDefaults에 저장하고, Widget target은 이 snapshot만 읽습니다.

공유 App Group:

```text
group.com.sssuunnnm.DevStreakApp
```

Snapshot 구조:

```swift
struct WidgetSnapshot: Codable, Equatable {
    var dateKey: String
    var isTodayCompleted: Bool
    var currentStreak: Int
    var pendingIdeaCount: Int
    var updatedAt: Date
}
```

Snapshot 저장 성공 후 `WidgetCenter.reloadTimelines(ofKind:)`로 `DevStreakWidget` timeline을 갱신합니다.

Stale snapshot 정책:

- snapshot의 `dateKey`가 Widget의 현재 local dateKey와 다르면 오늘 완료 상태로 표시하지 않음
- 오래된 snapshot으로 어제 완료를 오늘 완료처럼 보여주지 않음
- 오래된 snapshot의 streak를 임의로 증가시키지 않음

Widget tap은 `devstreak://dashboard` deep link로 app을 엽니다.

### GitHub Verification

GitHub integration은 repository의 실제 콘텐츠 작성 활동을 확인하기 위한 read-only verification입니다.

대상 repository:

```text
sssuunnnm/dev-archive
```

인증:

- GitHub 연결 전에는 자동 확인을 실행하지 않음
- Fine-grained PAT 기반 확인
- Token은 Keychain에만 저장
- Token이 있으면 `Authorization: Bearer <token>` 사용
- GitHub write permission 없음
- Token이 저장되어 있으면 입력칸은 숨기고 연결 테스트와 삭제만 제공합니다.

Dashboard verification:

- 기본 lookback: 최근 7일
- main branch commits 조회
- open Pull Request commits 조회
- working branch 직접 등록/검사는 현재 MVP 범위 밖
- SHA dedupe
- commit detail 조회
- changed files가 인정 경로에 포함되는지 확인
- 오늘 기록이 이미 `githubVerified`이면 앱 재진입 시 자동 verification을 다시 실행하지 않음

인정 경로:

```text
src/content/articles/
src/content/projects/
src/content/references/
src/content/snippets/
```

검증에서 사용하지 않는 값:

- frontmatter `draft`
- frontmatter `date`
- branch naming convention
- PR 존재 여부만
- branch 존재 여부만

콘텐츠 경로 변경이 확인되면 해당 local dateKey의 DailyRecord를 `githubVerified`로 생성하거나 승격합니다. 기존 `manualCompleted`도 GitHub 활동이 확인되면 `githubVerified`로 승격될 수 있습니다.

실패 처리:

- GitHub API 실패를 missed로 처리하지 않음
- partial success를 DailyRecord에 저장하지 않음
- rate limit, credential, network, decoding, budget exceeded 상태를 구분
- token 값은 error나 log에 노출하지 않음

### GitHub History Sync

GitHub 설정 화면에는 사용자가 명시적으로 실행하는 `최근 30일 동기화`가 있습니다.

정책:

- Dashboard 일반 refresh의 7일 lookback은 유지
- 사용자가 직접 실행할 때만 최근 30일 backfill
- 기존 기록은 삭제하지 않음
- 새 기록 추가 또는 기존 기록 승격만 수행
- 저장 실패 시 rollback
- verification 실패 시 unrelated unsaved SwiftData changes를 rollback하지 않음
- 오늘 dateKey가 포함된 경우에만 오늘 reminder cancel side effect 실행
- 성공 후 Widget snapshot refresh

## Architecture

DevStreak는 큰 Repository/ViewModel layer를 두지 않고, SwiftUI `@Query`와 `ModelContext`를 우선 사용합니다. 복잡한 계산과 side effect는 작은 service로 분리했습니다.

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

## Data Flow

### Manual Completion

```text
Dashboard confirmation
→ DailyRecord manualCompleted 생성/갱신
→ ModelContext.save()
→ WidgetSnapshot refresh
→ 오늘 reminder cancel
```

### GitHub Verification

```text
Dashboard refresh
→ GitHubVerificationService.verify()
→ GitHub REST API read-only requests
→ content path matching
→ GitHubDailyRecordUpdater
→ DailyRecord githubVerified 생성/승격
→ ModelContext.save()
→ WidgetSnapshot refresh
→ 오늘 verified인 경우 오늘 reminder cancel
```

### Widget

```text
App SwiftData state
→ WidgetSnapshotService.makeSnapshot()
→ App Group UserDefaults
→ WidgetSnapshotStore.load()
→ WidgetDisplayState
→ WidgetKit timeline
```

### Reminder Scheduling

```text
ReminderSettingsView / app activation
→ ReminderSettingsStore.load()
→ authorization status 확인
→ 14일 rolling schedule 계산
→ managed pending requests 정리
→ enabled reminder request 추가
```

## Design

현재 UI는 Minimal Editorial 방향으로 정리되어 있습니다.

- Dashboard는 오늘 목표, GitHub 확인, 아이디어 메모, 이번 달 캘린더 순서로 구성
- SF Symbols 기반 iconography
- Paperlogy font 적용
- Dynamic Type 기반 typography token
- Widget은 system background와 Lock Screen rendering을 존중

Design system은 `DesignTokens`, `SoftDepthCard`, `IconPlate`, `TactileButtonStyle`로 분리되어 있으며, feature code에 색상과 spacing이 흩어지지 않도록 관리합니다.

## Security

- GitHub PAT는 Keychain에 저장
- Source code에 token hardcoding 없음
- UserDefaults에 token 저장 없음
- GitHub API request는 read-only GET request만 사용
- GitHub write operation 없음
- Backend 없음
- Claude API 호출 없음

## Privacy

DevStreak는 local-first app입니다. 개발자는 사용자의 작성 기록, 아이디어, 리마인더 설정, GitHub token을 수집하거나 서버로 전송하지 않습니다.

Privacy Policy는 [PRIVACY.md](PRIVACY.md)에 보관하고, 배포용 공개 URL은 [DevStreak Privacy Policy](https://sssuunnnm.notion.site/DevStreak-Privacy-Policy-3c70f65e84d680c0a1e0e02425ccc7d2)입니다. 연락 이메일은 `sssuunnnm@gmail.com`입니다.

Local data:

- DailyRecord와 Idea는 기기 내 SwiftData에 저장
- Reminder 설정은 기기 내 UserDefaults에 저장
- Widget 공유 상태는 App Group UserDefaults에 최소 snapshot만 저장
- GitHub token은 선택 사항이며 Keychain에만 저장

Network behavior:

- GitHub verification은 `sssuunnnm/dev-archive` repository의 read-only GitHub REST API 요청만 수행
- Token이 있으면 GitHub API Authorization header에만 사용
- Claude API 직접 호출 없음
- Analytics SDK, tracking SDK, backend infrastructure 없음

## Testing

테스트는 Swift Testing과 XCTest UI Tests로 구성되어 있습니다.

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

최근 검증 기준:

```text
Last verified: 2026-08-25
App build: succeeded
Widget build: succeeded
Full xcodebuild test: succeeded
Tests: 128 passed
```

## Requirements

현재 Xcode project 설정 기준:

- Xcode with iOS 26.5 SDK
- iOS deployment target: 17.0
- SwiftUI
- SwiftData
- WidgetKit
- UserNotifications
- Security / Keychain
- App Groups capability

Targets:

- `DevStreak`
- `DevStreakWidget`
- `DevStreakTests`
- `DevStreakUITests`

Bundle identifiers:

- App: `com.sssuunnnm.DevStreakApp`
- Widget: `com.sssuunnnm.DevStreakApp.DevStreakWidget`

## Build & Test

Open the project:

```bash
open DevStreak/DevStreak.xcodeproj
```

Build app:

```bash
xcodebuild \
  -project DevStreak/DevStreak.xcodeproj \
  -scheme DevStreak \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Build widget:

```bash
xcodebuild \
  -project DevStreak/DevStreak.xcodeproj \
  -scheme DevStreakWidget \
  -destination 'generic/platform=iOS Simulator' \
  build
```

Run tests:

```bash
xcodebuild test \
  -project DevStreak/DevStreak.xcodeproj \
  -scheme DevStreak \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Repository Scope

DevStreak intentionally does not implement:

- Blog CMS features
- Blog deployment
- GitHub write operations
- Pull Request creation
- Claude API integration
- Backend infrastructure
- Widget-side SwiftData access

The app focuses on one job: helping a developer keep a daily technical writing habit visible, measurable, and easy to resume.
