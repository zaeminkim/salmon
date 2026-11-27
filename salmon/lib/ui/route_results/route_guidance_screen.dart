import 'package:flutter/material.dart';

class RouteGuidanceScreen extends StatelessWidget {
  const RouteGuidanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: const Text('경로 안내')),
    );
  }
}
