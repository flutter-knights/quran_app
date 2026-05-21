enum Reciter {
  husary('Husary_64kbps', 'محمود خليل الحصري'),
  husaryMuallim('Husary_Muallim_128kbps', 'الحصري (المعلم)'),
  husaryMujawwad('Husary_Mujawwad_128kbps', 'الحصري (مجود)'),
  minshawyMurattal('Minshawy_Murattal_128kbps', 'المنشاوي (مرتل)'),
  // minshawyMujawwad('Minshawy_Mujawwad_64kbps', 'المنشاوي (مجود)'),
  abdulBasitMurattal('Abdul_Basit_Murattal_192kbps', 'عبد الباسط (مرتل)'),
  abdulBasitMujawwad('Abdul_Basit_Mujawwad_128kbps', 'عبد الباسط (مجود)'),
  alafasy('Alafasy_128kbps', 'مشاري راشد العفاسي'),
  sudais('Abdurrahmaan_As-Sudais_192kbps', 'عبد الرحمن السديس'),
  shuraym('Saood_ash-Shuraym_128kbps', 'سعود الشريم'),
  maher('Maher_AlMuaiqly_64kbps', 'ماهر المعيقلي'),
  ghamadi('Ghamadi_40kbps', 'سعد الغامدي'),
  // ajmy('Ahmed_ibn_Ali_al-Ajmy_128kbps', 'أحمد العجمي'),
  qatami('Nasser_Alqatami_128kbps', 'ناصر القطامي'),
  dosary('Yasser_Ad-Dussary_128kbps', 'ياسر الدوسري'),
  shatree('Abu_Bakr_Ash-Shaatree_128kbps', 'أبو بكر الشاطري');
  // faresAbbad('Fares_Abbad_64kbps', 'فارس عباد'),
  // husaryWarsh('Husary_Warsh_64kbps', 'الحصري (ورش)');

  final String folderName;
  final String arabicName;

  const Reciter(this.folderName, this.arabicName);

  String getAyahUrl(int surah, int ayah) {
    const String baseUrl = "https://mirrors.quranicaudio.com/everyayah/";
    String s = surah.toString().padLeft(3, '0');
    String a = ayah.toString().padLeft(3, '0');
    return "$baseUrl$folderName/$s$a.mp3";
  }
}
