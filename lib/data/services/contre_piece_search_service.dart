import 'package:csv/csv.dart';
import 'package:flutter/services.dart';

class ContrePieceSearchService {
  ContrePieceSearchService({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  static const String _assetPath = 'contre pièce/contre_pieces.csv';

  final AssetBundle _bundle;
  List<String>? _cache;

  Future<void> initialize() => _load();

  List<String> suggest(String query, {int limit = 12}) {
    final values = _cache ?? const <String>[];
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return values.take(limit).toList(growable: false);
    }

    final startsWith = <String>[];
    final contains = <String>[];
    for (final value in values) {
      final normalized = _normalize(value);
      if (normalized.startsWith(normalizedQuery)) {
        startsWith.add(value);
      } else if (normalized.contains(normalizedQuery)) {
        contains.add(value);
      }
      if (startsWith.length >= limit) {
        break;
      }
    }

    return <String>[...startsWith, ...contains]
        .take(limit)
        .toList(growable: false);
  }

  Future<void> _load() async {
    final cached = _cache;
    if (cached != null) {
      return;
    }

    final raw = await _bundle.loadString(_assetPath);
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(raw);
    final values = <String>{};
    for (final row in rows.skip(1)) {
      if (row.isEmpty) {
        continue;
      }
      final value = row.first.toString().trim();
      if (value.isNotEmpty) {
        values.add(value);
      }
    }

    final sorted = values.toList()..sort();
    _cache = List<String>.unmodifiable(sorted);
  }

  static String _normalize(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }
}
