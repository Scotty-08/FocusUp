import UIKit

/// Redesigned per Scott's request: simple, elegant, with a "new-gen
/// AI" touch -- so this drops the boxed badge + letterform entirely in
/// favor of two shapes: a thin ring (focus / a target, quiet and
/// geometric) and a small solid 4-point sparkle at its center (the
/// spark/"thinking" glyph a lot of AI products use). No text glyph, no
/// filled tile -- it sits directly on the shield's own background.
enum FocusUpEmblem {
    static let image: UIImage = {
        let size = CGSize(width: 108, height: 108)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cyan = UIColor(red: 115/255, green: 191/255, blue: 202/255, alpha: 1)
            let center = CGPoint(x: 54, y: 54)
            let ctx = context.cgContext

            // Thin outer ring.
            let ring = UIBezierPath(arcCenter: center, radius: 40, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            ring.lineWidth = 2.5
            cyan.withAlphaComponent(0.85).setStroke()
            ring.stroke()

            // Small 4-point sparkle at the center -- long N/E/S/W points,
            // short concave notches between them.
            let outer: CGFloat = 22
            let inner: CGFloat = 6
            let points: [CGPoint] = [
                CGPoint(x: center.x, y: center.y - outer),       // N
                CGPoint(x: center.x + inner, y: center.y - inner), // concave
                CGPoint(x: center.x + outer, y: center.y),       // E
                CGPoint(x: center.x + inner, y: center.y + inner), // concave
                CGPoint(x: center.x, y: center.y + outer),       // S
                CGPoint(x: center.x - inner, y: center.y + inner), // concave
                CGPoint(x: center.x - outer, y: center.y),       // W
                CGPoint(x: center.x - inner, y: center.y - inner), // concave
            ]
            let sparkle = UIBezierPath()
            sparkle.move(to: points[0])
            for p in points.dropFirst() { sparkle.addLine(to: p) }
            sparkle.close()

            ctx.setShadow(offset: .zero, blur: 9, color: cyan.withAlphaComponent(0.55).cgColor)
            cyan.setFill()
            sparkle.fill()
        }.withRenderingMode(.alwaysOriginal)
    }()
}

