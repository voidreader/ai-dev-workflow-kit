// scan_pixel_specs 출력 모델. dart:convert만 사용.
import 'dart:convert';

class PixelSpecResult {
  PixelSpecResult(this.components);
  // 컴포넌트별 직렬화 맵
  final List<Map<String, dynamic>> components;

  // version 2: 컴포넌트가 variant set 구조(variantAxis/variants)를 가질 수 있음.
  Map<String, dynamic> toJson() => {'version': 2, 'components': components};
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}
