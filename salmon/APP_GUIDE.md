# 거슬렁 앱 구현 지도

현재 작업본 기준이다. 화면별 표에서 버튼·아이콘·텍스트를 찾고, 파일 링크를 열어 괄호 안의 클래스나 메서드 이름을 검색하면 된다.

### 화면에서 구현 파일로 바로 가기

| 화면 | 화면을 여는 곳 | 화면의 책임 파일 |
| --- | --- | --- |
| 시작·세션 확인 | 앱 실행 | [main.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/main.dart), [app.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/app/app.dart) |
| 로그인 | 세션 확인, 회원가입 종료, 로그아웃 | [login_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/auth/login_screen.dart) |
| 회원가입 | 로그인 화면의 회원가입 링크 | [signup_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/auth/signup_screen.dart) |
| 내 경로·길찾기 | 로그인 성공 또는 세션 복원 | [myroutes_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/myroutes_screen.dart) |
| 경로 관리 | 내 경로 칩 줄 오른쪽 슬라이더 버튼 | [route_management_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/route_management_screen.dart) |
| 경로추천 | 길찾기 시트 하단의 경로 검색 | [routeresults_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/routeresults_screen.dart) |
| 경로 상세·경로 안내 | 추천/저장 카드 및 관련 경로, 시트 하단의 안내 시작 | [route_detail_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/route_detail_screen.dart) |
| 설정·알림·계정·회원 탈퇴 | 지도 상단 톱니 → 설정 목록 → 필요 시 계정의 회원 탈퇴 | [settings_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/settings/settings_screen.dart)에서 알림·계정·탈퇴 파일로 연결 |

## 1. 앱 실행과 화면 이동

- [main.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/main.dart)의 `main`이 Flutter, 카카오 지도·로그인 SDK와 Liquid Glass를 초기화한다. 라이트 Glass 기본 품질은 `standard`다. 키 값은 빌드 설정에서 읽는다.
- [app.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/app/app.dart)의 `MyApp`이 앱 제목과 Material 테마를 정한다. 세션 확인 중 중앙에 브랜드색 원형 Glass 로딩 표시가 나오고, 복원 성공 시 지도, 그 외에는 로그인으로 이동한다. `/my_routes`도 같은 지도 화면이다.
- **로그인 → 지도 → 길찾기 → 경로추천 → 경로 상세**가 기본 이동 흐름이다. 경로 상세에서 안내를 시작하면 같은 화면이 경로 안내 모드로 바뀐다. **내 경로 → 예시 카드 → 경로 상세**, **지도 → 설정 → 알림 / 계정 → 회원 탈퇴**도 같은 앱 내 진입 경로다. 회원가입은 로그인에서 들어가고, 가입 성공 후 이메일을 전달해 로그인으로 돌아간다.

## 2. 로그인과 회원가입

| 보이는 요소 | 구현과 동작 |
| --- | --- |
| 거슬렁 제목, 슬로건, 소개 문구, 흰 배경, 키보드 여백 | [login_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/auth/login_screen.dart)의 `LoginScreen.build` |
| 이메일·비밀번호 라벨과 입력칸, 눈 아이콘 | 같은 파일의 `_input`이 공용 Glass 입력을 배치한다. 이메일 키보드와 비밀번호 숨김을 설정한다. 눈은 `visibility_outlined` / `visibility_off_outlined`를 전환한다. |
| 로그인 / 로그인 중…, 실패 안내 | `AppPrimaryButton`과 `_login`. 입력과 제출 상태로 활성화를 정하고, 성공하면 지도, 실패하면 스낵바를 표시한다. |
| 계정이 없으신가요? 회원가입 | `_openSignup`. 회원가입을 열고 가입이 완료되면 이메일을 받아 입력칸을 채운다. |
| 양쪽 구분선과 또는 간편 로그인 | 같은 파일의 `Row`, `Divider` |
| 노란 카카오 로그인 | `GlassButton.custom`과 [kakao_login_kr_large.png](C:/Users/jace0/Desktop/salmon/salmon/assets/images/kakao_login_kr_large.png). `_kakaoLogin`이 Android의 카카오 인증을 시작한다. |
| 카카오 계정으로 가입 팝업 | 로그인 파일의 약관·개인정보 체크박스, 취소, 동의하고 계속. 두 필수 항목을 모두 동의하면 가입 요청을 이어간다. |
| 회원가입 제목, 기본 뒤로가기, 소개 문구 | [signup_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/auth/signup_screen.dart)의 `SignupScreen`과 Material `AppBar` |
| 이메일, 비밀번호, 비밀번호 확인, 닉네임 | 회원가입 파일의 `_input`. 두 비밀번호 칸에 독립적인 눈 아이콘이 있고 확인 값이 다르면 오류 문구가 보인다. |
| 약관 동의, 전체 동의, 구분선, 필수 체크박스 두 개 | `_agreement`. 전체 동의가 두 필수 항목을 함께 바꾼다. 항목 옆 `chevron_right`는 약관 제목과 준비 중 문구가 있는 팝업을 열며 **닫기**로 돌아간다. |
| 회원가입 완료 / 가입 중…, 이미 계정이 있으신가요? 로그인 | 등록 버튼은 필수 입력·동의·제출 상태에 따라 활성화된다. 로그인 텍스트 버튼은 가입 화면을 닫는다. 인증 오류는 스낵바로 표시한다. |

인증 API와 계정 상태는 [auth_api.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/auth/auth_api.dart)의 `AuthApi`가 관리한다. 가입·이메일 로그인·카카오 서버 로그인·세션 갱신·로그아웃과 보안 저장소의 갱신 토큰 처리까지 여기 있다. 카카오 SDK 인증 경로와 취소 판별은 [kakao_login_sdk.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/auth/kakao_login_sdk.dart)가 담당한다.

- 입력칸의 구체적인 모양·텍스트 입력·포커스 영역은 [app_glass_text_field.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/app_glass_text_field.dart), 완료 버튼의 높이·활성색·눌림 처리는 [app_primary_button.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/app_primary_button.dart)에서 확인할 수 있다.
- 로그인은 `_login`/ `_kakaoLogin`에서 제출 상태를 관리하고, 가입은 `_signup`이 입력을 API에 전달한다. 이메일 로그인 버튼과 카카오 버튼은 동시에 제출할 수 없도록 같은 진행 상태를 본다.

## 3. 지도와 내 경로 탭

