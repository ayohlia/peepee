import 'package:flutter/foundation.dart';

@immutable
class Toilet {
  const Toilet({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.name,
    this.openingHours,
    this.fee,
    this.isWheelchairAccessible,
  });

  final int id;
  final double latitude;
  final double longitude;
  final String? name;
  final String? openingHours;
  final String? fee;
  final bool? isWheelchairAccessible;

  factory Toilet.fromOverpassJson(Map<String, dynamic> json) {
    final tags = json['tags'] as Map<String, dynamic>? ?? {};
    
    bool? wheelchair;
    if (tags['wheelchair'] == 'yes') {
      wheelchair = true;
    } else if (tags['wheelchair'] == 'no') {
      wheelchair = false;
    }

    return Toilet(
      id: json['id'],
      latitude: json['lat'],
      longitude: json['lon'],
      name: tags['name'],
      openingHours: tags['opening_hours'],
      fee: tags['fee'],
      isWheelchairAccessible: wheelchair,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Toilet &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Toilet{id: $id, name: $name, lat: $latitude, lon: $longitude}';
  }
}
