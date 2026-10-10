# UntilPayday / Payday Left 실제 출시 준비 기록

기준일: 2026-10-10. App Store 1.0(2) 테스트 광고 빌드는 서명·비공개 보관·Apple 업로드와 Apple 처리를 완료했습니다. 이 기록에 포함된 승인된 최종 소스 변경은 실제 iOS 재검증 전입니다. 사용자는 기존 실기기 테스트 결과를 기준으로 심사 제출을 요청했으며, 필수 출시 준비 후 제출할 예정입니다.

## 현재 결과

| 항목 | 실제 결과 |
|---|---|
| 원본 비공개 저장소 | 기존 소스·커밋·브랜치·태그 보존 |
| 기존 코드 재활용 | 원본 84개 기준 목록 보존; 81개 동일, 아래 승인된 3개 최소 변경 |
| 기존 테스트 | 직전 검증 소스 6d0ee76의 Core 33 / Unit 27 / UI 12 / 배포 검사 24 통과, 실패·건너뛰기 없음; 최종 변경본은 재검증 전 |
| 홈 위젯 | 실제 Simulator Small 위젯 데이터 공유·금액 갱신·Today 열기 통과; Medium·잠금 위젯 실동작 추가 확인 필요 |
| 공개 안전성 검사 | 소스·자산 선별 공개; 비밀 키·실기기 번호·서명 파일·실제 예산 기록 제외 |
| 신규 공개용 저장소 | 독립적인 공개 저장소; 원본 Git 이력 복사·Fork·Mirror·새 라이선스 없음 |
| GitHub Actions | 무료 표준 macOS 수동 실행; Linux 우선 검사; 서명은 소유자 승인 보호 Environment |
| Flutter analyze | 해당 없음 — 실제 SwiftUI 프로젝트 |
| Flutter test | 해당 없음 — 기존 Swift Core/XCTest/UI 테스트 실행 |
| iOS Release 빌드 | Xcode 27.0 / iOS SDK 27 앱·위젯 컴파일 및 1.0(2) Archive/Export 성공 |
| 메인 앱 및 위젯 서명 | 기존 인증서·각 App Store 프로파일 확인; 다운로드한 IPA와 원본 archive의 두 대상 CMS·페이지·메타데이터·권한 검사 통과 |
| IPA 생성 | 1.0(2) 테스트 광고 IPA 및 원본 xcarchive를 기존 비공개 저장소의 미게시 draft Release에 보관; 공개 서명 아티팩트 0개 |
| App Store Connect | Payday Left 6821234126 생성; Finance·1.0·4+·무료 가격·설명·URL·실제 화면 5장·심사 연락처 저장 |
| TestFlight | 1.0(2) Apple 처리 완료 및 수출 규정 답변 저장; 내부 그룹 생성, 설치 확인은 별도 필요 |
| 실제 iPhone QA | 기존 1.0(1) Ad Hoc 설치·실행·지출/Today·홈 위젯 갱신/탭·재실행 보존·오프라인 지출 저장·다크모드 앱/위젯 사용자 정상 확인; 확인 범위 밖의 항목은 미확인; 사용자는 기존 실기기 결과를 기준으로 심사 제출 요청 |
| App Store 심사 | 미제출; 최종 소스/운영 광고 빌드·동의 및 개인정보 공개 답변·필수 출시 준비 완료 후 사용자 요청에 따라 심사 제출 예정 |

## 승인된 변경과 이유

- `AppSources/UntilPayday/Views/Settings/AboutInfoView.swift`: 출시 준비용 Privacy 문장만 “Read the full privacy policy on our website.”와 실제 정책 링크로 교체. 기존 글자 스타일 유지.
- `AppSources/UntilPayday/Resources/Localizable.xcstrings`: 해당 영어 문장 키만 교체.
- `AppSources/UntilPayday/Services/AdManager.swift`: 기존 전면 광고 요청에 `npa=1`을 명시. 기존 광고 시점·횟수 제한·UMP 동의와 초기화 설정 유지. Google은 기존 PPT 설정이 개인 맞춤 광고를 끄지만 제3자 광고 추적까지 제한하지 않는다고 안내합니다.
- `Build/verify_source.py`, `Build/approved_source_changes.json`, 이 문서와 README: 원본 해시 기준을 보존하고 승인된 세 변경만 별도로 검증·기록.
- 이전 `Build/store_signing.py` 수정: Apple codesign의 기본 인증서 추출 방식을 임시 작업 폴더에서 사용하도록 최소 수정. 실제 재시도에서 엄격한 서명·기존 인증서 검사를 통과했습니다.
- 등록된 Bundle ID·App Group 조립 연결: `Config/AppInfo.plist`, `Config/WidgetInfo.plist`, 본체·위젯 entitlements, `project.yml`, Xcode project. 계산·기능·아이콘·위젯 디자인 변경 없음.

원본 기준 목록을 새 파일 해시로 덮어쓰지 않습니다. 비공개 원본 저장소는 변경하지 않습니다.

## 실제 실행 기록

- 수정 전 최초 서명 검사 오류: https://github.com/baewumnote-studio/untilpayday-ios-public-build/actions/runs/38023491884
- 최소 서명 검사 수정 후 실제 iOS 검증 성공: https://github.com/baewumnote-studio/untilpayday-ios-public-build/actions/runs/38025252917
- 실제 앱/위젯 서명·Export·비공개 보관·Apple 업로드 성공: https://github.com/baewumnote-studio/untilpayday-ios-public-build/actions/runs/38026556337
- 워크플로: `.github/workflows/ios-build.yml`, `.github/workflows/ios-release.yml`.

## 남은 출시 확인

- 승인된 최종 소스 변경의 실제 iOS SDK 컴파일·기존 테스트·Simulator 캡처 재검증.
- 앱 전용 운영 AdMob ID는 준비했으며 현재 1.0(2)는 테스트 광고입니다. 최종 운영 빌드는 별도로 서명·보관·업로드해야 합니다.
- EU/US 앱 전용 UMP 동의 메시지는 초안입니다. 최종 광고 설정과 실제 지역별 동작을 확인하고 적용해야 합니다.
- 최종 archive의 SDK 개인정보 정보와 실제 광고 설정에 맞는 App Privacy 목적·연결·추적 답변을 완료해야 합니다. SDK가 있으므로 앱 전체를 ‘수집 없음’으로 답하지 않습니다.
- 마케팅 URL은 실제 앱 안내 페이지입니다. https://baewumnote-studio.github.io/untilpayday/ 및 지원·정책 페이지 HTTP 200을 확인했습니다. 사이트 루트 app-ads.txt의 정확한 게시자 스니펫과 크롤러 응답을 확인했습니다. 공개 Store 정보 연결과 AdMob 준비 상태 심사는 출시 후 별도 단계입니다.
- 급여 주기·청구 처리·날짜 경계, 큰 글자, Medium/잠금 위젯, 알림·동의·광고의 전체 실기기 확인은 기록된 범위 밖입니다. 사용자는 이미 확인한 실기기 결과를 기준으로 심사를 요청했으므로 추가 내부 테스터 초대와 반복 설치를 심사 준비의 필수 단계로 요구하지 않습니다.
- App Store 심사 제출은 사용자 요청에 따라 필수 준비 후 진행할 예정입니다. 심사 승인 후 수동 출시는 별도 단계입니다.
