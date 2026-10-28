import 'package:flutter/material.dart';
import '../core/dashboard_wrapper.dart';

class SimplePreloadScreen extends StatelessWidget {
  const SimplePreloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardWrapper()),
      );
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}