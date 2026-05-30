// Flutter → Figma export 도구의 공용 데이터 모델.
// 의존성 없음(dart:core만 사용)으로 freezed/json_serializable codegen 회피.
// 두 scanner(scan_widgets, scan_tokens)가 공유한다.

import 'dart:convert';

class ConstructorParam {
  ConstructorParam({
    required this.name,
    required this.type,
    required this.required,
  });

  final String name;
  final String type;
  final bool required;

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'required': required,
      };
}

class WidgetInfo {
  WidgetInfo({
    required this.className,
    required this.file,
    required this.domains,
    required this.usageCount,
    required this.usageSites,
    required this.constructorParams,
    required this.isStateless,
  });

  final String className;
  final String file;
  final List<String> domains;
  final int usageCount;
  final List<String> usageSites;
  final List<ConstructorParam> constructorParams;
  final bool isStateless;

  Map<String, dynamic> toJson() => {
        'className': className,
        'file': file,
        'domains': domains,
        'usageCount': usageCount,
        'usageSites': usageSites,
        'constructorParams': constructorParams.map((e) => e.toJson()).toList(),
        'isStateless': isStateless,
      };
}

class WidgetScanResult {
  WidgetScanResult({
    required this.generatedAt,
    required this.scanRoot,
    required this.widgets,
  });

  final DateTime generatedAt;
  final String scanRoot;
  final List<WidgetInfo> widgets;

  Map<String, dynamic> toJson() {
    final sorted = [...widgets]
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return {
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'scanRoot': scanRoot,
      'widgets': sorted.map((e) => e.toJson()).toList(),
      'summary': {
        'totalUnique': widgets.length,
        'topUsed': sorted
            .take(10)
            .map((e) => {'className': e.className, 'usageCount': e.usageCount})
            .toList(),
      },
    };
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class RawTokenValue {
  RawTokenValue({
    required this.kind, // 'color' | 'spacing' | 'radius' | 'typography'
    required this.rawValue,
    required this.site, // file:line
    this.fontFamily,
    this.fontSize,
    this.fontWeight,
    this.lineHeight,
  });

  final String kind;
  final String rawValue;
  final String site;
  final String? fontFamily;
  final double? fontSize;
  final int? fontWeight;
  final double? lineHeight;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'rawValue': rawValue,
        'site': site,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (fontSize != null) 'fontSize': fontSize,
        if (fontWeight != null) 'fontWeight': fontWeight,
        if (lineHeight != null) 'lineHeight': lineHeight,
      };
}

class ClusteredToken {
  ClusteredToken({
    required this.name,
    required this.kind,
    required this.value,
    required this.sources,
    required this.clusterMembers,
    this.fontFamily,
    this.fontSize,
    this.fontWeight,
    this.lineHeight,
  });

  final String name;
  final String kind;
  final dynamic value; // hex string for color, num for spacing/radius, null for typography
  final List<String> sources;
  final List<RawTokenValue> clusterMembers;
  final String? fontFamily;
  final double? fontSize;
  final int? fontWeight;
  final double? lineHeight;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (value != null) 'value': value,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (fontSize != null) 'size': fontSize,
        if (fontWeight != null) 'weight': fontWeight,
        if (lineHeight != null) 'lineHeight': lineHeight,
        'sources': sources,
        'clusterMembers': clusterMembers.map((e) => e.toJson()).toList(),
      };
}

class TokenScanResult {
  TokenScanResult({
    required this.generatedAt,
    required this.tokens,
  });

  final DateTime generatedAt;
  final Map<String, List<ClusteredToken>> tokens; // 'color'/'typography'/'spacing'/'radius'

  Map<String, dynamic> toJson() => {
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'tokens': {
          for (final entry in tokens.entries)
            entry.key: entry.value.map((e) => e.toJson()).toList(),
        },
      };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}
