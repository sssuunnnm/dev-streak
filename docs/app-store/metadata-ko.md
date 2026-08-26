# DevStreak App Store Metadata (ko-KR)

Last updated: 2026-08-26

## Version

- Version: `1.0`
- Build: 새 TestFlight 빌드 업로드 후 선택
- Release option: 수동으로 버전 출시

## Preview And Screenshots

PNG 이미지는 App Store Connect의 "앱 미리보기"가 아니라 "스크린샷" 슬롯에 업로드한다. 앱 미리보기는 동영상 슬롯이다.

6.5 디스플레이 스크린샷:

1. `docs/app-store/previews/Preview-1.png`
2. `docs/app-store/previews/Preview-2.png`
3. `docs/app-store/previews/Preview-3.png`
4. `docs/app-store/previews/Preview-4.png`

첫 3장이 앱 설치 시트에 우선 표시된다.

## Promotional Text

매일 하나씩 GitHub 기록을 확인하고, 연속 기록과 아이디어 메모를 함께 관리하세요.

## Description

DevStreak는 GitHub 기록을 꾸준히 이어가고 싶은 사람을 위한 가벼운 iOS 앱입니다.
매일 하나의 기록을 남기는 습관을 눈에 보이게 만들고 GitHub 커밋 기록을 바탕으로 오늘의 기록 여부와 연속 기록을 확인할 수 있습니다.

주요 기능

- 오늘 기록 상태 확인
- GitHub 커밋 기반 기록 확인
- 연속 기록과 최고 기록 표시
- 월간 캘린더로 기록 흐름 확인
- 아이디어 메모 저장 및 정리
- 기록 리마인더 알림
- 홈 화면 및 잠금 화면 위젯 지원

GitHub 연결은 읽기 권한만 사용합니다. 토큰은 기기 Keychain에만 저장되며 DevStreak 개발자는 사용자의 기록, 메모, 알림 설정, GitHub 토큰을 수집하거나 서버로 전송하지 않습니다.
현재 버전은 하나의 저장소를 기준으로 기록을 확인합니다. 추후 확장될 예정입니다.

## Keywords

GitHub,streak,commit,developer,record,habit,widget,calendar,memo,productivity

## Support URL

TBD: Notion 또는 간단한 공개 support page URL을 입력한다.

임시로 별도 support page가 없다면 Privacy Policy 페이지와 같은 Notion workspace에 `DevStreak Support` 페이지를 만든다.

## Marketing URL

공백으로 둔다.

## Routing App Coverage File

공백으로 둔다.

## Copyright

© 2026 SUN MIN LEE

## App Review Information

### Sign-In

- Login required: No

### Contact Information

- First name / Last name: Apple Developer 계정의 법적 이름 기준으로 입력
- Email: `sssuunnnm@gmail.com`
- Phone: Apple Developer 계정 연락 가능한 전화번호 입력

### Review Notes

로그인 계정은 필요하지 않습니다.

GitHub 연결은 사용자가 직접 발급한 fine-grained personal access token을 기기 Keychain에 저장해 사용하는 선택 기능입니다. 앱은 GitHub 저장소에 쓰기 작업을 하지 않으며, read-only API 요청으로 커밋 기록을 확인합니다.

앱의 기록, 아이디어 메모, 알림 설정은 기기 내에 저장됩니다. 개발자 서버, analytics SDK, tracking SDK는 사용하지 않습니다.

### Attachment

공백으로 둔다.

## App Privacy Summary

- Developer data collection: 없음
- Daily records: 기기 내 SwiftData 저장
- Idea memos: 기기 내 SwiftData 저장
- Reminder settings: 기기 내 UserDefaults 저장
- Widget snapshot: App Group UserDefaults에 최소 표시 상태 저장
- GitHub token: Keychain에만 저장
- Network: GitHub REST API read-only request
- Tracking: 없음
- Analytics SDK: 없음
- Backend server: 없음

## Export Compliance / Encryption Notes

앱은 별도 독자 암호화 알고리즘을 구현하지 않는다.

사용하는 보안 기능:

- HTTPS 기반 GitHub API 통신
- iOS Keychain
- Apple OS/framework가 제공하는 표준 보안 기능

App Store Connect의 수출 규정/암호화 문항은 제출 시 실제 표시되는 질문 문구를 확인하고 답변한다.

## Open Follow-ups

배포 전 차단 이슈는 아니지만 후속 안정화 작업으로 추적한다.

- Initial backfill resume: 최근 3년 초기 동기화가 API request budget을 초과하면 다음 시도도 처음부터 다시 시작한다. pagination 진행 위치 저장 또는 기간 단위 분할 저장이 필요하다.
- Dashboard GitHub verification coordinator: Dashboard의 자동 verification 상태 전이와 side effect 일부가 아직 `DashboardView`에 남아 있다. Settings 쪽처럼 coordinator/view model로 분리하면 테스트와 유지보수가 쉬워진다.
- GitHub branch selection: 현재 MVP는 `main` branch와 open PR commit만 확인한다. 사용자가 branch/ref를 선택하는 UI는 후속 범위다.
- Repository scope expansion: 현재 MVP는 `sssuunnnm/dev-archive` 단일 repository만 지원한다. 다중 repository 선택은 후속 범위다.
