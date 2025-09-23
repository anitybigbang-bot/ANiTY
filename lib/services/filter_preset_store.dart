// lib/models/filter_preset.dart
import 'dart:convert';

class FilterPreset {
  final String id;             // 一意ID（作成時に付与）
  String name;                 // 表示名（編集対象）
  final Map<String, dynamic> payload; // フィルタ内容

  FilterPreset({required this.id, required this.name, required this.payload});

  factory FilterPreset.newPreset({required String name, required Map<String, dynamic> payload}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    return FilterPreset(id: id, name: name, payload: payload);
  }

  factory FilterPreset.fromJson(Map<String, dynamic> j) =>
      FilterPreset(id: j['id'] as String, name: j['name'] as String, payload: (j['payload'] as Map).cast<String, dynamic>());

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'payload': payload};

  static List<FilterPreset> listFromJson(List<dynamic> arr) =>
      arr.map((e) => FilterPreset.fromJson((e as Map).cast<String, dynamic>())).toList();

  static String encodeList(List<FilterPreset> list) => jsonEncode(list.map((e) => e.toJson()).toList());
  static List<FilterPreset> decodeList(String raw) => listFromJson(jsonDecode(raw) as List<dynamic>);
}