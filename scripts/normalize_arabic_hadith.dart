import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// 1. Enhanced Normalization Function
String normalizeArabic(String text) {
  return text
      // Remove invisible Unicode characters (like U+200F RLM)
      .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF\u200E\u200F]'), '')
      // Remove all Tashkeel/Diacritics
      .replaceAll(RegExp(r'[\u064B-\u065F]'), '')
      // Standardize Alifs
      .replaceAll(RegExp(r'[أإآ]'), 'ا')
      // Standardize Yaa and Taa Marbuta
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      // Clean extra whitespaces
      .trim();
}

Future<void> crawlBook(String bookSlug, String apiKey) async {
  Map<String, String> searchIndex = {};
  int currentPage = 1;
  bool hasNext = true;

  print('\n🚀 Starting crawl for: $bookSlug');

  while (hasNext) {
    final url =
        'https://hadithapi.com/api/hadiths?apiKey=$apiKey&book=$bookSlug&paginate=100&page=$currentPage';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['hadiths'] != null && data['hadiths']['data'] != null) {
          final list = data['hadiths']['data'] as List;

          for (var item in list) {
            String rawArabic = item['hadithArabic'] ?? "";
            // Use number as key, normalized text as value
            searchIndex[item['hadithNumber'].toString()] = normalizeArabic(
              rawArabic,
            );
          }

          stdout.write('\r✅ Page $currentPage processed...'); // Inline update

          hasNext = data['hadiths']['next_page_url'] != null;
          currentPage++;
        } else {
          hasNext = false;
        }

        await Future.delayed(Duration(milliseconds: 600));
      } else {
        print('\n❌ Error at $bookSlug P$currentPage: ${response.statusCode}');
        hasNext = false;
      }
    } catch (e) {
      print('\n🔥 Exception: $e');
      hasNext = false;
    }
  }

  // JsonEncoder.withIndent('  ') creates the readable new-line format you requested
  final encoder = JsonEncoder.withIndent('  ');
  final file = File('$bookSlug.json');
  await file.writeAsString(encoder.convert(searchIndex));
  print('\n💾 Saved $bookSlug.json with ${searchIndex.length} entries.');
}

void main() async {
  const String myApiKey =
      r'$2y$10$Vfjv5y14E1j5pqPcyvvGYm9UXBIFXvQ5xQKgCI7hVcVBRSQ6WZ1C';

  // The list of book slugs to iterate through
  final List<String> books = [
    'sahih-bukhari',
    'sahih-muslim',
    'al-tirmidhi',
    'abu-dawood',
    'ibn-e-majah',
    'sunan-nasai',
    'mishkat',
  ];

  for (String book in books) {
    await crawlBook(book, myApiKey);
  }

  print('\n✨ All books crawled successfully!');
}
