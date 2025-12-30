class Location {
  final double latitude;
  final double longitude;
  final String? country;
  final String? enCountry;
  final String? city;
  final String? enCity;
  Location({
    required this.latitude,
    required this.longitude,
    this.country,
    this.city,
    this.enCountry,
    this.enCity,
  });
}
