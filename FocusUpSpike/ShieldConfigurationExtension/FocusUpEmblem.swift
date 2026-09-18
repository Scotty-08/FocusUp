import UIKit

/// Fixed-size original artwork; the OS still controls shield layout.
enum FocusUpEmblem {
    static let image: UIImage = {
        let size = CGSize(width: 88, height: 88)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cyan = UIColor(red: 62/255, green: 230/255, blue: 1, alpha: 1)
            let frame = UIBezierPath()
            frame.move(to: CGPoint(x: 16, y: 3))
            for point in [CGPoint(x:85,y:3), CGPoint(x:85,y:72), CGPoint(x:72,y:85), CGPoint(x:3,y:85), CGPoint(x:3,y:16)] { frame.addLine(to: point) }
            frame.close()
            UIColor(red: 7/255, green: 22/255, blue: 29/255, alpha: 1).setFill()
            frame.fill()
            cyan.withAlphaComponent(0.6).setStroke()
            frame.lineWidth = 1.5
            frame.stroke()
            context.cgContext.setShadow(offset: .zero, blur: 7, color: cyan.withAlphaComponent(0.35).cgColor)
            ("F↑" as NSString).draw(at: CGPoint(x: 19, y: 23), withAttributes: [
                .font: UIFont.systemFont(ofSize: 35, weight: .heavy),
                .foregroundColor: cyan, .kern: -3
            ])
        }.withRenderingMode(.alwaysOriginal)
    }()
}