| 보이는 요소 | 구현과 동작 |
| --- | --- |
| 화면 전체 카카오 지도, 최초 서울시청 중심 | [myroutes_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/myroutes_screen.dart)의 `KakaoMap`, `_onMapReady`. 지도 타일과 기본 지명은 지도 SDK가 제공한다. 두 탭이 같은 지도를 공유한다. |
| 상단 거슬렁 제목과 유리 앱바 | 같은 파일의 `GlassAppBar`, `appBarPadding`, `_appBarButtonSize`. 제목과 버튼 크기·높이·여백을 이곳에서 바꾼다. `Scaffold`에서 지도를 앱바 뒤까지 펼친다. 앱바 배경의 `BackdropFilter`는 현재 `sigmaX`와 `sigmaY`가 모두 `0`이다. |
| 종 아이콘 알림 내역 | `notifications_none_rounded`. 누르면 준비 중 `GlassToast`를 띄운다. 설정의 알림 페이지와 별개다. |
| 톱니 아이콘 설정 | `Icons.settings`. 포커스를 해제하고 설정 화면을 연다. |
| 하단 내 경로·길찾기 | `GlassTabBar.bottom`, `Icons.route`, `Icons.map`, `_onTabSelected`. 아이콘과 라벨의 선택색은 브랜드색이고, 테두리와 탭바 크기도 같은 파일에서 정한다. |
| 과녁 아이콘 현재 위치로 이동 | `Icons.my_location`, `_positionMapControls`. [AppMapIconButton](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/app_map_icon_button.dart)을 사용한다. 누르면 현재 위치로 이동한다. 지도 준비 전·위치 조회 중에는 비활성이고, 선택하면 브랜드색이다. 지도 버튼 두 개는 카드·시트·키보드 높이에 맞춰 함께 움직인다. |
| GPS 위 경로 위치 보기 | `Icons.route_outlined`와 [`_moveCameraToRoute`](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/myroutes_screen.dart:250). 누를 때마다 전체 보기 → 출발지 → 목적지 → 전체 보기 순으로 이동하고 아이콘이 브랜드색으로 바뀐다. 내 경로에서는 좌표가 있는 예시 경로, 길찾기에서는 두 장소를 모두 선택했을 때 활성화된다. |
| 현재 위치 마커와 방향 표시 | [map_location_tracker.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/map_location_tracker.dart)의 `_showMyLocation`과 `_startHeading`. [current-pin.png](C:/Users/jace0/Desktop/salmon/salmon/assets/images/current-pin.png)를 등록·이동·회전한다. 위치 서비스·권한 확인은 [location_permission.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/location_permission.dart)다. |
| 핀 안의 ‘출발’·‘도착’ 글자 | 내 경로·길찾기 두 탭에서 사용한다. `_buildRoutePinIcon`이 `location-pin.png` 위에 Pretendard 글자를 올려 `KImage.fromWidget()`으로 합성한다. `top`과 `fontSize`가 글자 위치와 크기를 정한다. `RouteMapOverlays`는 합성한 두 이미지를 재사용하고 핀과 선택 상태를 맞춘다. [핀 합성](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/myroutes_screen.dart:305) · [지도 오버레이](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/route_map_overlays.dart:190) · [핀 원본](C:/Users/jace0/Desktop/salmon/salmon/assets/images/location-pin.png) |
| 예시 저장 경로선 | 실제 경로 형상이 있으면 구간별 색으로 그리고, 형상이 없으면 출발–도착 연결선을 그린다. 두 경우 모두 `PolylineStyle`의 두 번째 인수가 굵기 `16`을 지정한다. [경로선 스타일](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/route_map_overlays.dart:135) |
| 예시 경로·퇴근길·등교길·주말 경로 칩 | `SavedRoutesOverlay`의 `_routes`를 공용 `ChipButton`으로 가로 배치한다. 칩을 선택하거나 하단 `PageView` 카드를 스와이프하면 카드와 선택 표시점이 함께 바뀐다. [저장 경로 오버레이](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/saved_routes_overlay.dart:109) · [공용 칩](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/chip_button.dart) |
| 가장 오른쪽 슬라이더 아이콘 경로 관리 | 같은 오버레이의 `Icons.tune`. [route_management_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/route_management_screen.dart)로 이동한다. 관리 화면에는 제목과 기본 뒤로가기가 있다. |
| 탭바 위 내 경로 전용 카드 | [saved_route_card.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/saved_route_card.dart). 출발지→목적지, 예상 소요시간, 예상 잔여석, 구간별 시간 비율을 보여 주는 색상 막대, 교통수단·노선 순서, 상세 열기 꺾쇠를 표시한다. 잔여석은 경로의 최소 예측값을 쓰고, 경로 값이 없으면 예측된 구간 중 최솟값을 표시한다. |
| 카드 로딩·실패·준비 중 | [SavedRoutesOverlay](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/saved_routes_overlay.dart)의 `_buildExampleCard`가 예시 읽기 상태를 전달한다. 퇴근길·등교길·주말 카드의 지명은 임시값이며, 상세에 연결된 예시 카드만 열 수 있다. |
| 카드 크기와 스와이프 | 오버레이의 `PageView`는 가로 스와이프를 처리한다. `myroutes_screen.dart`는 여유 높이에서 카드 영역을 최대 160으로 제한한다. `SavedRouteCard`는 낮은 영역이나 큰 글자에 맞춰 보조 줄을 줄이며, 긴 줄은 말줄임 처리한다. 카드 내부의 시간 막대는 고정되고 카드 전체를 가로로 넘길 수 있다. |

지도 상단·GPS 아이콘 버튼과 하단 탭바에는 `minimal` 품질이 지정되어 있다. 기기 방향은 [DeviceHeadingStream.kt](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/kotlin/com/example/salmon/DeviceHeadingStream.kt)가 센서에서 읽고, [MainActivity.kt](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/kotlin/com/example/salmon/MainActivity.kt)가 `salmon/device_heading` 채널로 Flutter에 연결한다.

GPS 버튼을 눌렀을 때 이동하는 줌을 바꾸려면 `MapLocationTracker`의 `gpsZoomLevel`을 수정한다. `recenter()`를 호출하는 두 탭과 경로 상세·안내의 GPS 버튼, 안내 시작에 공통으로 적용된다. [GPS 줌 설정](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/map_location_tracker.dart:27)

경로 위치 보기에서 출발지나 목적지로 이동할 때는 `RouteCameraView.cameraUpdate`의 `zoomLevel: 16`을 사용한다. 내 경로·길찾기 지도가 처음 열릴 때의 줌은 `myroutes_screen.dart`의 `KakaoMapOption`에서 설정한다. [경로 위치 줌 설정](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/journey_map_geometry.dart:5)

## 4. 길찾기 탭과 입력 시트

| 보이는 요소 | 구현과 동작 |
| --- | --- |
| 흰색 시트, 숨김·중간·최대 높이, 드래그, 키보드 대응 | [route_sheet.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/route_sheet.dart)의 `RouteSheet`·`RouteSheetController`. 처음 길찾기 탭에 들어가면 중간 높이로 열리고, 같은 탭을 다시 누르면 시트를 열거나 닫는다. 최대 높이(`routeSheetTop`)는 앱바 아래에 지도 버튼 두 개와 간격을 남긴다. 경로 위치 보기 버튼을 누르면 지도 위 핀이 보이도록 시트를 접는다. |
| 위쪽 회색 손잡이 | [route_search_panel.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_search/route_search_panel.dart)의 `PinnedHeaderSliver`. 시트 내부 스크롤 중에도 상단에 붙는다. |
| 출발지 과녁, 목적지 지도 핀, 선호 광역버스 버스 아이콘 | [myroutes_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/myroutes_screen.dart)의 `_fieldDecoration`, `_placeField`, `BusRouteSearchField` 호출부. `my_location`, `place_outlined`, `directions_bus_outlined`를 쓴다. 현재 입력칸은 흰색 Material `TextField`다. |
| 입력칸 X와 지우기 접근성 문구 | [search_field_clear_button.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_search/search_field_clear_button.dart)의 `Icons.close`. 값이 있을 때만 표시한다. 장소를 지우면 해당 선택과 핀을, 버스를 지우면 노선 선택을 해제한다. |
| 장소 제안, 내 위치, 로딩·빈 결과·오류 | 출발지나 목적지를 편집하면 해당 입력란 바로 아래에 제안 목록이 열린다. 검색어가 비어 있을 때도 `near_me_outlined` 아이콘의 ‘내 위치’를 선택할 수 있다. 검색 결과에는 집·핀 아이콘과 이름·상세 주소가 표시된다. [제안 목록](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_search/routesearch_screen.dart) · [입력란과 목록 배치](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_search/route_search_panel.dart) |
| 장소 검색 입력 대기·요청 취소·결과 선택 | [kakao_place_suggestions.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_search/kakao_place_suggestions.dart)가 상태와 요청 순서를 관리한다. [kakao_place_search_api.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/places/kakao_place_search_api.dart)가 카카오 장소명·주소 API를 호출하고, [kakao_search_result.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/places/kakao_search_result.dart)가 지명·주소·좌표를 변환한다. 입력 채우기와 지도 카메라·핀 연동은 `MyRoutesScreen`에서 한다. |
| 버스 제안의 버스 아이콘, 노선 번호, 기점→종점/지역, 로딩·오류·빈 결과 | [bus_route_search_field.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_search/bus_route_search_field.dart). [bus_route_search_api.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/journeys/bus_route_search_api.dart)로 검색한다. GBIS 후보를 골랐을 때 API에는 공식 ID를, 사용자에게는 노선 번호를 사용한다. |
| 두 제안 목록의 선형 진행 표시 | [search_suggestions_progress.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_search/search_suggestions_progress.dart)의 공용 Glass 진행 바. 장소·광역버스마다 접근성 라벨이 다르다. |
| 경로 검색 | 출발지와 목적지를 선택하면 버튼이 활성화된다. `_openRouteResults`가 선택한 두 장소와 선호 광역버스 정보를 경로추천으로 전달한다. 화면이 아래에서 올라오고 X 또는 뒤로 가기로 닫으면 아래로 내려간다. `PageRouteBuilder`의 `transitionDuration`과 `reverseTransitionDuration`은 각각 450ms이며 `Curves.easeInOutCubic`을 사용한다. [화면 전환 설정](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/myroutes_screen.dart:144) |

