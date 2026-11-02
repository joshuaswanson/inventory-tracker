import SwiftUI

nonisolated struct ToothShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: point(0.5, 0.17))
        path.addCurve(to: point(0.21, 0.05), control1: point(0.41, 0.09), control2: point(0.31, 0.04))
        path.addCurve(to: point(0.07, 0.42), control1: point(0.06, 0.07), control2: point(0.02, 0.26))
        path.addCurve(to: point(0.2, 0.87), control1: point(0.12, 0.58), control2: point(0.16, 0.73))
        path.addCurve(to: point(0.35, 0.87), control1: point(0.23, 0.97), control2: point(0.32, 0.98))
        path.addCurve(to: point(0.5, 0.58), control1: point(0.38, 0.74), control2: point(0.41, 0.58))
        path.addCurve(to: point(0.65, 0.87), control1: point(0.59, 0.58), control2: point(0.62, 0.74))
        path.addCurve(to: point(0.8, 0.87), control1: point(0.68, 0.98), control2: point(0.77, 0.97))
        path.addCurve(to: point(0.93, 0.42), control1: point(0.84, 0.73), control2: point(0.88, 0.58))
        path.addCurve(to: point(0.79, 0.05), control1: point(0.98, 0.26), control2: point(0.94, 0.07))
        path.addCurve(to: point(0.5, 0.17), control1: point(0.69, 0.04), control2: point(0.59, 0.09))
        path.closeSubpath()
        return path
    }
}
