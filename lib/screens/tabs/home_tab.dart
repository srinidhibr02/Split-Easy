import 'package:flutter/material.dart';

class HomeTab extends StatelessWidget {
  // ignore: use_super_parameters
  const HomeTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text("Welcome to Home", style: TextStyle(fontSize: 20)),
    );
  }
}