## 5. 경로추천과 추천 전용 카드

| 보이는 요소 | 구현과 동작 |
| --- | --- |
| 브랜드색 헤더, 경로추천, Swagger 예시 표식, 오른쪽 X | [routeresults_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/routeresults_screen.dart). `CloseButton`으로 지도에 돌아간다. 아래 브랜드 영역의 출발→도착, 거슬렁 추천순과 안내 문구도 같은 화면에서 만든다. |
| 전체·버스·지하철·버스+지하철·선호 버스 칩과 건수 | 경로추천 화면이 공용 `ChipButton`을 가로로 배치한다. 필터 로직은 서버 필터와 후보를 연결하고 선호 버스를 입력한 경우에 해당 노선 칩을 만든다. 카드 목록은 세로로 스크롤한다. [공용 칩](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/chip_button.dart) · [필터 로직](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/journey_result_filters.dart) |
| 로딩 회전 표시, 오류 문구, 다시 시도, 표시할 경로가 없어요 | 경로추천의 `_buildCards`. 다시 시도하면 전체 필터에서 새 요청을 시작한다. |
| 큰 소요 시간, 오른쪽 꺾쇠, 출발·도착, 도보·환승·요금·거리 | [journey_result_card.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/journey_result_card.dart)의 `JourneyResultCard`. 값이 있는 항목을 표시한다. 카드 본문을 누르면 선택 후보의 상세를 연다. |
| 구간별 색과 분 수가 있는 시간 막대 | 같은 파일의 공개 위젯 `JourneyTimeBar`. 구간 시간을 막대 너비로 표현하고 화면보다 넓으면 가로 스크롤한다. 경로 상세의 시트에도 표시된다. |
| 버스·지하철 아이콘, 승차→하차 정류장, ARS 번호, 노선·시각, 잔여석 배지 | 같은 파일의 `_TransitStops`. 아이콘은 `directions_bus_outlined`, `subway_outlined`. 예측 수치가 없으면 응답의 상태 문구를 표시한다. |
| 추천 순위와 좌석 예측 요약 | [journey_recommendation.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/journey_recommendation.dart). 추천 순위와 ODsay 순위 다음에 위험 수준, 최소 예상 잔여석, 잔여 5석 이하 확률을 묶어서 표시한다. 여유·주의·예측 불가 상태는 아이콘·문구·색을 함께 쓴다. |
| 예측 근거 버튼, 설명 시트의 손잡이·제목·추천 문구·닫기 | 같은 파일의 `_showEvidence`. 카드 전체 탭은 경로 상세, 예측 근거 탭은 좌석 설명을 연다. 서버의 추천 문구와 수치가 뜻하는 범위는 설명 시트 안에 있다. |
| 한국 시간 포맷, 정류장 번호 붙이기, 교통수단·구간 시간과 색상·예측 문구 | [journey_presentation.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/journey_presentation.dart). 화면과 카드에 들어갈 표시값을 공통으로 변환한다. |

[journey_search_api.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/journeys/journey_search_api.dart)가 검색 요청과 응답 검증을 맡는다. 예시 모드에서는 [journey_example_api.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/journeys/journey_example_api.dart)가 번들 응답을 돌려준다. `JOURNEY_USE_MOCK`을 지정하지 않으면 디버그 여부가 예시 모드 기본값이다.

### 좌석 UX와 JSON 연결

1. **후보를 비교한다.** 목록에서 M5121 예시의 **좌석 부족 위험 낮음 · 최소 예상 잔여 12석 · 잔여 5석 이하 확률 8.9%**를 이동 시간과 함께 읽는다. 각각 `seat_risk_status`, `min_remaining_seats`, `max_low_seat_probability`로부터 온다.
2. **근거를 확인한다.** **예측 근거**를 열면 `recommendation_reason`의 ‘좌석 여유 우수…’ 설명을 읽을 수 있다. 경로 요약 수치는 예측 가능한 구간들의 최솟값·최댓값이다. 이를 탑승 성공률로 변환하지 않는다.
3. **구간을 확인하거나 다른 후보를 비교한다.** 상세 시트의 `JourneyStep`에서 구간별 `seat_prediction`을, `_relatedRoutes`에서 대체 경로의 소요 시간·확률 차이를 확인한다. 예측값이 비어 있으면 응답 상태를 표시한다.

## 6. 경로 상세와 안내

| 보이는 요소 | 구현과 동작 |
| --- | --- |
| 앱바의 제목과 기본 뒤로가기 | [route_detail_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/route_detail_screen.dart)의 `AppBar`. 시작 전에는 ‘경로 상세’와 뒤로가기를 표시한다. 위치 확인 중·안내 중에는 상단 뒤로가기를 숨기며, 안내 중 제목은 ‘경로 안내’다. |
| 경로 지도와 시트의 레이어 | `RouteDetailScreen._buildDetail`의 `Stack`에 카카오맵을 고정 크기로 배치한다. `DraggableScrollableSheet`만 높이를 조절하므로 지도 뷰·좌표·카메라가 다시 생성되지 않는다. 초기 시트 높이는 54%, 드래그 범위는 31–80%다. |
| 로딩 회전 표시, 지도 로드 실패, 확대·이동 | 상세 파일이 응답 로딩을 처리한다. [journey_preview_map.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/journey_preview_map.dart)가 카카오맵과 로드 실패 UI, 최초 카메라 맞춤, 확대·드래그 입력을 맡는다. |
| 출발·도착·승하차 핀과 정류장 번호, 실선·점선 및 안내 | `JourneyPreviewMap`은 핀 이미지와 별도로 지도 라벨을 등록한다. 실제 형상은 실선, 추정 구간과 형상이 없을 때의 연결선은 점선이다. 실선과 점선의 `PolylineStyle` 굵기는 모두 `16`이다. 좌표 변환은 `journey_map_geometry.dart`, 형상 출처 표시는 상세 화면에서 처리한다. [미리보기 지도](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/journey_preview_map.dart) · [좌표 변환](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/journey_map_geometry.dart) |
| 전체 경로 보기·현재 위치 지도 버튼 | 상세와 안내에서 [AppMapIconButton](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/app_map_icon_button.dart)을 사용한다. 오른쪽 여백 20, 버튼 크기 48, 세로 간격 12로 전체 경로를 GPS 위에 배치한다. 두 버튼은 시트 상단을 따라 움직이며, 최대 높이는 앱바 아래에 두 버튼 자리까지 남겨 둔다. 상세의 뒤로가기 버튼도 왼쪽 여백 20과 크기 48을 적용한다. |
| 전체 경로 카메라와 GPS 카메라 | 상세 파일의 `_moveCameraToRoute`는 공용 `RouteCameraView`를 사용한다. 누를 때마다 출발지·목적지 함께 보기 → 출발지(줌 16) → 목적지(줌 16) → 함께 보기 순으로 이동한다. 선택하면 브랜드색으로 바뀌고 GPS 따라가기를 해제하며, 지도 핀이 보이도록 시트를 최소 높이로 내린다. GPS 버튼과 안내 시작 시 `recenter()`가 현재 위치에 공용 `gpsZoomLevel`을 적용한다. 안내 중 추가 GPS 갱신은 줌을 유지하고 카메라 중심만 옮긴다. [경로 카메라 설정](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/journey_map_geometry.dart:5) · [GPS 줌 설정](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/map_location_tracker.dart:27) |
| 시트 손잡이, 출발→도착, 총 시간, 예상 도착·환승·도보 | 상세 파일의 `DraggableScrollableSheet`와 내부 목록. 회색 손잡이, 높이·스냅, 총 시간 글자, 요약 순서를 여기에서 조정한다. |
| 좌석 요약·근거, 시간 비례 막대 | [JourneyRecommendation](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/journey_recommendation.dart)과 [JourneyTimeBar](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/journey_result_card.dart)를 상세에 배치한다. 두 위젯은 추천 화면에서도 재사용한다. |
| 상세 이동 여정 제목, 출발→도착 시각, 구간 확인 중·구간 없음 안내 | 상세 파일이 목록 안에 배치한다. 시각은 [journey_presentation.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/journey_presentation.dart)에서 한국 시간으로 표시한다. |
| 여정 행의 버스·지하철·도보/환승 도보·대기·기타 경로 아이콘 | [journey_step.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/journey_step.dart)의 `JourneyStep`. `directions_bus_outlined`, `subway_outlined`, `directions_walk`, `schedule`, `route_outlined`를 쓴다. 예상 시각, 노선, 소요 시간, 정류장·번호, 거리, 좌석 추정도 여기서 표시한다. |
| 현재 이동 구간 강조 | 상세 파일의 `_onPosition`이 [journey_progress.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/journey_progress.dart)로 위치와 구간 선을 비교한다. 일치하는 행은 연한 브랜드색 배경을 적용한다. |
| 대체 경로, 이 경로가 대체하는 후보, 오른쪽 꺾쇠 | 상세 파일의 `_relatedRoutes`, `_alternativeComparison`. 관련 후보의 순위·시간과 제공된 비교값을 보여주며 행을 누르면 해당 후보 상세로 이동한다. |
| 시트 하단의 안내 시작·현재 위치 확인 중·안내 종료 | 같은 하단 고정 영역과 [AppPrimaryButton](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/app_primary_button.dart)을 사용한다. `_startGuidance`가 권한과 위치를 확인하고, 안내 중에는 버튼 라벨·동작이 종료로 바뀐다. |
| 안내 종료와 길찾기 복귀 | 상세의 `PopScope`가 추적을 멈춘다. [routeresults_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/routeresults_screen.dart)가 종료 결과를 전달받아 추천 화면을 닫고, [myroutes_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/myroutes_screen.dart)의 `_openRouteResults`가 입력을 보존한 길찾기 시트를 다시 연다. |

