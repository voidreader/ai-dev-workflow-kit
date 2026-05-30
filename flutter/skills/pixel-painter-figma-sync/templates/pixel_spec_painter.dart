import 'package:flutter/widgets.dart';
import 'pixel_specs.dart';

/// 스펙 [ops]를 [canvas]에 그린다. 색키 → Color는 [resolve]가 주입한다.
/// strokeWeight와 cornerRadius는 size.width 기준으로 복원된다(원본 painter 규약).
void paintPixelSpec(
    Canvas canvas, Size size, List<PixelOp> ops, Color Function(String key) resolve) {
  final w = size.width, h = size.height;

  // fill 페인트 생성 — 채우기 스타일
  Paint fillPaint(String key, double a) => Paint()
    ..style = PaintingStyle.fill
    ..color = resolve(key).withValues(alpha: a);

  // stroke 페인트 생성 — strokeWeight는 width 기준으로 복원
  Paint strokePaint(String key, double a, double weight) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = weight * w
    ..color = resolve(key).withValues(alpha: a);

  for (final op in ops) {
    switch (op.kind) {
      case PixelOpKind.rect:
        final rect = Rect.fromLTWH(op.x * w, op.y * h, op.w * w, op.h * h);
        final useRRect = op.cornerRadius > 0;
        // cornerRadius도 width 기준으로 복원
        final rr = useRRect
            ? RRect.fromRectAndRadius(rect, Radius.circular(op.cornerRadius * w))
            : null;
        if (op.fillKey != null) {
          final p = fillPaint(op.fillKey!, op.fillAlpha);
          useRRect ? canvas.drawRRect(rr!, p) : canvas.drawRect(rect, p);
        }
        if (op.strokeKey != null) {
          final p = strokePaint(op.strokeKey!, op.strokeAlpha, op.strokeWeight);
          useRRect ? canvas.drawRRect(rr!, p) : canvas.drawRect(rect, p);
        }
      case PixelOpKind.oval:
        final rect = Rect.fromLTWH(op.x * w, op.y * h, op.w * w, op.h * h);
        if (op.fillKey != null) canvas.drawOval(rect, fillPaint(op.fillKey!, op.fillAlpha));
        if (op.strokeKey != null) {
          canvas.drawOval(rect, strokePaint(op.strokeKey!, op.strokeAlpha, op.strokeWeight));
        }
      case PixelOpKind.line:
        // x,y=시작점, x2,y2=끝점. oval/path와 동일하게 strokeKey 가드.
        if (op.strokeKey != null) {
          canvas.drawLine(
            Offset(op.x * w, op.y * h),
            Offset(op.x2 * w, op.y2 * h),
            strokePaint(op.strokeKey!, op.strokeAlpha, op.strokeWeight),
          );
        }
      case PixelOpKind.path:
        // points는 [x0,y0,x1,y1,...] 형태 (짝수 개수 보장은 PixelOp.path assert가 담당)
        final path = Path();
        for (var i = 0; i < op.points.length; i += 2) {
          final px = op.points[i] * w, py = op.points[i + 1] * h;
          i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
        }
        if (op.closed) path.close();
        if (op.fillKey != null) canvas.drawPath(path, fillPaint(op.fillKey!, op.fillAlpha));
        if (op.strokeKey != null) {
          canvas.drawPath(path, strokePaint(op.strokeKey!, op.strokeAlpha, op.strokeWeight));
        }
    }
  }
}
