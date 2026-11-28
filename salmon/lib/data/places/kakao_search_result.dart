// 검색 API의 문자열 좌표를 앱에서 사용할 숫자로 변환합니다.
// 공통 데이터 타입을 선언
class KakaoSearchResult {
  const KakaoSearchResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.isAddress,
    this.placeId,
    this.category = '',
  });

  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final bool isAddress;
  final String? placeId;
  final String category;

  static KakaoSearchResult? fromDocument(
    Map<String, dynamic> document, {
    required bool isAddress,
  }) {
    final latitude = double.tryParse('${document['y']}');
    final longitude = double.tryParse('${document['x']}');
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }

    final roadAddress = document['road_address_name'] as String? ?? '';
    final address = document['address_name'] as String? ?? '';
    return KakaoSearchResult(
      name: isAddress ? address : document['place_name'] as String? ?? '',
      address: roadAddress.isNotEmpty ? roadAddress : address,
      latitude: latitude,
      longitude: longitude,
      isAddress: isAddress,
      placeId: document['id'] as String?,
      category: document['category_name'] as String? ?? '',
    );
  }

  // 이후 백엔드 연동 시 이 정보를 요청 본문으로 사용할 수 있습니다.
  Map<String, Object?> toJson() => {
    'provider': 'kakao',
    'type': isAddress ? 'address' : 'place',
    'placeId': placeId,
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
  };
}