`_loadDetail`은 검색·후보 ID가 맞는 번들 예시를 먼저 사용한다. 실검색에는 [journey_search_api.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/journeys/journey_search_api.dart)의 `fetchJourneyDetail`을 쓰며, 상세 응답이 없으면 기존 검색 후보의 정보로 시트를 구성한다. GPS로 갱신하는 정보는 현재 위치와 추정 이동 구간이다. 예상 도착·좌석 정보는 선택된 검색·상세 응답에서 읽는다.

## 7. 설정

| 페이지 또는 요소 | 구현과 동작 |
| --- | --- |
| 설정 제목·뒤로가기, 알림과 계정 메뉴, 보조 설명과 오른쪽 꺾쇠 | [settings_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/settings/settings_screen.dart). 공용 앱바, 메뉴 행, 정보 카드, 글자·여백은 [settings_components.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/settings/settings_components.dart). |
| 알림 제목, 앱 알림 소제목, 푸시 알림 받기 Glass 스위치, 구분선, 권한 안내문 | [notification_settings.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/settings/notification_settings.dart). 기본 켜짐, 기기 내 SharedPreferences 저장, 저장 실패 시 이전 값으로 복귀. 현재 UI에서 저장하는 값은 로컬 수신 설정이다. |
| 계정 제목, 로그인 정보 카드, 닉네임·이메일/카카오 안내, 로그아웃·회원 탈퇴 행 | [account_settings.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/settings/account_settings.dart). 인증 세션에서 계정 정보를 읽는다. |
| 로그아웃 확인 팝업, 취소, 로그아웃, 스낵바 | 계정 파일의 `_confirmLogout`. 확인 후 로그아웃을 실행하고 로그인 화면으로 돌아간다. |
| 회원 탈퇴 제목, 정말 탈퇴하시겠어요?, 정보 삭제 안내 카드, 계속 이용하기·탈퇴하기 | [withdraw_settings.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/settings/withdraw_settings.dart). 계속 이용하기는 계정으로 돌아간다. 탈퇴하기에는 현재 서버 삭제 동작이 연결되어 있지 않다. |

설정 홈의 두 메뉴는 `_SettingsMenuRow`, 계정 정보와 탈퇴 경고는 `_SettingsCard`, 설정 계열의 뒤로가기와 앱바는 `_SettingsPage`가 공유한다. 알림 스위치의 라벨·활성색은 알림 파일, 로그아웃 확인창의 두 버튼은 계정 파일, 탈퇴 화면의 하단 두 버튼은 탈퇴 파일에 각각 있다. ‘계속 이용하기’는 공용 주 버튼을 사용한다.

## 8. 공용 위젯과 프로젝트 리소스

| 파일 | 역할 |
| --- | --- |
| [app_primary_button.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/app_primary_button.dart) | 로그인·회원가입 완료·경로 검색·안내 시작·안내 종료·계속 이용하기의 기본 버튼. 브랜드색, 모서리, 높이, 글자, 활성 상태와 탭 콜백을 공통으로 설정한다. |
| [app_map_icon_button.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/app_map_icon_button.dart) | 메인 지도의 종·톱니·경로 위치·GPS와 안내 지도의 전체 경로·GPS를 담당하는 원형 버튼. `appMapGlassSettings`와 `appMapGlassOutline`을 가운데 탭바도 사용한다. |
| [app_glass_text_field.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/app_glass_text_field.dart) | 인증 화면의 Glass 입력. 테두리, Noto Sans KR 입력 폰트, 안쪽 여백 탭으로 포커스, 입력 타입, 가리기, 접미 아이콘 슬롯을 설정한다. |
| [app_message_dialog.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/app_message_dialog.dart) | 회원가입의 약관 안내와 계정 화면의 로그아웃 확인에 쓰는 공용 팝업. |
| [chip_button.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/chip_button.dart) | 내 경로 탭과 경로추천 필터가 공유하는 칩. 텍스트와 아이콘 전용 표시, 선택 상태를 처리한다. |
| [backend.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/backend.dart) | 거슬렁 서버 주소 상수. |
| [journey_api_inputs.json](C:/Users/jace0/Desktop/salmon/salmon/assets/examples/journey_api_inputs.json) | 예시 검색 요청과 상세 요청 매개변수. 검색 예시 로더의 장소 기본값에도 사용한다. |
| [journey_search.json](C:/Users/jace0/Desktop/salmon/salmon/assets/examples/journey_search.json) | 예시 경로 후보, 검색 조건, 필터, 좌석 예측, 대체 관계. |
| [journey_candidate_detail.json](C:/Users/jace0/Desktop/salmon/salmon/assets/examples/journey_candidate_detail.json) | 일치하는 후보의 상세 형상·정류장·출처. |
| [appicon.png](C:/Users/jace0/Desktop/salmon/salmon/assets/icons/appicon.png) | Android 런처 아이콘 생성 원본. 화면 속 버튼은 주로 Flutter의 Material 아이콘을 쓴다. |
| [character.png](C:/Users/jace0/Desktop/salmon/salmon/assets/images/character.png) · [flutter_native_splash.yaml](C:/Users/jace0/Desktop/salmon/salmon/flutter_native_splash.yaml) | 네이티브 스플래시 원본과 생성 설정. Android 밀도별/다크 모드 스플래시와 iOS LaunchImage·LaunchBackground 리소스는 파일 색인에서 찾을 수 있다. |
| [NotoSansKR-Regular.otf](C:/Users/jace0/Desktop/salmon/salmon/assets/fonts/NotoSansKR-Regular.otf) · [NotoSansKR-Bold.otf](C:/Users/jace0/Desktop/salmon/salmon/assets/fonts/NotoSansKR-Bold.otf) | Noto Sans KR 글꼴 리소스. |
| [Pretendard-Regular.otf](C:/Users/jace0/Desktop/salmon/salmon/assets/fonts/Pretendard-Regular.otf) · [Pretendard-Medium.otf](C:/Users/jace0/Desktop/salmon/salmon/assets/fonts/Pretendard-Medium.otf) · [Pretendard-Bold.otf](C:/Users/jace0/Desktop/salmon/salmon/assets/fonts/Pretendard-Bold.otf) | Pretendard 등록 리소스. 현재 앱의 전역 테마는 별도 기본 글꼴을 지정하지 않는다. |
| [pubspec.yaml](C:/Users/jace0/Desktop/salmon/salmon/pubspec.yaml) · [pubspec.lock](C:/Users/jace0/Desktop/salmon/salmon/pubspec.lock) | 의존성 선언·확정 버전, 아이콘 생성, 에셋·글꼴 등록. |
| [analysis_options.yaml](C:/Users/jace0/Desktop/salmon/salmon/analysis_options.yaml) · [devtools_options.yaml](C:/Users/jace0/Desktop/salmon/salmon/devtools_options.yaml) · [.metadata](C:/Users/jace0/Desktop/salmon/salmon/.metadata) · [.gitignore](C:/Users/jace0/Desktop/salmon/salmon/.gitignore) · [README.md](C:/Users/jace0/Desktop/salmon/salmon/README.md) | 정적 분석, DevTools 옵션, Flutter 프로젝트 메타데이터, Git 제외 규칙, 기본 프로젝트 설명. |
| salmon.local.json | 로컬 빌드에 전달하는 카카오 설정 파일. 키 값은 읽거나 기록하지 않았다. |

