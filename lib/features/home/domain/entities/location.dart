class Location {
  final double latitude;
  final double longitude;
  final String? country;
  final String? city;
  Location({
    required this.latitude,
    required this.longitude,
    this.country,
    this.city,
  });
}
