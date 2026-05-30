// 픽셀 아트의 단일 진실 원천(SSOT). dart:ui/material 미사용 — 순수 데이터.
// Flutter painter(pixel_spec_painter.dart)와 빌드타임 도구(scan_pixel_specs.dart)가
// 동일하게 소비한다. 좌표/크기/weight는 모두 0~1 정규화.
//
// ── 이 파일은 재사용 골격(template)이다 ──
// PixelOp 자료형과 팩토리는 그대로 가져다 쓰고, spec 함수는 프로젝트의 픽셀아트에
// 맞게 새로 작성한다. 아래 coinSpec()은 색키만 쓰는 도메인 비종속 예시로 남겨둔다.
// 실제 사례(음식 태그 10종·통화·자판기 등)는 SKILL.md의 examples 절을 참고.

enum PixelOpKind { rect, oval, line, path }

class PixelOp {
  const PixelOp({
    required this.kind,
    this.x = 0, this.y = 0, this.w = 0, this.h = 0,
    this.x2 = 0, this.y2 = 0,
    this.points = const [],
    this.fillKey,
    this.strokeKey,
    this.fillAlpha = 1.0,
    this.strokeAlpha = 1.0,
    this.strokeWeight = 0.0,
    this.cornerRadius = 0.0,
    this.closed = true,
  });

  final PixelOpKind kind;
  final double x, y, w, h;       // rect/oval: 좌상단+크기 (정규화)
  final double x2, y2;           // line: 끝점 (정규화)
  final List<double> points;     // path: [x0,y0,x1,y1,...] (정규화)
  final String? fillKey;
  final String? strokeKey;
  final double fillAlpha;
  final double strokeAlpha;
  final double strokeWeight;     // 정규화 (size 곱해서 사용)
  final double cornerRadius;     // 정규화 (RRect용)
  final bool closed;

  factory PixelOp.rect(double x, double y, double w, double h, String fillKey,
          {double alpha = 1.0, double cornerRadius = 0.0}) =>
      PixelOp(kind: PixelOpKind.rect, x: x, y: y, w: w, h: h,
          fillKey: fillKey, fillAlpha: alpha, cornerRadius: cornerRadius);

  factory PixelOp.strokeRect(double x, double y, double w, double h, String strokeKey,
          double strokeWeight, {double alpha = 1.0, double cornerRadius = 0.0}) =>
      PixelOp(kind: PixelOpKind.rect, x: x, y: y, w: w, h: h,
          strokeKey: strokeKey, strokeAlpha: alpha,
          strokeWeight: strokeWeight, cornerRadius: cornerRadius);

  factory PixelOp.oval(double x, double y, double w, double h,
          {String? fillKey, String? strokeKey,
          double fillAlpha = 1.0, double strokeAlpha = 1.0, double strokeWeight = 0.0}) =>
      PixelOp(kind: PixelOpKind.oval, x: x, y: y, w: w, h: h,
          fillKey: fillKey, strokeKey: strokeKey,
          fillAlpha: fillAlpha, strokeAlpha: strokeAlpha, strokeWeight: strokeWeight);

  factory PixelOp.line(double x1, double y1, double x2, double y2,
          String strokeKey, double strokeWeight, {double alpha = 1.0}) =>
      PixelOp(kind: PixelOpKind.line, x: x1, y: y1, x2: x2, y2: y2,
          strokeKey: strokeKey, strokeAlpha: alpha, strokeWeight: strokeWeight);

  factory PixelOp.path(List<double> points,
          {String? fillKey, String? strokeKey,
          double fillAlpha = 1.0, double strokeAlpha = 1.0,
          double strokeWeight = 0.0, bool closed = true}) {
    // points는 (x,y) 쌍이어야 하므로 짝수 개수를 강제한다.
    assert(points.length % 2 == 0, 'points는 (x,y) 쌍이어야 한다');
    return PixelOp(kind: PixelOpKind.path, points: points,
        fillKey: fillKey, strokeKey: strokeKey,
        fillAlpha: fillAlpha, strokeAlpha: strokeAlpha,
        strokeWeight: strokeWeight, closed: closed);
  }
}

// 색키 규약:
//   - 'tint' = 위젯이 런타임에 전달하는 동적 색(예: 태그색, 통화 primary색, 외곽색).
//     소비자(painter)가 resolve 함수에서 실제 색을 주입한다.
//   - 그 외 키('inkPrimary', 'white', ...)는 painter와 무관한 고정 토큰색.
//     프로젝트의 DesignTokens 등 고정 팔레트로 매핑한다.

// ── 예시 spec(도메인 비종속) ──
// 동전 아이콘: oval fill+stroke → 하이라이트 rect → 세로/가로선 3개.
// 정규화 좌표 위에 어떤 도형을 무슨 색키로 어떤 순서로 찍는지를 순수 데이터로만 기술한다.
List<PixelOp> coinSpec() => [
  PixelOp.oval(0, 0, 1, 1, fillKey: 'tint', strokeKey: 'inkPrimary', strokeWeight: 1 / 9),
  PixelOp.rect(0.28, 0.18, 0.20, 0.14, 'white', alpha: 0.44),
  PixelOp.line(0.50, 0.26, 0.50, 0.74, 'inkPrimary', 1 / 12),
  PixelOp.line(0.36, 0.38, 0.64, 0.38, 'inkPrimary', 1 / 12),
  PixelOp.line(0.36, 0.62, 0.64, 0.62, 'inkPrimary', 1 / 12),
];

// TODO(프로젝트): 여기에 프로젝트의 픽셀아트 spec 함수를 추가한다.
//   - 단일 아이콘  → List<PixelOp> fooSpec()
//   - variant 집합 → enum 값별 분기하는 List<PixelOp> barSpec(BarKind kind)
// 작성 팁: 원본 CustomPainter의 drawRect/drawOval/drawLine/drawPath 호출을
// 1:1로 PixelOp 팩토리에 옮기고, 좌표·크기·strokeWeight를 그릴 때의 기준 크기로
// 나눠 0~1로 정규화한다. 주석에 "원본 painter의 어느 줄을 어떻게 옮겼는지"를
// 남겨두면 골든 테스트로 1:1 대조하기 쉽다.