## 9. 실험 화면과 자동 테스트

| 파일 | 어떤 요소를 확인하는지 |
| --- | --- |
| [main_test.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/main_test.dart) | 별도 데모 진입점, 현재 데모 홈은 카카오맵 SDK 화면. |
| [kakaomap_sdk.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/tests/kakaomap_sdk.dart) | 지도 SDK 데모. 정보·GPS 아이콘, 검색창의 돋보기·X, 주소/장소 제안, 진행 표시와 선택정보 텍스트, 위치 버튼. |
| [demo_map_overlays.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/tests/demo_map_overlays.dart) | 데모 서울시청 POI, 서울역 도착 핀, 주황색 경로선. |
| [liquid_glass_widgets.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/tests/liquid_glass_widgets.dart) | 글래스 테스트 앱바, 컨트롤·홈·입력 탭, 스위치, GPS, 브랜드 버튼, 하트 즐겨찾기, 버스 검색바, 이메일 입력. |
| [auth.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/tests/auth.dart) | 이메일 인증 데모. 가입/로그인 입력과 전환, 약관 체크, 요청 상태, 환영 문구, 로그아웃. |
| [kakao_login.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/tests/kakao_login.dart) | 카카오 인증 데모. 진행 바, 필수 체크박스, 인증·서버 로그인·조회·로그아웃 버튼, 회원 ID·닉네임·상태. |
| [login_screen_test.dart](C:/Users/jace0/Desktop/salmon/salmon/test/login_screen_test.dart) | 가입·로그인 요청과 Glass 입력 포커스. |
| [settings_screen_test.dart](C:/Users/jace0/Desktop/salmon/salmon/test/settings_screen_test.dart) | 푸시 설정 유지, 탈퇴 페이지, 로그아웃 확인과 복귀. |
| [my_routes_screen_test.dart](C:/Users/jace0/Desktop/salmon/salmon/test/my_routes_screen_test.dart) | 내 경로 카드와 스와이프·관리 진입, 길찾기 시트와 검색, GPS 재중심·줌·방향 표시를 점검한다. 출발·도착 이미지가 서로 다른 PNG로 등록되고, 저장 경로와 길찾기에서 같은 이미지를 재사용하는지도 확인한다. |
| [journey_example_api_test.dart](C:/Users/jace0/Desktop/salmon/salmon/test/journey_example_api_test.dart) | 필터와 좌석 근거, 대체 경로, 지도 크기·핀·좌표, 공용 지도 버튼, GPS 따라가기·줌, 하단 안내 시작·종료 및 복귀. |
| [kakao_search_result_test.dart](C:/Users/jace0/Desktop/salmon/salmon/test/kakao_search_result_test.dart) | 장소·주소 변환, ID 없는 주소, 유효하지 않은 좌표 제외. |
| [bus_route_search_field_test.dart](C:/Users/jace0/Desktop/salmon/salmon/test/bus_route_search_field_test.dart) | 노선 자동완성과 선택·공식 GBIS ID. |

## 10. 플랫폼 파일 길잡이

| 위치 | 담당 기능 |
| --- | --- |
| Android | 앱 이름·아이콘 참조·네트워크/위치 권한·카카오 복귀는 [AndroidManifest.xml](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/AndroidManifest.xml). 밀도별 아이콘·적응형 전경·시작 배경은 res 아래, 시작 테마와 색은 values 아래에 있다. Gradle 파일은 빌드·플러그인·SDK를 설정한다. |
| iOS | [Info.plist](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Info.plist)는 앱 메타데이터와 위치 사용 설명. AppDelegate·SceneDelegate·브리징 헤더는 네이티브 시작, Main/LaunchScreen storyboard는 Flutter 컨테이너와 초기 화면, Assets.xcassets는 아이콘과 시작 이미지를 담당한다. |
| macOS | AppDelegate·MainFlutterWindow·MainMenu가 창과 메뉴를 연다. AppInfo·Info.plist가 앱 메타데이터, entitlements가 권한, Assets.xcassets가 크기별 런처 아이콘을 지정한다. |
| Windows | runner의 main·flutter_window·win32_window·utils가 Flutter 창을 실행한다. Runner.rc·resource.h·runner.exe.manifest·app_icon.ico가 실행 파일 리소스·매니페스트·아이콘을 맡는다. |
| Linux | runner의 main·my_application이 GTK/Flutter 창을 시작한다. Windows와 Linux의 CMakeLists는 빌드, generated_plugin 계열은 Flutter 플러그인 등록이다. |
| Web | [index.html](C:/Users/jace0/Desktop/salmon/salmon/web/index.html)이 Flutter 부트스트랩과 페이지 메타데이터를 맡는다. [manifest.json](C:/Users/jace0/Desktop/salmon/salmon/web/manifest.json)과 웹 아이콘·favicon은 PWA 설치와 브라우저 아이콘을 정의한다. |
| Xcode 공통 | project.pbxproj·workspace·scheme·xcconfig가 프로젝트·빌드·실행 설정을 맡고 RunnerTests.swift는 플랫폼 테스트 파일이다. |

### 파일 색인

작업본에 실제 존재하는 관리 파일과 Git 제외 규칙에 해당하지 않는 신규 파일을 열거했다. 플랫폼별 아이콘 변형과 생성된 플러그인 등록 파일도 목록에 포함했다. 로컬 키 파일은 위에 용도만 적었다. 의존성 캐시, 빌드 산출물, Git 내부 파일은 제외했다. 화면 동작은 소스 기준이며 이번 작업에서 앱을 실행해 확인한 내용은 아니다.

#### Flutter 소스 (52)

