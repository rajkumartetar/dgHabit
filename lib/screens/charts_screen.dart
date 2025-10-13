import 'package:flutter/material.dart';

class ChartsScreen extends StatelessWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charts (Coming Soon)')),
      body: const Center(
        child: Text('Charts will appear here once the chart library is reintroduced.'),
      ),
    );
  }
}
