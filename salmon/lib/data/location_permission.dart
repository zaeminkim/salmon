import 'package:geolocator/geolocator.dart' as geo;

/// 위치 서비스와 권한 상태를 확인하고 필요한 조치를 호출 화면에 전달합니다.
// geolocator
// 위치 서비스와 권한을 확인하는 함수
Future<bool> checkLocationPermission({
  required bool requestPermission,
  required void Function(String) onMessage,
}) async {
  final enabled = await geo.Geolocator.isLocationServiceEnabled();

  if (!enabled) {
    onMessage('기기 설정에서 위치 기능을 켠 뒤 현재 위치 버튼을 눌러 주세요.');
    return false;
  }

  var permission = await geo.Geolocator.checkPermission();

  if (permission == geo.LocationPermission.denied && requestPermission) {
    permission = await geo.Geolocator.requestPermission();
  }

  if (permission == geo.LocationPermission.deniedForever) {
    onMessage('Android 설정 → 앱 → salmon → 권한에서 위치를 허용해 주세요.');
    return false;
  }

  final allowed =
      permission == geo.LocationPermission.whileInUse ||
      permission == geo.LocationPermission.always;

  if (!allowed) {
    onMessage('현재 위치를 표시하려면 위치 권한이 필요합니다.');
  }

  return allowed;
}