- [lib/app/app.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/app/app.dart)
- [lib/data/auth/auth_api.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/auth/auth_api.dart)
- [lib/data/auth/kakao_login_sdk.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/auth/kakao_login_sdk.dart)
- [lib/data/backend.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/backend.dart)
- [lib/data/journeys/bus_route_search_api.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/journeys/bus_route_search_api.dart)
- [lib/data/journeys/journey_example_api.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/journeys/journey_example_api.dart)
- [lib/data/journeys/journey_search_api.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/journeys/journey_search_api.dart)
- [lib/data/location_permission.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/location_permission.dart)
- [lib/data/places/kakao_place_search_api.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/places/kakao_place_search_api.dart)
- [lib/data/places/kakao_search_result.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/data/places/kakao_search_result.dart)
- [lib/main_test.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/main_test.dart)
- [lib/main.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/main.dart)
- [lib/tests/auth.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/tests/auth.dart)
- [lib/tests/demo_map_overlays.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/tests/demo_map_overlays.dart)
- [lib/tests/kakao_login.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/tests/kakao_login.dart)
- [lib/tests/kakaomap_sdk.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/tests/kakaomap_sdk.dart)
- [lib/tests/liquid_glass_widgets.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/tests/liquid_glass_widgets.dart)
- [lib/ui/auth/login_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/auth/login_screen.dart)
- [lib/ui/auth/signup_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/auth/signup_screen.dart)
- [lib/ui/core/widgets/app_glass_text_field.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/app_glass_text_field.dart)
- [lib/ui/core/widgets/app_map_icon_button.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/app_map_icon_button.dart)
- [lib/ui/core/widgets/app_message_dialog.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/app_message_dialog.dart)
- [lib/ui/core/widgets/app_primary_button.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/app_primary_button.dart)
- [lib/ui/core/widgets/chip_button.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/chip_button.dart)
- [lib/ui/core/widgets/journey_map_geometry.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/journey_map_geometry.dart)
- [lib/ui/core/widgets/journey_presentation.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/journey_presentation.dart)
- [lib/ui/core/widgets/journey_recommendation.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/journey_recommendation.dart)
- [lib/ui/core/widgets/journey_result_card.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/journey_result_card.dart)
- [lib/ui/core/widgets/saved_routes_overlay.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/core/widgets/saved_routes_overlay.dart)
- [lib/ui/my_routes/map_location_tracker.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/map_location_tracker.dart)
- [lib/ui/my_routes/myroutes_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/myroutes_screen.dart)
- [lib/ui/my_routes/route_management_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/route_management_screen.dart)
- [lib/ui/my_routes/route_map_overlays.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/route_map_overlays.dart)
- [lib/ui/my_routes/route_sheet.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/route_sheet.dart)
- [lib/ui/my_routes/saved_route_card.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/my_routes/saved_route_card.dart)
- [lib/ui/route_results/journey_preview_map.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/journey_preview_map.dart)
- [lib/ui/route_results/journey_progress.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/journey_progress.dart)
- [lib/ui/route_results/journey_result_filters.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/journey_result_filters.dart)
- [lib/ui/route_results/journey_step.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/journey_step.dart)
- [lib/ui/route_results/route_detail_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/route_detail_screen.dart)
- [lib/ui/route_results/routeresults_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_results/routeresults_screen.dart)
- [lib/ui/route_search/bus_route_search_field.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_search/bus_route_search_field.dart)
- [lib/ui/route_search/kakao_place_suggestions.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_search/kakao_place_suggestions.dart)
- [lib/ui/route_search/route_search_panel.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_search/route_search_panel.dart)
- [lib/ui/route_search/routesearch_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_search/routesearch_screen.dart)
- [lib/ui/route_search/search_field_clear_button.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_search/search_field_clear_button.dart)
- [lib/ui/route_search/search_suggestions_progress.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/route_search/search_suggestions_progress.dart)
- [lib/ui/settings/account_settings.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/settings/account_settings.dart)
- [lib/ui/settings/notification_settings.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/settings/notification_settings.dart)
- [lib/ui/settings/settings_components.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/settings/settings_components.dart)
- [lib/ui/settings/settings_screen.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/settings/settings_screen.dart)
- [lib/ui/settings/withdraw_settings.dart](C:/Users/jace0/Desktop/salmon/salmon/lib/ui/settings/withdraw_settings.dart)

#### 자동 테스트 (6)

- [test/bus_route_search_field_test.dart](C:/Users/jace0/Desktop/salmon/salmon/test/bus_route_search_field_test.dart)
- [test/journey_example_api_test.dart](C:/Users/jace0/Desktop/salmon/salmon/test/journey_example_api_test.dart)
- [test/kakao_search_result_test.dart](C:/Users/jace0/Desktop/salmon/salmon/test/kakao_search_result_test.dart)
- [test/login_screen_test.dart](C:/Users/jace0/Desktop/salmon/salmon/test/login_screen_test.dart)
- [test/my_routes_screen_test.dart](C:/Users/jace0/Desktop/salmon/salmon/test/my_routes_screen_test.dart)
- [test/settings_screen_test.dart](C:/Users/jace0/Desktop/salmon/salmon/test/settings_screen_test.dart)

#### 앱 에셋 (13)

- [assets/examples/journey_api_inputs.json](C:/Users/jace0/Desktop/salmon/salmon/assets/examples/journey_api_inputs.json)
- [assets/examples/journey_candidate_detail.json](C:/Users/jace0/Desktop/salmon/salmon/assets/examples/journey_candidate_detail.json)
- [assets/examples/journey_search.json](C:/Users/jace0/Desktop/salmon/salmon/assets/examples/journey_search.json)
- [assets/fonts/NotoSansKR-Bold.otf](C:/Users/jace0/Desktop/salmon/salmon/assets/fonts/NotoSansKR-Bold.otf)
- [assets/fonts/NotoSansKR-Regular.otf](C:/Users/jace0/Desktop/salmon/salmon/assets/fonts/NotoSansKR-Regular.otf)
- [assets/fonts/Pretendard-Bold.otf](C:/Users/jace0/Desktop/salmon/salmon/assets/fonts/Pretendard-Bold.otf)
- [assets/fonts/Pretendard-Medium.otf](C:/Users/jace0/Desktop/salmon/salmon/assets/fonts/Pretendard-Medium.otf)
- [assets/fonts/Pretendard-Regular.otf](C:/Users/jace0/Desktop/salmon/salmon/assets/fonts/Pretendard-Regular.otf)
- [assets/icons/appicon.png](C:/Users/jace0/Desktop/salmon/salmon/assets/icons/appicon.png)
- [assets/images/character.png](C:/Users/jace0/Desktop/salmon/salmon/assets/images/character.png)
- [assets/images/current-pin.png](C:/Users/jace0/Desktop/salmon/salmon/assets/images/current-pin.png)
- [assets/images/kakao_login_kr_large.png](C:/Users/jace0/Desktop/salmon/salmon/assets/images/kakao_login_kr_large.png)
- [assets/images/location-pin.png](C:/Users/jace0/Desktop/salmon/salmon/assets/images/location-pin.png)

#### Android (41)

