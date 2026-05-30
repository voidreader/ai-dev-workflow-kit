// `dart run tool/flutter_figma_bridge/scan_pixel_specs.dart` 로 실행.
// lib/ 의 pixel_specs.dart를 import해 스펙 함수를 실행하고
// 정규화 ops + 색키를 JSON으로 stdout 출력한다.
//
// ── 이 파일은 재사용 골격(template)이다 ──
// _opJson/_comp/_variant/_variantComp 헬퍼는 그대로 쓴다.
// main()의 컴포넌트 등록부만 프로젝트의 spec 함수에 맞게 채운다.
//
// TODO(프로젝트): 아래 import 경로를 실제 패키지명으로 바꾼다.
//   import 'package:<your_package>/shared/presentation/pixel_specs.dart';
//   (variant 축으로 enum을 쓰면 그 enum 파일도 import)
import 'pixel_spec_models.dart';
import 'pixel_specs.dart';

/// PixelOp 하나를 직렬화 가능한 Map으로 변환한다.
Map<String, dynamic> _opJson(PixelOp o) => {
      'kind': o.kind.name,
      if (o.kind != PixelOpKind.path) ...{'x': o.x, 'y': o.y},
      if (o.kind == PixelOpKind.rect || o.kind == PixelOpKind.oval) ...{'w': o.w, 'h': o.h},
      if (o.kind == PixelOpKind.line) ...{'x2': o.x2, 'y2': o.y2},
      if (o.kind == PixelOpKind.path) 'points': o.points,
      if (o.fillKey != null) 'fillKey': o.fillKey,
      if (o.strokeKey != null) 'strokeKey': o.strokeKey,
      if (o.fillAlpha != 1.0) 'fillAlpha': o.fillAlpha,
      if (o.strokeAlpha != 1.0) 'strokeAlpha': o.strokeAlpha,
      if (o.strokeWeight != 0.0) 'strokeWeight': o.strokeWeight,
      if (o.cornerRadius != 0.0) 'cornerRadius': o.cornerRadius,
      if (!o.closed) 'closed': false,
    };

/// variant 없는 단일 컴포넌트 맵. viewBoxHeight는 가로 대비 세로 비율(1.0 = 정사각형).
Map<String, dynamic> _comp(String name, double vbH, List<PixelOp> ops) => {
      'name': name,
      'viewBoxHeight': vbH,
      'ops': ops.map(_opJson).toList(),
    };

/// variant 한 개(value + ops).
// ignore: unused_element
Map<String, dynamic> _variant(String value, List<PixelOp> ops) => {
      'value': value,
      'ops': ops.map(_opJson).toList(),
    };

/// variant set 컴포넌트 맵. naming-rules의 variant 묶음 규칙을 따른다.
// ignore: unused_element
Map<String, dynamic> _variantComp(
        String name, double vbH, String axis, List<Map<String, dynamic>> variants) =>
    {
      'name': name,
      'viewBoxHeight': vbH,
      'variantAxis': axis,
      'variants': variants,
    };

void main() {
  // TODO(프로젝트): 프로젝트의 spec 함수를 Figma 컴포넌트로 등록한다.
  //   - 단일 아이콘    → _comp('Pixel/Foo', <세로비율>, fooSpec())
  //   - variant 집합   → _variantComp('Pixel/Bar', <세로비율>, '<축이름>', [
  //                         for (final v in BarKind.values) _variant(v.name, barSpec(v)),
  //                       ])
  // 아래는 골격의 예시(coinSpec 하나만 단일 컴포넌트로 등록).
  final comps = <Map<String, dynamic>>[
    _comp('Pixel/CoinIcon', 1.0, coinSpec()),
  ];

  // ignore: avoid_print
  print(PixelSpecResult(comps).toJsonString());
}
