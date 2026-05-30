// `dart run tool/flutter_figma_bridge/scan_widgets.dart [--root lib]` 로 실행.
// lib/ 트리에서 public Widget 서브클래스를 enumerate하고 JSON으로 stdout 출력.
//
// 한계: 정규식 기반이라 매크로·복잡한 generic 상속은 놓칠 수 있다.
// 목표 정확도 95% — 누락은 designer agent가 게이트에서 사용자와 조정.

import 'dart:io';
import 'models.dart';

final _classDecl = RegExp(
  r'class\s+(\w+)\s*(?:<[^>]*>)?\s+extends\s+(StatelessWidget|StatefulWidget|HookWidget|ConsumerWidget|ConsumerStatefulWidget)\b',
);

final _paramSplit = RegExp(r',\s*');

class _RawWidget {
  _RawWidget(this.name, this.baseClass, this.params);
  final String name;
  final String baseClass;
  final List<ConstructorParam> params;
}

List<String> domainOf(String path) {
  final norm = path.replaceAll('\\', '/');
  final featureMatch = RegExp(r'lib/features/([^/]+)/').firstMatch(norm);
  if (featureMatch != null) return [featureMatch.group(1)!];
  if (norm.startsWith('lib/shared/')) return ['shared'];
  if (norm.startsWith('lib/app/')) return ['app'];
  if (norm.startsWith('lib/core/')) return ['core'];
  if (norm.startsWith('lib/data/')) return ['data'];
  return ['unknown'];
}

Future<List<WidgetInfo>> scanWidgetsInFile(String filePath) async {
  final content = await File(filePath).readAsString();
  final raws = <_RawWidget>[];
  for (final m in _classDecl.allMatches(content)) {
    final name = m.group(1)!;
    if (name.startsWith('_')) continue; // private 제외
    final baseClass = m.group(2)!;
    final params = _extractCtor(content, name);
    raws.add(_RawWidget(name, baseClass, params));
  }
  return raws
      .map((r) => WidgetInfo(
            className: r.name,
            file: filePath,
            domains: domainOf(filePath),
            usageCount: 0, // Task 3에서는 미사용. Task 4의 main에서 채움.
            usageSites: const [],
            constructorParams: r.params,
            isStateless: !r.baseClass.contains('Stateful') &&
                !r.baseClass.contains('ConsumerStateful'),
          ))
      .toList();
}

List<ConstructorParam> _extractCtor(String src, String className) {
  // class <name>의 첫 생성자만 잡는다.
  final ctor = RegExp(
    r'(?:const\s+)?' + RegExp.escape(className) + r'\s*\(\s*\{([^}]*)\}\s*\)',
  ).firstMatch(src);
  if (ctor == null) return const [];
  final body = ctor.group(1)!;
  final result = <ConstructorParam>[];
  for (final raw in body.split(_paramSplit)) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) continue;
    final isRequired = trimmed.startsWith('required ');
    final cleaned = trimmed
        .replaceFirst(RegExp(r'^required\s+'), '')
        .replaceFirst(RegExp(r'^this\.'), '');
    if (cleaned == 'key' ||
        cleaned == 'super.key' ||
        cleaned.startsWith('super.')) {
      continue;
    }
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length < 2) {
      // `this.label` 처럼 타입 없는 경우 — 타입을 클래스 본문에서 찾아야 하지만
      // 95% 정확도 목표라 'dynamic'으로 표시.
      result.add(ConstructorParam(
        name: parts[0],
        type: 'dynamic',
        required: isRequired,
      ));
    } else {
      result.add(ConstructorParam(
        name: parts.last,
        type: parts.sublist(0, parts.length - 1).join(' '),
        required: isRequired,
      ));
    }
  }
  return result;
}

Future<int> countUsages(String className, Directory root) async {
  // grep 풍 — 'ClassName(' 또는 'const ClassName(' 등장 횟수.
  // 정의 자체는 제외하기 위해 'class ClassName' 라인과
  // 생성자 선언 라인 'ClassName(' 도 함께 제외한다.
  final pattern = RegExp(r'\b' + RegExp.escape(className) + r'\s*\(');
  final defPattern = RegExp(
      r'^\s*class\s+' + RegExp.escape(className) + r'\b');
  final ctorDeclPattern = RegExp(
      r'^\s*(?:const\s+)?' + RegExp.escape(className) + r'\s*\(');
  int count = 0;
  await for (final ent in root.list(recursive: true, followLinks: false)) {
    if (ent is! File || !ent.path.endsWith('.dart')) continue;
    if (ent.path.contains('.g.dart') || ent.path.contains('.freezed.dart')) {
      continue;
    }
    final lines = await ent.readAsLines();
    for (final line in lines) {
      if (defPattern.hasMatch(line)) continue;
      if (ctorDeclPattern.hasMatch(line)) continue;
      count += pattern.allMatches(line).length;
    }
  }
  return count;
}

String _parseRootArg(List<String> args) {
  final idx = args.indexOf('--root');
  if (idx == -1) return 'lib';
  if (idx + 1 >= args.length) {
    stderr.writeln('error: --root requires a value');
    exit(64);
  }
  return args[idx + 1];
}

Future<void> main(List<String> args) async {
  final root = _parseRootArg(args);
  final widgets = <WidgetInfo>[];
  final rootDir = Directory(root);
  await for (final ent
      in rootDir.list(recursive: true, followLinks: false)) {
    if (ent is! File || !ent.path.endsWith('.dart')) continue;
    if (ent.path.contains('.g.dart') || ent.path.contains('.freezed.dart')) {
      continue;
    }
    final found = await scanWidgetsInFile(ent.path);
    widgets.addAll(found);
  }
  // 사용 횟수 채우기
  final filled = <WidgetInfo>[];
  for (final w in widgets) {
    final count = await countUsages(w.className, rootDir);
    filled.add(WidgetInfo(
      className: w.className,
      file: w.file,
      domains: w.domains,
      usageCount: count,
      usageSites: w.usageSites,
      constructorParams: w.constructorParams,
      isStateless: w.isStateless,
    ));
  }
  final result = WidgetScanResult(
    generatedAt: DateTime.now(),
    scanRoot: root,
    widgets: filled,
  );
  stdout.writeln(result.toJsonString());
}
