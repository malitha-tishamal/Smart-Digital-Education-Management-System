import 'package:flutter/material.dart';

/// Loading screen while Firebase initializes.
class FirebaseLoadCheckScreen extends StatelessWidget {
  const FirebaseLoadCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}