import SwiftUI

/// The TeleDrive box-and-plane glyph from `assets/icon/launch_mark.svg`, drawn
/// without a container as the HIG asks of logo marks in Live Activities.
struct TeleDriveMark: View {
  var body: some View {
    ZStack {
      SVGPathShape(data: Self.lid + " " + Self.plane)
      SVGPathShape(data: Self.box).fill(style: FillStyle(eoFill: true))
    }
    .aspectRatio(1, contentMode: .fit)
  }

  private static let lid =
    "M 15 30 L 43 14 C 47 12 50 12 54 14 L 72 24 L 60 31 L 49 25 L 25 39 L 43 49 L 33 55 L 15 45 C 11 43 10 40 10 37 C 10 34 12 32 15 30 Z"
  private static let plane =
    "M 45 41 L 88 28 C 91 27 93 29 91 32 L 75 64 C 74 67 72 67 70 65 L 60 53 L 77 37 L 54 49 L 45 45 C 42 44 42 42 45 41 Z"
  private static let box =
    "M 10 51 L 43 70 C 47 72 50 72 54 70 L 84 53 L 91 58 L 91 72 C 91 75 89 78 86 80 L 54 98 C 50 100 46 100 42 98 L 15 82 C 12 80 10 77 10 73 Z M 22 69 L 22 74 L 46 88 C 48 89 50 89 52 88 L 79 73 L 79 68 L 54 82 C 50 84 46 84 42 82 Z"
}

/// Minimal absolute M/L/C/Z path reader over a 100×100 view box.
private struct SVGPathShape: Shape {
  let data: String

  func path(in rect: CGRect) -> Path {
    let scale = min(rect.width, rect.height) / 100
    let tokens = data.split(separator: " ")
    var path = Path()
    var index = 0
    func point() -> CGPoint {
      let x = Double(tokens[index]) ?? 0
      let y = Double(tokens[index + 1]) ?? 0
      index += 2
      return CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
    }
    while index < tokens.count {
      let command = tokens[index]
      index += 1
      switch command {
      case "M": path.move(to: point())
      case "L": path.addLine(to: point())
      case "C":
        let c1 = point(), c2 = point(), end = point()
        path.addCurve(to: end, control1: c1, control2: c2)
      case "Z": path.closeSubpath()
      default: return path
      }
    }
    return path
  }
}
