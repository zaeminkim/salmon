import 'package:flutter/material.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart';

/// 카카오맵 데모의 예시 핀과 경로선을 그립니다.
Future<void> addDemoMapOverlays(
  BuildContext context,
  KakaoMapController controller, {
  required LatLng cityHall,
  required LatLng seoulStation,
}) async {
  // 이미지가 로딩된 상태에서 합성하도록 미리 준비합니다.
  const pinImage = AssetImage('assets/images/location-pin.png');

  await precacheImage(pinImage, context);
  if (!context.mounted) return;

  final destinationIcon = await KImage.fromWidget(
    Stack(
      fit: StackFit.expand,
      children: [
        const Image(image: pinImage, fit: BoxFit.fill),
        Positioned(
          top: 14,
          left: 4,
          right: 4,
          child: const Text(
            '도착지',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 7,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
    const Size(28, 36),
    context: context,
  );

  if (!context.mounted) return;

  await controller.labelLayer.addPoi(
    seoulStation,
    id: 'seoul-station',
    style: PoiStyle(icon: destinationIcon, anchor: const KPoint(0.5, 1.0)),
  );

  await controller.routeLayer.addRoute(
    [cityHall, LatLng(37.5600, 126.9750), seoulStation],
    RouteStyle(
      Colors.orange,
      16.0,
      strokeColor: Colors.white,
      strokeWidth: 2.0,
    ),
  );

  await controller.lodLabelLayer.addLodPoi(
    cityHall,
    text: '서울시청',
    style: PoiStyle(
      icon: KImage.fromAsset('assets/images/location-pin.png', 24, 36),
      textStyle: const [PoiTextStyle(size: 20, color: Colors.black)],
    ),
  );

  // await controller.labelLayer.addPolylineText('시청에서 서울역 방향', const [
  //   _cityHall,
  //   LatLng(37.5600, 126.9750),
  //   _seoulStation,
  // ], style: PolylineTextStyle(24, Colors.deepPurple));
}
