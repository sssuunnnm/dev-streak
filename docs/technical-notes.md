# DevStreak Technical Notes

This document keeps implementation details that are useful for future maintenance, reviews, and hand-off between Codex sessions.

`SPEC.md` remains the source of truth for product behavior. `README.md` is intentionally shorter and more user-facing.

## Product Principles

- Local-first
- SwiftUI first
- SwiftData for local persistence
- Widget and app share only the minimum snapshot state
- GitHub integration is read-only
- No GitHub write operations
- No Claude API integration
- No backend infrastructure
- No analytics or tracking SDK
- GitHub token is stored only in Keychain
- Daily records, ideas, reminder settings, and GitHub token are not collected by a developer server
- Calendar and timezone logic is handled explicitly through `DateService`

## Daily Records

DailyRecord is stored as a SwiftData model.

```swift
@Model
final class DailyRecord {
    @Attribute(.unique) var dateKey: String
    var statusRawValue: String
    var completedAt: Date?
    var createdAt: Date
}
```

Supported statuses:

- `pending`
- `manualCompleted`
- `githubVerified`

`manualCompleted` is kept for compatibility with older local data. Only `githubVerified` counts as a completed day in current product behavior.

## Streak Rules

`StreakService` calculates current streak and best streak.

Current streak follows these rules:

- If today is completed, count backward from today.
- If today is incomplete but yesterday is completed, keep the streak through yesterday.
- The streak breaks only when a past day is confirmed missed.

This avoids dropping a streak to zero just because today is still in progress.

## Calendar Rules

`HabitCalendarService` interprets dates with five statuses.

- `completed`: a verified GitHub record exists
- `missed`: a past date has no completed record
- `pending`: today has no completed record yet
- `future`: a date after today
- `untracked`: before repository creation or while GitHub verification is disconnected

Monthly completion rate uses only eligible tracked dates. Pending today, future dates, and untracked dates are excluded.

When the GitHub token is deleted, local GitHub verification records and repository metadata are reset, and the calendar returns to neutral/untracked presentation.

## Reminder Scheduling

Reminder notifications use UserNotifications local notifications.

Default slots:

- Morning: 09:00
- Evening: 18:00
- Night: 22:00

Scheduling policy:

- 14-day rolling horizon
- Maximum 3 slots * 14 days = 42 managed requests
- Past reminder times for today are skipped
- If today is completed, today's reminders are not scheduled
- Future reminders are kept
- Completing today cancels only today's pending reminders
- Reminder preferences are disabled until notification permission allows scheduling

Race conditions are guarded with scheduling generation in `ReminderScheduleState`. Older sync tasks cannot add requests after a newer cancel/sync generation has started.

## Idea Inbox

Idea is stored as a SwiftData model.

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

Supported statuses:

- `inbox`
- `used`
- `archived`

Tags are stored as a JSON-encoded string array instead of a separate entity. `TagNormalizer` trims whitespace, removes empty tags, removes duplicates, and preserves input order.

## Claude Hand-off

DevStreak does not call the Claude API.

The Claude hand-off flow:

1. Generate a prompt from an idea memo.
2. Copy the prompt to the clipboard.
3. Try to open `https://claude.ai/`.

Sending a prompt to Claude does not mark an idea as used. The user must explicitly mark the idea as used.

## Widget Data Flow

Widget target does not open the SwiftData store.

The app creates a `WidgetSnapshot` and stores it in App Group UserDefaults. The widget reads only this snapshot.

App Group:

```text
group.com.sssuunnnm.DevStreakApp
```

Snapshot shape:

```swift
struct WidgetSnapshot: Codable, Equatable {
    var dateKey: String
    var isTodayCompleted: Bool
    var currentStreak: Int
    var pendingIdeaCount: Int
    var recentDays: [WidgetRecentDay]
    var updatedAt: Date
}
```

After saving the snapshot, the app reloads the `DevStreakWidget` timeline.

Stale snapshot policy:

