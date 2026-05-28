// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ar locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'ar';

  static String m0(count) => "${count} حديث";

  static String m1(surah, ayah) => "سورة ${surah}، الآية ${ayah}";

  static String m2(count) => "${count} كتب";

  static String m3(weekday, day, month, year) =>
      "${weekday}، ${day} ${month} ${year} هـ";

  static String m4(page) => "الصفحة ${page}";

  static String m5(percent) => "${percent}% مكتمل";

  static String m6(time, prayerName) => "متبقي ${time} على صلاة ${prayerName}";

  static String m7(minutes) => "قبل ${minutes} د";

  static String m8(count) => "${count} سورة";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "abu_dawood": MessageLookupByLibrary.simpleMessage("سنن أبي داود"),
        "adhanPerPrayerSection":
            MessageLookupByLibrary.simpleMessage("الأذان لكل صلاة"),
        "ahadith_count": m0,
        "ahadith_section": MessageLookupByLibrary.simpleMessage("الأحاديث"),
        "al_silsila_sahiha":
            MessageLookupByLibrary.simpleMessage("السلسلة الصحيحة"),
        "al_tirmidhi": MessageLookupByLibrary.simpleMessage("جامع الترمذي"),
        "all_surahs": MessageLookupByLibrary.simpleMessage("جميع السور"),
        "appearance_section": MessageLookupByLibrary.simpleMessage("المظهر"),
        "arabicLanguage": MessageLookupByLibrary.simpleMessage("اللغة العربية"),
        "arabic_label": MessageLookupByLibrary.simpleMessage("العربية"),
        "asr": MessageLookupByLibrary.simpleMessage("العصر"),
        "author_abu_dawood":
            MessageLookupByLibrary.simpleMessage("الإمام أبو داود السجستاني"),
        "author_albani":
            MessageLookupByLibrary.simpleMessage("محمد ناصر الدين الألباني"),
        "author_bukhari": MessageLookupByLibrary.simpleMessage(
            "الإمام محمد بن إسماعيل البخاري"),
        "author_ibn_majah": MessageLookupByLibrary.simpleMessage(
            "الإمام محمد بن يزيد ابن ماجه القزويني"),
        "author_muslim": MessageLookupByLibrary.simpleMessage(
            "الإمام مسلم بن الحجاج النيسابوري"),
        "author_nasai":
            MessageLookupByLibrary.simpleMessage("الإمام أحمد بن شعيب النسائي"),
        "author_tirmidhi":
            MessageLookupByLibrary.simpleMessage("الإمام محمد بن عيسى الترمذي"),
        "ayah_label": m1,
        "bookmark": MessageLookupByLibrary.simpleMessage("حفظ"),
        "bookmark_added": MessageLookupByLibrary.simpleMessage("تم الحفظ"),
        "bookmark_removed":
            MessageLookupByLibrary.simpleMessage("تم إزالة الحفظ"),
        "bookmark_save_failed":
            MessageLookupByLibrary.simpleMessage("تعذّر حفظ المرجعية"),
        "bookmarks_screen_title":
            MessageLookupByLibrary.simpleMessage("الإشارات"),
        "books_count": m2,
        "books_section": MessageLookupByLibrary.simpleMessage("الكتب"),
        "chapter_label": MessageLookupByLibrary.simpleMessage("باب"),
        "collections_label": MessageLookupByLibrary.simpleMessage("المجموعات"),
        "coming_soon": MessageLookupByLibrary.simpleMessage("قريبًا"),
        "continue_reading":
            MessageLookupByLibrary.simpleMessage("متابعة التلاوة"),
        "darkMode": MessageLookupByLibrary.simpleMessage("الوضع الداكن"),
        "death_abu_dawood": MessageLookupByLibrary.simpleMessage("٢٧٥ هـ"),
        "death_albani": MessageLookupByLibrary.simpleMessage("١٤٢٠ هـ"),
        "death_bukhari": MessageLookupByLibrary.simpleMessage("٢٥٦ هـ"),
        "death_ibn_majah": MessageLookupByLibrary.simpleMessage("٢٧٣ هـ"),
        "death_muslim": MessageLookupByLibrary.simpleMessage("٢٦١ هـ"),
        "death_nasai": MessageLookupByLibrary.simpleMessage("٣٠٣ هـ"),
        "death_tirmidhi": MessageLookupByLibrary.simpleMessage("٢٧٩ هـ"),
        "dhuhr": MessageLookupByLibrary.simpleMessage("الظهر"),
        "fajr": MessageLookupByLibrary.simpleMessage("الفجر"),
        "full_title_abu_dawood":
            MessageLookupByLibrary.simpleMessage("سنن أبي داود"),
        "full_title_albani":
            MessageLookupByLibrary.simpleMessage("السلسلة الصحيحة"),
        "full_title_bukhari": MessageLookupByLibrary.simpleMessage(
            "الجامع المسند الصحيح المختصر"),
        "full_title_ibn_majah":
            MessageLookupByLibrary.simpleMessage("سنن ابن ماجه"),
        "full_title_muslim":
            MessageLookupByLibrary.simpleMessage("المسند الصحيح المختصر"),
        "full_title_nasai": MessageLookupByLibrary.simpleMessage("سنن النسائي"),
        "full_title_tirmidhi":
            MessageLookupByLibrary.simpleMessage("جامع الترمذي"),
        "general_section": MessageLookupByLibrary.simpleMessage("عام"),
        "hadith_books_appbar_title":
            MessageLookupByLibrary.simpleMessage("الحديث الشريف"),
        "hadith_heading_label":
            MessageLookupByLibrary.simpleMessage("عنوان الحديث"),
        "hadith_number_label": MessageLookupByLibrary.simpleMessage("حديث رقم"),
        "hadith_screen_title":
            MessageLookupByLibrary.simpleMessage("الحديث الشريف"),
        "hadith_total_label":
            MessageLookupByLibrary.simpleMessage("إجمالي الأحاديث"),
        "hijriDateWithDay": m3,
        "ibn_e_majah": MessageLookupByLibrary.simpleMessage("سنن ابن ماجه"),
        "isha": MessageLookupByLibrary.simpleMessage("العشاء"),
        "lastRead": MessageLookupByLibrary.simpleMessage("آخر قراءة"),
        "madaniyya": MessageLookupByLibrary.simpleMessage("مدنية"),
        "maghrib": MessageLookupByLibrary.simpleMessage("المغرب"),
        "makkiyya": MessageLookupByLibrary.simpleMessage("مكية"),
        "mishkat": MessageLookupByLibrary.simpleMessage("مشكاة المصابيح"),
        "musnad_ahmad": MessageLookupByLibrary.simpleMessage("مسند أحمد"),
        "narrator_label": MessageLookupByLibrary.simpleMessage("الراوي"),
        "next_hadith": MessageLookupByLibrary.simpleMessage("التالي"),
        "notifications": MessageLookupByLibrary.simpleMessage("الإشعارات"),
        "notificationsScreenSubtitle":
            MessageLookupByLibrary.simpleMessage("إدارة إشعارات أوقات الصلاة."),
        "page_label": m4,
        "pinnedPrayerTimes":
            MessageLookupByLibrary.simpleMessage("أوقات الصلاة المثبتة"),
        "pinnedPrayerTimesSubtitle": MessageLookupByLibrary.simpleMessage(
            "اعرض صلوات اليوم في شريط الإشعارات"),
        "play": MessageLookupByLibrary.simpleMessage("تشغيل"),
        "playTestAdhan":
            MessageLookupByLibrary.simpleMessage("تشغيل أذان تجريبي"),
        "play_surah": MessageLookupByLibrary.simpleMessage("تشغيل السورة"),
        "playback_close": MessageLookupByLibrary.simpleMessage("إغلاق"),
        "playback_next": MessageLookupByLibrary.simpleMessage("الآية التالية"),
        "playback_pause": MessageLookupByLibrary.simpleMessage("إيقاف مؤقت"),
        "playback_previous":
            MessageLookupByLibrary.simpleMessage("الآية السابقة"),
        "playback_restart": MessageLookupByLibrary.simpleMessage("إعادة"),
        "playback_speed": MessageLookupByLibrary.simpleMessage("السرعة"),
        "prayers": MessageLookupByLibrary.simpleMessage("الصلوات"),
        "progress_complete": m5,
        "quickAccess": MessageLookupByLibrary.simpleMessage("الوصول السريع"),
        "quran_screen_title":
            MessageLookupByLibrary.simpleMessage("القرآن الكريم"),
        "reciter_label": MessageLookupByLibrary.simpleMessage("القارئ"),
        "remainingTimeLabel": m6,
        "reminderLabel": MessageLookupByLibrary.simpleMessage("ذكرني"),
        "reminderMinutesBefore": m7,
        "reminderOff": MessageLookupByLibrary.simpleMessage("لا"),
        "sahih_bukhari": MessageLookupByLibrary.simpleMessage("صحيح البخاري"),
        "sahih_muslim": MessageLookupByLibrary.simpleMessage("صحيح مسلم"),
        "search_surah_hint":
            MessageLookupByLibrary.simpleMessage("ابحث عن سورة..."),
        "settings": MessageLookupByLibrary.simpleMessage("الإعدادات"),
        "settings_screen_title":
            MessageLookupByLibrary.simpleMessage("الإعدادات"),
        "share": MessageLookupByLibrary.simpleMessage("مشاركة"),
        "share_failed":
            MessageLookupByLibrary.simpleMessage("تعذّر فتح نافذة المشاركة"),
        "status_daeef": MessageLookupByLibrary.simpleMessage("ضعيف"),
        "status_hasan": MessageLookupByLibrary.simpleMessage("حسن"),
        "status_mudu": MessageLookupByLibrary.simpleMessage("موضوع"),
        "status_sahih": MessageLookupByLibrary.simpleMessage("صحيح"),
        "sunan_nasai": MessageLookupByLibrary.simpleMessage("سنن النسائي"),
        "sunrise": MessageLookupByLibrary.simpleMessage("الشروق"),
        "surahs_appbar_title": MessageLookupByLibrary.simpleMessage("السور"),
        "surahs_count": m8,
        "tafsir": MessageLookupByLibrary.simpleMessage("تفسير"),
        "testAdhanScheduledSnack":
            MessageLookupByLibrary.simpleMessage("أذان تجريبي خلال ٥ ثوانٍ"),
        "the_noble_quran":
            MessageLookupByLibrary.simpleMessage("القرآن الكريم"),
        "translation": MessageLookupByLibrary.simpleMessage("ترجمة"),
        "translation_label": MessageLookupByLibrary.simpleMessage("الترجمة"),
        "twentyFourHourFormat":
            MessageLookupByLibrary.simpleMessage("تنسيق 24 ساعة")
      };
}
