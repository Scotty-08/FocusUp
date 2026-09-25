import UIKit

/// FocusUp's mark: the "Shutter" logo -- four shutter blades turning around
/// a dark lens inside a square frame. Source art and exports live in
/// design/logo/ (logos.py concept B, export.py); the same artwork is the app
/// icon and the browser extension icons.
///
/// Bundled next to this file as ShieldMark@2x.png / @3x.png (160pt, cropped
/// tight so the mark fills the whole image -- iOS sizes the shield icon
/// itself, so this just gives it the most logo per point). If the
/// image is ever missing, the previous ring-and-sparkle emblem is drawn in
/// code so the shield is never left without an icon.
enum FocusUpEmblem {
    static let image: UIImage = {
        if let mark = UIImage(named: "ShieldMark") {
            return mark.withRenderingMode(.alwaysOriginal)
        }
        return fallback
    }()

    private static let fallback: UIImage = {
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
