// `dart run tool/flutter_figma_bridge/scan_tokens.dart [--root lib]` 로 실행.
// lib/ 트리에서 raw color/spacing/typography/radius 값을 수집·클러스터링해 stdout에 JSON 출력.

import 'dart:io';
import 'dart:math' as math;
import 'models.dart';

final _colorHex = RegExp(r'Color\(\s*0x([0-9A-Fa-f]{8})\s*\)');
final _edgeInsetsAll = RegExp(r'EdgeInsets\.all\(\s*(\d+(?:\.\d+)?)\s*\)');
final _edgeInsetsSymHoriz = RegExp(
  r'EdgeInsets\.symmetric\([^)]*?\bhorizontal:\s*(\d+(?:\.\d+)?)',
);
final _edgeInsetsSymVert = RegExp(
  r'EdgeInsets\.symmetric\([^)]*?\bvertical:\s*(\d+(?:\.\d+)?)',
);
final _sizedBox = RegExp(
  r'SizedBox\(\s*(?:height|width):\s*(\d+(?:\.\d+)?)',
);
final _borderRadius = RegExp(
  r'BorderRadius\.circular\(\s*(\d+(?:\.\d+)?)\s*\)',
);
final _textStyle = RegExp(
  r'TextStyle\(([^)]*)\)',
  multiLine: true,
  dotAll: true,
);

double? _parseNum(String? s) => s == null ? null : double.tryParse(s);

/// --root 인자를 파싱한다. 값이 없으면 'lib'를 반환하고, 플래그만 있고 값이 없으면 오류로 종료한다.
String _parseRootArg(List<String> args) {
  final idx = args.indexOf('--root');
  if (idx == -1) return 'lib';
  if (idx + 1 >= args.length) {
    stderr.writeln('error: --root requires a value');
    exit(64);
  }
  return args[idx + 1];
}

Future<List<RawTokenValue>> extractRawValuesFromFile(String filePath) async {
  final content = await File(filePath).readAsString();
  final out = <RawTokenValue>[];
  final lines = content.split('\n');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final site = '$filePath:${i + 1}';
    for (final m in _colorHex.allMatches(line)) {
      out.add(RawTokenValue(
        kind: 'color',
        rawValue: '#${m.group(1)!.toUpperCase()}',
        site: site,
      ));
    }
    for (final m in _edgeInsetsAll.allMatches(line)) {
      out.add(RawTokenValue(
        kind: 'spacing',
        rawValue: m.group(1)!,
        site: site,
      ));
    }
    for (final m in _edgeInsetsSymHoriz.allMatches(line)) {
      out.add(RawTokenValue(kind: 'spacing', rawValue: m.group(1)!, site: site));
    }
    for (final m in _edgeInsetsSymVert.allMatches(line)) {
      out.add(RawTokenValue(kind: 'spacing', rawValue: m.group(1)!, site: site));
    }
    for (final m in _sizedBox.allMatches(line)) {
      out.add(RawTokenValue(kind: 'spacing', rawValue: m.group(1)!, site: site));
    }
    for (final m in _borderRadius.allMatches(line)) {
      out.add(RawTokenValue(kind: 'radius', rawValue: m.group(1)!, site: site));
    }
  }
  // TextStyle은 multi-line — 전체 content에서 한 번에 추출.
  for (final m in _textStyle.allMatches(content)) {
    final body = m.group(1)!;
    final fontFamily = RegExp(r"fontFamily:\s*'([^']+)'").firstMatch(body)?.group(1);
    final fontSize = _parseNum(
        RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)').firstMatch(body)?.group(1));
    final fontWeightMatch =
        RegExp(r'fontWeight:\s*FontWeight\.w(\d+)').firstMatch(body);
    final fontWeight =
        fontWeightMatch != null ? int.parse(fontWeightMatch.group(1)!) : null;
    final lineHeight = _parseNum(
        RegExp(r'height:\s*(\d+(?:\.\d+)?)').firstMatch(body)?.group(1));
    out.add(RawTokenValue(
      kind: 'typography',
      rawValue: 'TextStyle',
      site: '$filePath:?',
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      lineHeight: lineHeight,
    ));
  }
  return out;
}

