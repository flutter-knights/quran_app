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

  static String m0(weekday, day, month, year) =>
      "${weekday}، ${day} ${month} ${year} هـ";

  static String m1(time, prayerName) => "متبقي ${time} على صلاة ${prayerName}";

  static String m2(surah, ayah) => "سورة ${surah}، الآية ${ayah}";

  static String m3(page) => "الصفحة ${page}";

  static String m4(minutes) => "قبل ${minutes} د";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "abu_dawood": MessageLookupByLibrary.simpleMessage("سنن أبي داود"),
    "al_silsila_sahiha": MessageLookupByLibrary.simpleMessage(
      "السلسلة الصحيحة",
    ),
    "al_tirmidhi": MessageLookupByLibrary.simpleMessage("جامع الترمذي"),
    "arabicLanguage": MessageLookupByLibrary.simpleMessage("اللغة العربية"),
    "arabic_label": MessageLookupByLibrary.simpleMessage("العربية"),
    "adhanPerPrayerSection": MessageLookupByLibrary.simpleMessage("الأذان لكل صلاة"),
    "asr": MessageLookupByLibrary.simpleMessage("العصر"),
    "author_abu_dawood": MessageLookupByLibrary.simpleMessage(
      "الإمام أبو داود السجستاني",
    ),
    "author_ahmad": MessageLookupByLibrary.simpleMessage("الإمام أحمد بن حنبل"),
    "author_albani": MessageLookupByLibrary.simpleMessage(
      "الإمام محمد ناصر الدين الألباني",
    ),
    "author_bukhari": MessageLookupByLibrary.simpleMessage(
      "الإمام محمد بن إسماعيل البخاري",
    ),
    "author_ibn_majah": MessageLookupByLibrary.simpleMessage(
      "الإمام محمد بن يزيد ابن ماجه القزويني",
    ),
    "author_mishkat": MessageLookupByLibrary.simpleMessage(
      "الإمام الخطيب التبريزي",
    ),
    "author_muslim": MessageLookupByLibrary.simpleMessage(
      "الإمام مسلم بن الحجاج النيسابوري",
    ),
    "author_nasai": MessageLookupByLibrary.simpleMessage(
      "الإمام أحمد بن شعيب النسائي",
    ),
    "author_tirmidhi": MessageLookupByLibrary.simpleMessage(
      "الإمام محمد بن عيسى الترمذي",
    ),
    "chapter_label": MessageLookupByLibrary.simpleMessage("باب"),
    "darkMode": MessageLookupByLibrary.simpleMessage("الوضع الداكن"),
    "death_abu_dawood": MessageLookupByLibrary.simpleMessage("٢٧٥ هـ"),
    "death_ahmad": MessageLookupByLibrary.simpleMessage("٢٤١ هـ"),
    "death_albani": MessageLookupByLibrary.simpleMessage("١٤٢٠ هـ"),
    "death_bukhari": MessageLookupByLibrary.simpleMessage("٢٥٦ هـ"),
    "death_ibn_majah": MessageLookupByLibrary.simpleMessage("٢٧٣ هـ"),
    "death_mishkat": MessageLookupByLibrary.simpleMessage("٧٤١ هـ"),
    "death_muslim": MessageLookupByLibrary.simpleMessage("٢٦١ هـ"),
    "death_nasai": MessageLookupByLibrary.simpleMessage("٣٠٣ هـ"),
    "death_tirmidhi": MessageLookupByLibrary.simpleMessage("٢٧٩ هـ"),
    "dhuhr": MessageLookupByLibrary.simpleMessage("الظهر"),
    "fajr": MessageLookupByLibrary.simpleMessage("الفجر"),
    "full_title_abu_dawood": MessageLookupByLibrary.simpleMessage(
      "سنن أبي داود",
    ),
    "full_title_ahmad": MessageLookupByLibrary.simpleMessage(
      "مسند الإمام أحمد بن حنبل",
    ),
    "full_title_albani": MessageLookupByLibrary.simpleMessage(
      "السلسلة الصحيحة",
    ),
    "full_title_bukhari": MessageLookupByLibrary.simpleMessage(
      "الجامع المسند الصحيح المختصر",
    ),
    "full_title_ibn_majah": MessageLookupByLibrary.simpleMessage(
      "سنن ابن ماجه",
    ),
    "full_title_mishkat": MessageLookupByLibrary.simpleMessage(
      "مشكاة المصابيح",
    ),
    "full_title_muslim": MessageLookupByLibrary.simpleMessage(
      "المسند الصحيح المختصر",
    ),
    "full_title_nasai": MessageLookupByLibrary.simpleMessage("سنن النسائي"),
    "full_title_tirmidhi": MessageLookupByLibrary.simpleMessage("جامع الترمذي"),
    "hadith_heading_label": MessageLookupByLibrary.simpleMessage(
      "عنوان الحديث",
    ),
    "hadith_number_label": MessageLookupByLibrary.simpleMessage("حديث رقم"),
    "hadith_total_label": MessageLookupByLibrary.simpleMessage(
      "إجمالي الأحاديث",
    ),
    "hijriDateWithDay": m0,
    "ibn_e_majah": MessageLookupByLibrary.simpleMessage("سنن ابن ماجه"),
    "isha": MessageLookupByLibrary.simpleMessage("العشاء"),
    "maghrib": MessageLookupByLibrary.simpleMessage("المغرب"),
    "mishkat": MessageLookupByLibrary.simpleMessage("مشكاة المصابيح"),
    "musnad_ahmad": MessageLookupByLibrary.simpleMessage("مسند أحمد"),
    "remainingTimeLabel": m1,
    "sahih_bukhari": MessageLookupByLibrary.simpleMessage("صحيح البخاري"),
    "sahih_muslim": MessageLookupByLibrary.simpleMessage("صحيح مسلم"),
    "settings": MessageLookupByLibrary.simpleMessage("الإعدادات"),
    "status_daeef": MessageLookupByLibrary.simpleMessage("ضعيف"),
    "status_hasan": MessageLookupByLibrary.simpleMessage("حسن"),
    "status_mudu": MessageLookupByLibrary.simpleMessage("موضوع"),
    "status_sahih": MessageLookupByLibrary.simpleMessage("صحيح"),
    "sunan_nasai": MessageLookupByLibrary.simpleMessage("سنن النسائي"),
    "sunrise": MessageLookupByLibrary.simpleMessage("الشروق"),
    "translation_label": MessageLookupByLibrary.simpleMessage("الترجمة"),
    "twentyFourHourFormat": MessageLookupByLibrary.simpleMessage(
      "تنسيق 24 ساعة",
    ),
    "tafsir": MessageLookupByLibrary.simpleMessage("تفسير"),
    "translation": MessageLookupByLibrary.simpleMessage("ترجمة"),
    "play": MessageLookupByLibrary.simpleMessage("تشغيل"),
    "bookmark": MessageLookupByLibrary.simpleMessage("حفظ"),
    "share": MessageLookupByLibrary.simpleMessage("مشاركة"),
    "coming_soon": MessageLookupByLibrary.simpleMessage("قريبًا"),
    "bookmark_added": MessageLookupByLibrary.simpleMessage("تم الحفظ"),
    "bookmark_removed": MessageLookupByLibrary.simpleMessage("تم إزالة الحفظ"),
    "bookmark_save_failed": MessageLookupByLibrary.simpleMessage(
      "تعذّر حفظ المرجعية",
    ),
    "share_failed": MessageLookupByLibrary.simpleMessage(
      "تعذّر فتح نافذة المشاركة",
    ),
    "playback_pause": MessageLookupByLibrary.simpleMessage("إيقاف مؤقت"),
    "playback_next": MessageLookupByLibrary.simpleMessage("الآية التالية"),
    "playback_previous": MessageLookupByLibrary.simpleMessage("الآية السابقة"),
    "playback_restart": MessageLookupByLibrary.simpleMessage("إعادة"),
    "playback_close": MessageLookupByLibrary.simpleMessage("إغلاق"),
    "playback_speed": MessageLookupByLibrary.simpleMessage("السرعة"),
    "reciter_label": MessageLookupByLibrary.simpleMessage("القارئ"),
    "continue_reading": MessageLookupByLibrary.simpleMessage("متابعة التلاوة"),
    "ayah_label": m2,
    "page_label": m3,
    "play_surah": MessageLookupByLibrary.simpleMessage("تشغيل السورة"),
    "playTestAdhan": MessageLookupByLibrary.simpleMessage("تشغيل أذان تجريبي"),
    "pinnedPrayerTimes": MessageLookupByLibrary.simpleMessage("أوقات الصلاة المثبتة"),
    "pinnedPrayerTimesSubtitle": MessageLookupByLibrary.simpleMessage(
      "اعرض صلوات اليوم في شريط الإشعارات",
    ),
    "notifications": MessageLookupByLibrary.simpleMessage("الإشعارات"),
    "notificationsScreenSubtitle": MessageLookupByLibrary.simpleMessage("إدارة إشعارات أوقات الصلاة."),
    "reminderLabel": MessageLookupByLibrary.simpleMessage("ذكرني"),
    "reminderOff": MessageLookupByLibrary.simpleMessage("لا"),
    "reminderMinutesBefore": m4,
    "testAdhanScheduledSnack": MessageLookupByLibrary.simpleMessage("أذان تجريبي خلال ٥ ثوانٍ"),
  };
}
