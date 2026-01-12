import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  const apiKey = "\$2y\$10\$Vfjv5y14E1j5pqPcyvvGYm9UXBIFXvQ5xQKgCI7hVcVBRSQ6WZ1C";
  const bookSlugs = [
    "sahih-bukhari",
    "sahih-muslim",
    "al-tirmidhi",
    "abu-dawood",
    "ibn-e-majah",
    "sunan-nasai",
    "mishkat",
    "musnad-ahmad",
    "al-silsila-sahiha",
  ];

  Map<String, dynamic> allChapters = {};

  print("🚀 Starting fetch with Dio...");

  try {
    await Future.wait(
      bookSlugs.map((slug) async {
        try {
          final response = await dio.get(
            "https://hadithapi.com/api/$slug/chapters",
            queryParameters: {"apiKey": apiKey},
          );

          if (response.statusCode == 200) {
            final List chaptersRaw = response.data['chapters'];

            allChapters[slug] = chaptersRaw.map((ch) {
              // Extract the chapter number as an integer
              // Using tryParse to handle cases where the API might send non-numeric strings
              final rawNumber = ch['chapterNumber'].toString();
              final int chapterInt = int.tryParse(rawNumber) ?? 0;

              return {
                "id": ch['id'],
                "chapterNumber": chapterInt, // Now a pure integer
                "chapterArabic": ch['chapterArabic'],
                "chapterEnglish": ch['chapterEnglish'],
              };
            }).toList();

            print("✅ Fetched: $slug");
          }
        } on DioException catch (e) {
          print("⚠️ Failed to fetch $slug: ${e.message}");
        }
      }),
    );

    // Convert to JSON with indentation
    String jsonString = const JsonEncoder.withIndent('  ').convert(allChapters);

    // Personalization: Remove outer curly braces and add trailing comma
    // This allows you to append this content into an existing JSON object if needed
    if (jsonString.startsWith('{') && jsonString.endsWith('}')) {
      jsonString = jsonString.substring(1, jsonString.length - 1).trim();
    }
    
    // Ensure the final output ends with a trailing comma as requested
    if (!jsonString.endsWith(',')) {
      jsonString = "$jsonString,";
    }

    final file = File('all_chapters.json');
    await file.writeAsString(jsonString);

    print("\n✨ Done! Saved to ${file.path}");
    print("📌 Note: chapterNumber is now stored as an integer.");
  } catch (err) {
    print("❌ Critical Error: $err");
  } finally {
    dio.close();
  }
}