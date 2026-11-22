abstract class AssetsDir {
  static String fontsDir(String fontName) => 'assets/fonts/$fontName';
  static String imagesDir(String imageName) => 'assets/images/$imageName';
  static String iconsDir(String iconName) => 'assets/icons/$iconName';
  static String jsonDir(String jsonName) => 'assets/json/$jsonName';
  static String mushafPage(int page) =>
      'assets/mushaf/pages/page_${page.toString().padLeft(3, '0')}.png';
}