- [android/.gitignore](C:/Users/jace0/Desktop/salmon/salmon/android/.gitignore) · Git 제외 규칙
- [android/app/build.gradle.kts](C:/Users/jace0/Desktop/salmon/salmon/android/app/build.gradle.kts)
- [android/app/src/debug/AndroidManifest.xml](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/debug/AndroidManifest.xml) · 해당 빌드 유형의 매니페스트
- [android/app/src/main/AndroidManifest.xml](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/AndroidManifest.xml) · 앱·권한·인텐트 설정
- [android/app/src/main/kotlin/com/example/salmon/DeviceHeadingStream.kt](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/kotlin/com/example/salmon/DeviceHeadingStream.kt) · 방향 센서
- [android/app/src/main/kotlin/com/example/salmon/MainActivity.kt](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/kotlin/com/example/salmon/MainActivity.kt) · Flutter Activity 및 센서 채널
- [android/app/src/main/res/drawable-hdpi/android12splash.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-hdpi/android12splash.png) · 네이티브 시작 화면 리소스
- [android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png) · 런처 아이콘 리소스
- [android/app/src/main/res/drawable-mdpi/android12splash.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-mdpi/android12splash.png) · 네이티브 시작 화면 리소스
- [android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png) · 런처 아이콘 리소스
- [android/app/src/main/res/drawable-night-hdpi/android12splash.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-night-hdpi/android12splash.png) · 네이티브 시작 화면 리소스
- [android/app/src/main/res/drawable-night-mdpi/android12splash.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-night-mdpi/android12splash.png) · 네이티브 시작 화면 리소스
- [android/app/src/main/res/drawable-night-xhdpi/android12splash.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-night-xhdpi/android12splash.png) · 네이티브 시작 화면 리소스
- [android/app/src/main/res/drawable-night-xxhdpi/android12splash.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-night-xxhdpi/android12splash.png) · 네이티브 시작 화면 리소스
- [android/app/src/main/res/drawable-night-xxxhdpi/android12splash.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-night-xxxhdpi/android12splash.png) · 네이티브 시작 화면 리소스
- [android/app/src/main/res/drawable-v21/background.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-v21/background.png) · 네이티브 시작 화면 리소스
- [android/app/src/main/res/drawable-v21/launch_background.xml](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-v21/launch_background.xml) · 앱 시작 화면
- [android/app/src/main/res/drawable-xhdpi/android12splash.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-xhdpi/android12splash.png) · 네이티브 시작 화면 리소스
- [android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png) · 런처 아이콘 리소스
- [android/app/src/main/res/drawable-xxhdpi/android12splash.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-xxhdpi/android12splash.png) · 네이티브 시작 화면 리소스
- [android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png) · 런처 아이콘 리소스
- [android/app/src/main/res/drawable-xxxhdpi/android12splash.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-xxxhdpi/android12splash.png) · 네이티브 시작 화면 리소스
- [android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png) · 런처 아이콘 리소스
- [android/app/src/main/res/drawable/background.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable/background.png) · 네이티브 시작 화면 리소스
- [android/app/src/main/res/drawable/launch_background.xml](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/drawable/launch_background.xml) · 앱 시작 화면
- [android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml) · 런처 아이콘 리소스
- [android/app/src/main/res/mipmap-hdpi/ic_launcher.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/mipmap-hdpi/ic_launcher.png) · 런처 아이콘 리소스
- [android/app/src/main/res/mipmap-mdpi/ic_launcher.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/mipmap-mdpi/ic_launcher.png) · 런처 아이콘 리소스
- [android/app/src/main/res/mipmap-xhdpi/ic_launcher.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png) · 런처 아이콘 리소스
- [android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png) · 런처 아이콘 리소스
- [android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png) · 런처 아이콘 리소스
- [android/app/src/main/res/values-night-v31/styles.xml](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/values-night-v31/styles.xml)
- [android/app/src/main/res/values-night/styles.xml](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/values-night/styles.xml) · Android 테마·색상 리소스
- [android/app/src/main/res/values-v31/styles.xml](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/values-v31/styles.xml)
- [android/app/src/main/res/values/colors.xml](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/values/colors.xml) · Android 테마·색상 리소스
- [android/app/src/main/res/values/styles.xml](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/main/res/values/styles.xml) · Android 테마·색상 리소스
- [android/app/src/profile/AndroidManifest.xml](C:/Users/jace0/Desktop/salmon/salmon/android/app/src/profile/AndroidManifest.xml) · 해당 빌드 유형의 매니페스트
- [android/build.gradle.kts](C:/Users/jace0/Desktop/salmon/salmon/android/build.gradle.kts)
- [android/gradle.properties](C:/Users/jace0/Desktop/salmon/salmon/android/gradle.properties) · Android Gradle 빌드 설정
- [android/gradle/wrapper/gradle-wrapper.properties](C:/Users/jace0/Desktop/salmon/salmon/android/gradle/wrapper/gradle-wrapper.properties) · Gradle Wrapper 버전 설정
- [android/settings.gradle.kts](C:/Users/jace0/Desktop/salmon/salmon/android/settings.gradle.kts)

#### iOS (42)

- [ios/.gitignore](C:/Users/jace0/Desktop/salmon/salmon/ios/.gitignore) · Git 제외 규칙
- [ios/Flutter/AppFrameworkInfo.plist](C:/Users/jace0/Desktop/salmon/salmon/ios/Flutter/AppFrameworkInfo.plist) · 앱/프레임워크 메타데이터
- [ios/Flutter/Debug.xcconfig](C:/Users/jace0/Desktop/salmon/salmon/ios/Flutter/Debug.xcconfig)
- [ios/Flutter/Release.xcconfig](C:/Users/jace0/Desktop/salmon/salmon/ios/Flutter/Release.xcconfig)
- [ios/Runner.xcodeproj/project.pbxproj](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner.xcodeproj/project.pbxproj)
- [ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata)
- [ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist) · Xcode 프로젝트·빌드 설정
- [ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings)
- [ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme)
- [ios/Runner.xcworkspace/contents.xcworkspacedata](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner.xcworkspace/contents.xcworkspacedata)
- [ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist) · Xcode 프로젝트·빌드 설정
- [ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings)
- [ios/Runner/AppDelegate.swift](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/AppDelegate.swift)
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json) · 아이콘 크기별 파일 매핑
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png) · 런처 아이콘 리소스
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png) · 런처 아이콘 리소스
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png) · 런처 아이콘 리소스
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png) · 런처 아이콘 리소스
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png) · 런처 아이콘 리소스
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png) · 런처 아이콘 리소스
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png) · 런처 아이콘 리소스
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png) · 런처 아이콘 리소스
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png) · 런처 아이콘 리소스
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png) · 런처 아이콘 리소스
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png) · 런처 아이콘 리소스
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png) · 런처 아이콘 리소스
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png) · 런처 아이콘 리소스
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png) · 런처 아이콘 리소스
- [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png) · 런처 아이콘 리소스
- [ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png) · 네이티브 시작 화면 리소스
- [ios/Runner/Assets.xcassets/LaunchBackground.imageset/Contents.json](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/LaunchBackground.imageset/Contents.json) · 네이티브 시작 화면 리소스
- [ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json) · iOS 시작 이미지·메타데이터
- [ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png) · iOS 시작 이미지·메타데이터
- [ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png) · iOS 시작 이미지·메타데이터
- [ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png) · iOS 시작 이미지·메타데이터
- [ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md) · iOS 시작 이미지·메타데이터
- [ios/Runner/Base.lproj/LaunchScreen.storyboard](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Base.lproj/LaunchScreen.storyboard) · 앱 시작 화면
- [ios/Runner/Base.lproj/Main.storyboard](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Base.lproj/Main.storyboard) · 네이티브 화면·메뉴 리소스
- [ios/Runner/Info.plist](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Info.plist) · 앱/프레임워크 메타데이터
- [ios/Runner/Runner-Bridging-Header.h](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/Runner-Bridging-Header.h) · 네이티브 Flutter 컨테이너·시작 처리
- [ios/Runner/SceneDelegate.swift](C:/Users/jace0/Desktop/salmon/salmon/ios/Runner/SceneDelegate.swift)
- [ios/RunnerTests/RunnerTests.swift](C:/Users/jace0/Desktop/salmon/salmon/ios/RunnerTests/RunnerTests.swift) · 네이티브 테스트

#### macOS (28)

