import AppKit

let size: CGFloat = 2048
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }
ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

// Stylized wutong (parasol tree) leaf, y-up. 3 lobes with real notches.
let leaf = CGMutablePath()
leaf.move(to: CGPoint(x: 1024, y: 1700))  // center tip
leaf.addCurve(
    to: CGPoint(x: 1120, y: 1440),
    control1: CGPoint(x: 1080, y: 1610), control2: CGPoint(x: 1108, y: 1520))
leaf.addCurve(
    to: CGPoint(x: 1108, y: 1240),
    control1: CGPoint(x: 1130, y: 1370), control2: CGPoint(x: 1116, y: 1300))
// notch -> side-lobe tip pointing up-out (maple gesture)
leaf.addCurve(
    to: CGPoint(x: 1450, y: 1370),
    control1: CGPoint(x: 1170, y: 1220), control2: CGPoint(x: 1340, y: 1400))
leaf.addCurve(
    to: CGPoint(x: 1330, y: 1000),
    control1: CGPoint(x: 1500, y: 1290), control2: CGPoint(x: 1390, y: 1120))
leaf.addCurve(
    to: CGPoint(x: 1150, y: 800),
    control1: CGPoint(x: 1290, y: 910), control2: CGPoint(x: 1200, y: 850))
leaf.addCurve(
    to: CGPoint(x: 1024, y: 640),
    control1: CGPoint(x: 1096, y: 735), control2: CGPoint(x: 1050, y: 678))
// mirror left
leaf.addCurve(
    to: CGPoint(x: 898, y: 800),
    control1: CGPoint(x: 998, y: 678), control2: CGPoint(x: 952, y: 735))
leaf.addCurve(
    to: CGPoint(x: 718, y: 1000),
    control1: CGPoint(x: 848, y: 850), control2: CGPoint(x: 758, y: 910))
leaf.addCurve(
    to: CGPoint(x: 598, y: 1370),
    control1: CGPoint(x: 658, y: 1120), control2: CGPoint(x: 548, y: 1290))
leaf.addCurve(
    to: CGPoint(x: 940, y: 1240),
    control1: CGPoint(x: 708, y: 1400), control2: CGPoint(x: 878, y: 1220))
leaf.addCurve(
    to: CGPoint(x: 928, y: 1440),
    control1: CGPoint(x: 932, y: 1300), control2: CGPoint(x: 918, y: 1370))
leaf.addCurve(
    to: CGPoint(x: 1024, y: 1700),
    control1: CGPoint(x: 940, y: 1520), control2: CGPoint(x: 968, y: 1610))
leaf.closeSubpath()

let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
let topColor = CGColor(colorSpace: colorSpace, components: [0.36, 0.83, 0.50, 1])!
let bottomColor = CGColor(colorSpace: colorSpace, components: [0.08, 0.58, 0.33, 1])!
let gradient = CGGradient(colorsSpace: colorSpace, colors: [topColor, bottomColor] as CFArray, locations: [0, 1])!

ctx.saveGState()
ctx.addPath(leaf)
ctx.clip()
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 1024, y: 1700),
    end: CGPoint(x: 1024, y: 560),
    options: [])
ctx.restoreGState()

// Stem
let stem = CGMutablePath()
stem.move(to: CGPoint(x: 1024, y: 656))
stem.addQuadCurve(to: CGPoint(x: 1002, y: 350), control: CGPoint(x: 1022, y: 490))
ctx.addPath(stem)
ctx.setStrokeColor(CGColor(colorSpace: colorSpace, components: [0.07, 0.46, 0.26, 1])!)
ctx.setLineWidth(40)
ctx.setLineCap(.round)
ctx.strokePath()

// Veins
ctx.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1, 1, 1, 0.42])!)
ctx.setLineWidth(15)
ctx.setLineCap(.round)
let veins: [(CGPoint, CGPoint)] = [
    (CGPoint(x: 1024, y: 1580), CGPoint(x: 1024, y: 1160)),
    (CGPoint(x: 1350, y: 1290), CGPoint(x: 1170, y: 1000)),
    (CGPoint(x: 698, y: 1290), CGPoint(x: 878, y: 1000)),
]
for (target, control) in veins {
    let vein = CGMutablePath()
    vein.move(to: CGPoint(x: 1024, y: 716))
    vein.addQuadCurve(to: target, control: control)
    ctx.addPath(vein)
    ctx.strokePath()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else { exit(1) }
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/qingwu-leaf.png"
try! png.write(to: URL(fileURLWithPath: out))
print("written: \(out)")
