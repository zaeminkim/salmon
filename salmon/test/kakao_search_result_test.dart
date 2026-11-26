import 'package:flutter_test/flutter_test.dart';
import 'package:salmon/ui/route_search/routesearch_screen.dart';

void main() {
  test('장소 응답의 좌표와 도로명 주소를 선택 정보로 변환한다', () {
    final result = KakaoSearchResult.fromDocument({
      'id': '123',
      'place_name': '테스트 장소',
      'address_name': '지번 주소',
      'road_address_name': '도로명 주소',
      'x': '126.9780',
      'y': '37.5665',
    }, isAddress: false)!;
    expect(result.toJson(), {
      'provider': 'kakao',
      'type': 'place',
      'placeId': '123',
      'name': '테스트 장소',
      'address': '도로명 주소',
      'latitude': 37.5665,
      'longitude': 126.9780,
    });
  });

  test('장소 ID가 없는 주소 응답도 처리한다', () {
    final result = KakaoSearchResult.fromDocument({
      'address_name': '서울특별시 중구 세종대로 110',
      'x': '126.9780',
      'y': '37.5665',
    }, isAddress: true)!;
    expect(result.name, result.address);
    expect(result.placeId, isNull);
    expect(result.toJson()['type'], 'address');
  });

  test('좌표가 없거나 유효하지 않은 후보를 제외한다', () {
    for (final x in [null, '', 'invalid', 'NaN', 'Infinity', '181']) {
      expect(
        KakaoSearchResult.fromDocument({
          'x': x,
          'y': '37.5665',
        }, isAddress: false),
        isNull,
      );
    }
    expect(
      KakaoSearchResult.fromDocument({
        'x': '126.9780',
        'y': '91',
      }, isAddress: true),
      isNull,
    );
  });
}
