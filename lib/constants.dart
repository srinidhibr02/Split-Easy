import 'package:flutter/material.dart';

const black = Colors.black;
const white = Colors.white;
const primary = Color(0xFF0cc0df);
const secondary = Color(0xFF0ae3f9);

const h1 = TextStyle(fontSize: 35, fontWeight: FontWeight.w500);
const h2 = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.normal,
  color: primary,
);
const body = TextStyle(fontSize: 15);

final List<Map<String, dynamic>> purposes = [
  {"label": "Trip", "icon": Icons.airplanemode_active},
  {"label": "Group", "icon": Icons.group},
  {"label": "Family", "icon": Icons.family_restroom},
  {"label": "Couple", "icon": Icons.favorite},
  {"label": "Others", "icon": Icons.widgets},
];

final List<String> avatar = [
  "https://cdn-icons-png.flaticon.com/512/4140/4140037.png",
  "https://cdn-icons-png.flaticon.com/512/4140/4140047.png",
  "https://cdn-icons-png.flaticon.com/512/4140/4140051.png",
  "https://cdn-icons-png.flaticon.com/512/4140/4140040.png",
  "https://cdn-icons-png.flaticon.com/512/6997/6997662.png",
  "https://cdn-icons-png.flaticon.com/512/6997/6997668.png",
  "https://cdn-icons-png.flaticon.com/512/6997/6997675.png",
  "https://cdn-icons-png.flaticon.com/512/4140/4140038.png",
  "https://cdn-icons-png.flaticon.com/512/4140/4140041.png",
];

IconData getPurposeIcon(String? label) {
  final purpose = purposes.firstWhere(
    (p) => p["label"] == label,
    orElse: () => {"icon": Icons.group}, // default fallback
  );
  return purpose["icon"] as IconData;
}
