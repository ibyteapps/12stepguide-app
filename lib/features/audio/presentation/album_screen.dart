import 'package:flutter/material.dart';

import '../../shell/placeholder_page.dart';

class AlbumScreen extends StatelessWidget {
  const AlbumScreen({required this.albumId, super.key});

  final int albumId;

  @override
  Widget build(BuildContext context) => const PlaceholderPage(title: 'Album');
}