- If the snapshot dateKey differs from the widget's current local dateKey, it must not show today as completed.
- Old snapshots must not make yesterday look like today's completion.
- Old snapshots must not arbitrarily increase streak.

Widget taps open the app through `devstreak://dashboard`.

## GitHub Verification

GitHub integration verifies actual content activity through read-only GitHub API requests.

Repository:

```text
sssuunnnm/dev-archive
```

Authentication:

- Fine-grained PAT
- Token stored only in Keychain
- Token used only in the GitHub API `Authorization` header
- No GitHub write permission
- If a token exists, the settings screen hides the token input and shows only connection test/delete actions

Dashboard verification:

- Default lookback: recent 7 days
- Main branch commits are checked
- Open Pull Request commits are checked
- MVP does not let the user select branch/ref
- SHAs are deduped
- Commit detail is fetched to inspect changed files
- If today is already `githubVerified`, automatic verification does not rerun on app activation

Accepted content paths:

```text
src/content/articles/
src/content/projects/
src/content/references/
src/content/snippets/
```

Ignored for verification:

- frontmatter `draft`
- frontmatter `date`
- branch naming convention
- PR existence alone
- branch existence alone

Failure policy:

- GitHub API failure is not treated as missed.
- Partial success is not persisted to DailyRecord.
- Rate limit, credential, network, decoding, and budget exceeded states are distinguished.
- Token values must not appear in logs or errors.

## GitHub History Sync

GitHub settings has two history sync modes:

- Initial automatic backfill: recent 3 years
- Manual sync: recent 30 days

Policy:

- Dashboard refresh keeps its 7-day lookback.
- Initial 3-year backfill runs automatically once after connection.
- Manual backfill does not mark the initial backfill as complete.
- Existing records are not deleted.
- Backfill only adds new records or promotes existing compatible records.
- Save failure rolls back backfill changes.
- Verification failure does not roll back unrelated unsaved SwiftData changes.
- Today's reminder cancel side effect runs only if today's dateKey is included.
- Widget snapshot refreshes after successful persistence.

## Architecture

DevStreak does not currently use a large repository/view model layer. It prefers SwiftUI `@Query` and `ModelContext`, with complex calculations and side effects split into focused services.

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
│   │       └── GitHubConnectionCoordinator.swift
│   ├── Services/
│   │   ├── DateService.swift
│   │   ├── CalendarMonthRangePolicy.swift
│   │   ├── StreakService.swift
│   │   ├── HabitCalendarService.swift
│   │   ├── ReminderNotificationService.swift
│   │   ├── GitHubAPIClient.swift
│   │   ├── GitHubVerificationService.swift
│   │   ├── GitHubCredentialStore.swift
│   │   ├── GitHubRepositoryMetadataStore.swift
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

## Data Flows

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

## Design Notes

Current UI direction is minimal and editorial.

- Dashboard order: today's goal, GitHub verification, idea memo, monthly calendar
- SF Symbols iconography
- Paperlogy font
- Dynamic Type based typography tokens
- Widgets respect system background and Lock Screen rendering

Design system pieces:

- `DesignTokens`
- `SoftDepthCard`
- `IconPlate`
- `TactileButtonStyle`

## Security Notes

- GitHub PAT is stored in Keychain
- No token hardcoding
- No token in UserDefaults
- GitHub API requests are read-only GET requests
- No GitHub write operations
- No backend
- No Claude API calls

## Testing Notes

Test suite uses Swift Testing and XCTest UI Tests.

Main coverage:

- DateService timezone/dateKey/month logic
- StreakService current/best streak
- HabitCalendarService completed/missed/pending/future/untracked status
- Monthly completion rate
- Reminder settings persistence
- 14-day rolling notification schedule
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
- Calendar month range policy

Recent validation during TestFlight/App Store preparation:

- iPhone 15 Pro iOS 17.0.1 build succeeded
- iPad Pro 12.9-inch iOS 17.0.1 build succeeded
- iPad 10th generation iOS 17.0.1 unit tests succeeded

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
