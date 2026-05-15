import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran/quran.dart' as quran;

import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';

class AyahActionSheet extends StatelessWidget {
  const AyahActionSheet({super.key, required this.ayah});

  final AyahIdentifier ayah;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Play from here'),
            onTap: () => Navigator.of(context).pop(_Action.play),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Tafsir'),
            onTap: () => Navigator.of(context).pop(_Action.tafsir),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('Bookmark'),
            onTap: () => Navigator.of(context).pop(_Action.bookmark),
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy'),
            onTap: () async {
              final text = quran.getVerse(ayah.surah, ayah.ayah);
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) Navigator.of(context).pop(_Action.copy);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () => Navigator.of(context).pop(_Action.share),
          ),
        ],
      ),
    );
  }
}

enum _Action { play, tafsir, bookmark, copy, share }