- [macos/.gitignore](C:/Users/jace0/Desktop/salmon/salmon/macos/.gitignore) · Git 제외 규칙
- [macos/Flutter/Flutter-Debug.xcconfig](C:/Users/jace0/Desktop/salmon/salmon/macos/Flutter/Flutter-Debug.xcconfig)
- [macos/Flutter/Flutter-Release.xcconfig](C:/Users/jace0/Desktop/salmon/salmon/macos/Flutter/Flutter-Release.xcconfig)
- [macos/Flutter/GeneratedPluginRegistrant.swift](C:/Users/jace0/Desktop/salmon/salmon/macos/Flutter/GeneratedPluginRegistrant.swift) · Flutter 플러그인 등록
- [macos/Runner.xcodeproj/project.pbxproj](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner.xcodeproj/project.pbxproj)
- [macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist) · Xcode 프로젝트·빌드 설정
- [macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme)
- [macos/Runner.xcworkspace/contents.xcworkspacedata](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner.xcworkspace/contents.xcworkspacedata)
- [macos/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist) · Xcode 프로젝트·빌드 설정
- [macos/Runner/AppDelegate.swift](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/AppDelegate.swift)
- [macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png) · 런처 아이콘 리소스
- [macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png) · 런처 아이콘 리소스
- [macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png) · 런처 아이콘 리소스
- [macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png) · 런처 아이콘 리소스
- [macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png) · 런처 아이콘 리소스
- [macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png) · 런처 아이콘 리소스
- [macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png) · 런처 아이콘 리소스
- [macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json) · 아이콘 크기별 파일 매핑
- [macos/Runner/Base.lproj/MainMenu.xib](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/Base.lproj/MainMenu.xib) · 네이티브 화면·메뉴 리소스
- [macos/Runner/Configs/AppInfo.xcconfig](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/Configs/AppInfo.xcconfig)
- [macos/Runner/Configs/Debug.xcconfig](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/Configs/Debug.xcconfig)
- [macos/Runner/Configs/Release.xcconfig](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/Configs/Release.xcconfig)
- [macos/Runner/Configs/Warnings.xcconfig](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/Configs/Warnings.xcconfig)
- [macos/Runner/DebugProfile.entitlements](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/DebugProfile.entitlements) · macOS 앱 권한 구성
- [macos/Runner/Info.plist](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/Info.plist) · 앱/프레임워크 메타데이터
- [macos/Runner/MainFlutterWindow.swift](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/MainFlutterWindow.swift)
- [macos/Runner/Release.entitlements](C:/Users/jace0/Desktop/salmon/salmon/macos/Runner/Release.entitlements) · macOS 앱 권한 구성
- [macos/RunnerTests/RunnerTests.swift](C:/Users/jace0/Desktop/salmon/salmon/macos/RunnerTests/RunnerTests.swift) · 네이티브 테스트

#### Linux (10)

- [linux/.gitignore](C:/Users/jace0/Desktop/salmon/salmon/linux/.gitignore) · Git 제외 규칙
- [linux/CMakeLists.txt](C:/Users/jace0/Desktop/salmon/salmon/linux/CMakeLists.txt) · CMake 빌드 구성
- [linux/flutter/CMakeLists.txt](C:/Users/jace0/Desktop/salmon/salmon/linux/flutter/CMakeLists.txt) · CMake 빌드 구성
- [linux/flutter/generated_plugin_registrant.cc](C:/Users/jace0/Desktop/salmon/salmon/linux/flutter/generated_plugin_registrant.cc) · Flutter 플러그인 등록
- [linux/flutter/generated_plugin_registrant.h](C:/Users/jace0/Desktop/salmon/salmon/linux/flutter/generated_plugin_registrant.h) · Flutter 플러그인 등록
- [linux/flutter/generated_plugins.cmake](C:/Users/jace0/Desktop/salmon/salmon/linux/flutter/generated_plugins.cmake) · Flutter 플러그인 등록
- [linux/runner/CMakeLists.txt](C:/Users/jace0/Desktop/salmon/salmon/linux/runner/CMakeLists.txt) · CMake 빌드 구성
- [linux/runner/main.cc](C:/Users/jace0/Desktop/salmon/salmon/linux/runner/main.cc)
- [linux/runner/my_application.cc](C:/Users/jace0/Desktop/salmon/salmon/linux/runner/my_application.cc)
- [linux/runner/my_application.h](C:/Users/jace0/Desktop/salmon/salmon/linux/runner/my_application.h)

#### Windows (18)

- [windows/.gitignore](C:/Users/jace0/Desktop/salmon/salmon/windows/.gitignore) · Git 제외 규칙
- [windows/CMakeLists.txt](C:/Users/jace0/Desktop/salmon/salmon/windows/CMakeLists.txt) · CMake 빌드 구성
- [windows/flutter/CMakeLists.txt](C:/Users/jace0/Desktop/salmon/salmon/windows/flutter/CMakeLists.txt) · CMake 빌드 구성
- [windows/flutter/generated_plugin_registrant.cc](C:/Users/jace0/Desktop/salmon/salmon/windows/flutter/generated_plugin_registrant.cc) · Flutter 플러그인 등록
- [windows/flutter/generated_plugin_registrant.h](C:/Users/jace0/Desktop/salmon/salmon/windows/flutter/generated_plugin_registrant.h) · Flutter 플러그인 등록
- [windows/flutter/generated_plugins.cmake](C:/Users/jace0/Desktop/salmon/salmon/windows/flutter/generated_plugins.cmake) · Flutter 플러그인 등록
- [windows/runner/CMakeLists.txt](C:/Users/jace0/Desktop/salmon/salmon/windows/runner/CMakeLists.txt) · CMake 빌드 구성
- [windows/runner/flutter_window.cpp](C:/Users/jace0/Desktop/salmon/salmon/windows/runner/flutter_window.cpp)
- [windows/runner/flutter_window.h](C:/Users/jace0/Desktop/salmon/salmon/windows/runner/flutter_window.h)
- [windows/runner/main.cpp](C:/Users/jace0/Desktop/salmon/salmon/windows/runner/main.cpp)
- [windows/runner/resource.h](C:/Users/jace0/Desktop/salmon/salmon/windows/runner/resource.h)
- [windows/runner/resources/app_icon.ico](C:/Users/jace0/Desktop/salmon/salmon/windows/runner/resources/app_icon.ico) · 런처 아이콘 리소스
- [windows/runner/runner.exe.manifest](C:/Users/jace0/Desktop/salmon/salmon/windows/runner/runner.exe.manifest)
- [windows/runner/Runner.rc](C:/Users/jace0/Desktop/salmon/salmon/windows/runner/Runner.rc)
- [windows/runner/utils.cpp](C:/Users/jace0/Desktop/salmon/salmon/windows/runner/utils.cpp)
- [windows/runner/utils.h](C:/Users/jace0/Desktop/salmon/salmon/windows/runner/utils.h)
- [windows/runner/win32_window.cpp](C:/Users/jace0/Desktop/salmon/salmon/windows/runner/win32_window.cpp)
- [windows/runner/win32_window.h](C:/Users/jace0/Desktop/salmon/salmon/windows/runner/win32_window.h)

#### Web (7)

- [web/favicon.png](C:/Users/jace0/Desktop/salmon/salmon/web/favicon.png) · 브라우저/PWA 아이콘
- [web/icons/Icon-192.png](C:/Users/jace0/Desktop/salmon/salmon/web/icons/Icon-192.png) · 브라우저/PWA 아이콘
- [web/icons/Icon-512.png](C:/Users/jace0/Desktop/salmon/salmon/web/icons/Icon-512.png) · 브라우저/PWA 아이콘
- [web/icons/Icon-maskable-192.png](C:/Users/jace0/Desktop/salmon/salmon/web/icons/Icon-maskable-192.png) · 브라우저/PWA 아이콘
- [web/icons/Icon-maskable-512.png](C:/Users/jace0/Desktop/salmon/salmon/web/icons/Icon-maskable-512.png) · 브라우저/PWA 아이콘
- [web/index.html](C:/Users/jace0/Desktop/salmon/salmon/web/index.html) · Flutter 웹 진입 페이지
- [web/manifest.json](C:/Users/jace0/Desktop/salmon/salmon/web/manifest.json) · 웹 앱 설치 메타데이터

#### 프로젝트 루트 (9)

- [.gitignore](C:/Users/jace0/Desktop/salmon/salmon/.gitignore) · Git 제외 규칙
- [.metadata](C:/Users/jace0/Desktop/salmon/salmon/.metadata)
- [analysis_options.yaml](C:/Users/jace0/Desktop/salmon/salmon/analysis_options.yaml)
- [APP_GUIDE.md](C:/Users/jace0/Desktop/salmon/salmon/APP_GUIDE.md)
- [devtools_options.yaml](C:/Users/jace0/Desktop/salmon/salmon/devtools_options.yaml)
- [flutter_native_splash.yaml](C:/Users/jace0/Desktop/salmon/salmon/flutter_native_splash.yaml) · 네이티브 시작 화면 리소스
- [pubspec.lock](C:/Users/jace0/Desktop/salmon/salmon/pubspec.lock)
- [pubspec.yaml](C:/Users/jace0/Desktop/salmon/salmon/pubspec.yaml)
- [README.md](C:/Users/jace0/Desktop/salmon/salmon/README.md)
