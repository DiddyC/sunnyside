import AppKit
import CoreGraphics

// Usage: frame <in.png> <out.png> <W> <H> "<headline>" "<subline>" <light|dark>
// Composes a raw simulator screenshot into an App Store screenshot: coloured
// canvas, headline + subline at the top, the screenshot scaled below with
// rounded corners and a soft shadow.
let a = CommandLine.arguments
guard a.count >= 8 else { print("usage: frame in out W H headline subline light|dark"); exit(1) }
let inPath = a[1], outPath = a[2], W = Double(a[3])!, H = Double(a[4])!, headline = a[5], subline = a[6], light = a[7] == "light"

guard let src = NSImage(contentsOfFile: inPath), let cg = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("bad input"); exit(1) }
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func rgb(_ r: Double, _ g: Double, _ b: Double, _ al: Double = 1) -> CGColor { CGColor(colorSpace: cs, components: [r/255, g/255, b/255, al])! }

// Background
let bgTop = light ? rgb(247, 245, 239) : rgb(11, 16, 32)
let bgBot = light ? rgb(236, 231, 219) : rgb(20, 27, 48)
let grad = CGGradient(colorsSpace: cs, colors: [bgTop, bgBot] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])
// Sun glow top-right
let glow = CGGradient(colorsSpace: cs, colors: [rgb(242, 169, 59, light ? 0.35 : 0.28), rgb(242, 169, 59, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: W * 0.92, y: H * 0.93), startRadius: 0, endCenter: CGPoint(x: W * 0.92, y: H * 0.93), endRadius: W * 0.55, options: [])

// Text (AppKit drawing in a flipped NSGraphicsContext)
let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.current = ns
let ink = light ? NSColor(red: 23/255, green: 26/255, blue: 34/255, alpha: 1) : NSColor(red: 236/255, green: 231/255, blue: 219/255, alpha: 1)
let sub = light ? NSColor(red: 85/255, green: 93/255, blue: 112/255, alpha: 1) : NSColor(red: 165/255, green: 176/255, blue: 200/255, alpha: 1)
let margin = W * 0.08
let para = NSMutableParagraphStyle(); para.alignment = .left; para.lineBreakMode = .byWordWrapping
let headFont = NSFont.systemFont(ofSize: W * 0.072, weight: .heavy)
let subFont = NSFont.systemFont(ofSize: W * 0.036, weight: .medium)
let headAttr: [NSAttributedString.Key: Any] = [.font: headFont, .foregroundColor: ink, .paragraphStyle: para, .kern: -1.5]
let subAttr: [NSAttributedString.Key: Any] = [.font: subFont, .foregroundColor: sub, .paragraphStyle: para]
let headRect = CGRect(x: margin, y: H - margin * 0.9 - W * 0.20, width: W - margin * 2, height: W * 0.20)
NSAttributedString(string: headline, attributes: headAttr).draw(with: headRect, options: [.usesLineFragmentOrigin])
let subRect = CGRect(x: margin, y: headRect.minY - W * 0.10, width: W - margin * 2, height: W * 0.09)
NSAttributedString(string: subline, attributes: subAttr).draw(with: subRect, options: [.usesLineFragmentOrigin])

// Screenshot: scale to width, pinned to the bottom, rounded, shadow
// Fit the screenshot below the text: its top stays under the subline, 8% of it hides below the bottom edge.
let aspect = Double(cg.height) / Double(cg.width)
let topLimit = subRect.minY - W * 0.03
let maxShotH = topLimit / 0.92
let shotW = min(W * 0.84, maxShotH / aspect)
let shotH = shotW * aspect
let shotRect = CGRect(x: (W - shotW) / 2, y: -shotH * 0.08, width: shotW, height: shotH)
let radius = shotW * 0.11
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 70, color: rgb(0, 0, 0, light ? 0.25 : 0.55))
ctx.setFillColor(rgb(0, 0, 0))
ctx.addPath(CGPath(roundedRect: shotRect, cornerWidth: radius, cornerHeight: radius, transform: nil)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: shotRect, cornerWidth: radius, cornerHeight: radius, transform: nil)); ctx.clip()
ctx.draw(cg, in: shotRect)
ctx.restoreGState()
ctx.setStrokeColor(rgb(255, 255, 255, light ? 0.5 : 0.12)); ctx.setLineWidth(3)
ctx.addPath(CGPath(roundedRect: shotRect.insetBy(dx: 1.5, dy: 1.5), cornerWidth: radius, cornerHeight: radius, transform: nil)); ctx.strokePath()

let out = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: out)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) \(Int(W))x\(Int(H))")