// ΔE — RGB 유클리드 거리(단순 근사). 정확한 ΔE2000은 과잉.
double _colorDistance(String hexA, String hexB) {
  int p(String h, int i) => int.parse(h.substring(i, i + 2), radix: 16);
  // 8자리 ARGB 형식: #AARRGGBB — RGB 부분(3~8번째 문자)만 사용.
  final aR = p(hexA, 3), aG = p(hexA, 5), aB = p(hexA, 7);
  final bR = p(hexB, 3), bG = p(hexB, 5), bB = p(hexB, 7);
  return math.sqrt(
    math.pow(aR - bR, 2) + math.pow(aG - bG, 2) + math.pow(aB - bB, 2),
  );
}

List<ClusteredToken> clusterColors(List<RawTokenValue> raws) {
  const threshold = 8.0; // 대략 ΔE76 < 8 ≒ ΔE00 < 3
  final groups = <List<RawTokenValue>>[];
  for (final r in raws.where((r) => r.kind == 'color')) {
    List<RawTokenValue>? existing;
    for (final g in groups) {
      if (_colorDistance(g.first.rawValue, r.rawValue) < threshold) {
        existing = g;
        break;
      }
    }
    if (existing == null) {
      groups.add([r]);
    } else {
      existing.add(r);
    }
  }
  int idx = 0;
  return groups.map((g) {
    final name = 'color/auto/${idx++}'; // designer agent가 이름 재정의 가능
    return ClusteredToken(
      name: name,
      kind: 'color',
      value: g.first.rawValue,
      sources: g.map((m) => m.site).toList(),
      clusterMembers: g,
    );
  }).toList();
}

List<ClusteredToken> clusterSpacings(List<RawTokenValue> raws) {
  // 4px 단위 step으로 정규화. 같은 step에 묶이면 ±2px 이내 값이 함께 묶인다.
  final groups = <int, List<RawTokenValue>>{};
  for (final r in raws.where((r) => r.kind == 'spacing')) {
    final v = double.parse(r.rawValue);
    final step = (v / 4).round();
    groups.putIfAbsent(step, () => []).add(r);
  }
  return groups.entries.map((e) {
    return ClusteredToken(
      name: 'spacing/${e.key}',
      kind: 'spacing',
      value: e.key * 4,
      sources: e.value.map((m) => m.site).toList(),
      clusterMembers: e.value,
    );
  }).toList()
    ..sort((a, b) => (a.value as int).compareTo(b.value as int));
}

List<ClusteredToken> clusterRadii(List<RawTokenValue> raws) {
  final groups = <int, List<RawTokenValue>>{};
  for (final r in raws.where((r) => r.kind == 'radius')) {
    final v = double.parse(r.rawValue).round();
    final bucket = (v <= 8) ? 8 : (v <= 12 ? 12 : 16);
    groups.putIfAbsent(bucket, () => []).add(r);
  }
  return groups.entries.map((e) {
    final tag = e.key == 8 ? 'sm' : (e.key == 12 ? 'md' : 'lg');
    return ClusteredToken(
      name: 'radius/$tag',
      kind: 'radius',
      value: e.key,
      sources: e.value.map((m) => m.site).toList(),
      clusterMembers: e.value,
    );
  }).toList();
}

List<ClusteredToken> clusterTypography(List<RawTokenValue> raws) {
  final groups = <String, List<RawTokenValue>>{};
  for (final r in raws.where((r) => r.kind == 'typography')) {
    final key = '${r.fontFamily ?? ''}|${r.fontSize ?? 0}|${r.fontWeight ?? 0}';
    groups.putIfAbsent(key, () => []).add(r);
  }
  int idx = 0;
  return groups.entries.map((e) {
    final first = e.value.first;
    return ClusteredToken(
      name: 'typography/auto/${idx++}',
      kind: 'typography',
      value: null,
      fontFamily: first.fontFamily,
      fontSize: first.fontSize,
      fontWeight: first.fontWeight,
      lineHeight: first.lineHeight,
      sources: e.value.map((m) => m.site).toList(),
      clusterMembers: e.value,
    );
  }).toList();
}

Future<void> main(List<String> args) async {
  final root = _parseRootArg(args);
  final all = <RawTokenValue>[];
  await for (final ent in Directory(root).list(recursive: true, followLinks: false)) {
    if (ent is! File || !ent.path.endsWith('.dart')) continue;
    if (ent.path.contains('.g.dart') || ent.path.contains('.freezed.dart')) continue;
    all.addAll(await extractRawValuesFromFile(ent.path));
  }
  final result = TokenScanResult(
    generatedAt: DateTime.now(),
    tokens: {
      'color': clusterColors(all),
      'typography': clusterTypography(all),
      'spacing': clusterSpacings(all),
      'radius': clusterRadii(all),
    },
  );
  stdout.writeln(result.toJsonString());
}
