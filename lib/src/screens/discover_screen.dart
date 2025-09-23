
import 'package:flutter/material.dart';
import '../mock_data.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: ListView(
        children: mockAnimes.map((a) => ListTile(title: Text(a.title))).toList(),
      ),
    );
  }
}
