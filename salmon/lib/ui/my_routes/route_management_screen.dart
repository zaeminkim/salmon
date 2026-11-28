import 'package:flutter/material.dart';

class RouteManagementScreen extends StatelessWidget {
  const RouteManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: -4,
        title: const Text(
          '경로 관리',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
