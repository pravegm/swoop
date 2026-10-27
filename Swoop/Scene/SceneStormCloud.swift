import CoreGraphics
import Foundation

/// The storm cloud's pixels (ROUND-6, settled point "the storm"): a new technique in place of the stacked vector lobes
/// that critics kept reading as "rows of river stones".
///
/// One soft cumulonimbus is rendered **once at load** from noise, then tinted per sky:
/// - **Silhouette:** a smooth envelope (a flat rain base, a front face leaning back, a flat anvil top with an
///   overhang), domain-warped by low-frequency noise and eroded by 4-octave fbm. So the outline billows at every
///   scale and nothing repeats in rows.
/// - **Volume:** a rounded bevel of the depth gives the normals, lit from the sun side (ahead and above). The sunlit
///   upper-right rims glow in the sky's storm-rim colour; the base is dark; a soft shading noise breaks up the body.
/// - **Rain:** a streaked curtain hangs from the base and feathers out over 140 pt (ART-FLIGHT-SCHOOL §7.3).
///
/// Pure functions, no UIKit / SpriteKit / actor isolation; `SceneTextures.stormCloud` turns the pixels into a texture.
/// Nominal coordinates: a `width × height` box, origin bottom-left, y up, the storm's front toward +x.
///
/// Why a texture and not an `SKShader`: there is no Metal compiler on the build host, and a shader that fails to
/// compile on a device draws nothing, silently. A texture made once gives the same fbm billows at the cost of one
/// sprite (the R5 wall was about 60 sprites and a shape).
enum SceneStormCloud {
    /// The nominal box (pt).
    static let width: CGFloat = 1300
    static let height: CGFloat = 720
    /// The shelf's visible front at the base (alpha ≥ 0.5 there): the scene maps the storm's edge onto this x.
    static let edgeX: CGFloat = 1110
    /// Nothing is drawn right of this x, so the cloud never reaches past edge + (drawnRight − edgeX) × scale.
    static let drawnRight: CGFloat = 1250
    /// Nothing is drawn above this y (no hard cut at the sprite's top).
    static let drawnTop: CGFloat = 712
    /// The cloud's flat base (nominal y); the rain curtain hangs below it.
    static let baseY: CGFloat = 170
    /// Texture pixels per nominal point (the cloud is drawn at about 0.33 × nominal, so this is ≥ 1 px per screen pt).
    static let pixelsPerPoint: CGFloat = 0.4
    /// R11 (ROUND-11 P0-1): the cloud's behind (left) edge fades from alpha 0 at x = 0 to full at this nominal x, so the
    /// sprite never ends in a straight column; `SceneStorm`'s backing (a stretched band with no detail) takes over
    /// behind it. Together with the empty top, front and base, no edge of the texture ever shows.
    static let leftFade: CGFloat = 360
    /// The backing ramps out under the cloud over this nominal width, from `leftFade` on (inside the solid body).
    static let backingRamp: CGFloat = 260
    /// Where the internal lightning glows sit (nominal), well inside the cloud.
    static let glowSpots: [CGPoint] = [CGPoint(x: 940, y: 400), CGPoint(x: 700, y: 330), CGPoint(x: 800, y: 540)]

    // The design (tuned against renders in Node before porting).
    private static let designFront: Float = 1180
    private static let towerTop: Float = 600
    private static let lean: Float = 330
    private static let anvilTop: Float = 670
    private static let anvilThick: Float = 100
    private static let overhang: Float = 230
    private static let warp: Float = 120
    private static let erosionScale: Float = 100
    private static let erosionAmp: Float = 115
    private static let bevel: Float = 80
    private static let innerBump: Float = 40
    private static let rimStrength: Float = 0.8

    /// The rendered field, kept so each sky's tint is a cheap pass.
    struct Field {
        let w: Int
        let h: Int
        /// Depth inside the silhouette (pt; ≤ 0 outside).
        var depth: [Float]
        /// The bevelled "height" the normals come from.
        var bump: [Float]
        /// Shading noise, −0.5 … 0.5 (0 outside).
        var tone: [Float]
        /// The rain curtain's alpha (0 above the base).
        var rain: [Float]
    }

    // MARK: Field

    static func makeField() -> Field {
        let w = max(Int((width * pixelsPerPoint).rounded()), 4)
        let h = max(Int((height * pixelsPerPoint).rounded()), 4)
        let px = Float(1 / pixelsPerPoint)
        let boxH = Float(height)
        let base = Float(baseY)
        let n = w * h
        var depth = [Float](repeating: 0, count: n)
        var bump = [Float](repeating: 0, count: n)
        var tone = [Float](repeating: 0, count: n)
        var rain = [Float](repeating: 0, count: n)
        let grid = noiseGrid()
        grid.withUnsafeBufferPointer { g in
            for j in 0..<h {
                let y = boxH - (Float(j) + 0.5) * px
                let below = 0.35 + 0.65 * smooth(base, base + 60, y)
                let topCut = 1 - smooth(boxH - 40, boxH - 8, y)
                for i in 0..<w {
                    let x = (Float(i) + 0.5) * px
                    let k = j * w + i
                    let e = envelope(g, x, y)
                    var d = e + erosionAmp * below * (fbm(g, x / erosionScale, y / erosionScale, 4) - 0.5)
                    d *= 1 - smooth(designFront + 20, designFront + 70, x)
                    d *= topCut
                    depth[k] = d
                    if d > -2 {
                        let q = 1 - min(max(d, 0) / bevel, 1)
                        bump[k] = bevel * max(1 - q * q, 0).squareRoot()
                            + innerBump * (1 - q) * (fbm(g, x / 140 + 3.3, y / 140 + 1.9, 2) - 0.5)
                        tone[k] = fbm(g, x / 55, y / 55, 3) - 0.5
                    }
                    if y < base + 40 {
                        let f = min(max((y - (base - 140)) / 140, 0), 1)
                        let shaft = (0.45 + 0.55 * smooth(0.3, 0.7, fbm(g, x / 150, 3.7, 3)))
                            * (1 - smooth(designFront - 200, designFront - 70, x))
                        let streak = 0.6 + 0.4 * noise(g, (x + (base - y) * 0.25) / 5, y / 90)
                        rain[k] = 0.35 * f * f.squareRoot() * shaft * streak
                    }
                }
            }
        }
        return Field(w: w, h: h, depth: depth, bump: bump, tone: tone, rain: rain)
    }

    /// The cloud's own alpha at a depth and height (nominal y): soft at the base and the front, crisper on the anvil.
    static func cloudAlpha(depth d: Float, y: Float) -> Float {
        let soft = 30 - 14 * smooth(560, 660, y)
        return smooth(0, soft, d)
    }

    /// The behind-edge fade at nominal x: 0 at the box's left edge, 1 from `leftFade` on (R11).
    static func leftFadeK(x: Float) -> Float {
        smooth(0, Float(leftFade), x)
    }

    /// The final alpha (cloud over rain, with the behind-edge fade) of pixel (i, j), row 0 at the top.
    static func alpha(_ f: Field, i: Int, j: Int) -> Float {
        guard i >= 0, i < f.w, j >= 0, j < f.h else { return 0 }
        let k = j * f.w + i
        let y = Float(height) - (Float(j) + 0.5) * Float(1 / pixelsPerPoint)
        let x = (Float(i) + 0.5) * Float(1 / pixelsPerPoint)
        let a = cloudAlpha(depth: f.depth[k], y: y)
        return (a + f.rain[k] * (1 - a)) * leftFadeK(x: x)
    }

    // MARK: Tint

    /// Premultiplied RGBA8 pixels, row 0 at the top. `body` / `top`: the sky's storm body and its darker base colour;
    /// `rim`: the sunlit edge; `rain`: the curtain.
    static func pixels(_ f: Field, body: RGBA, top: RGBA, rim: RGBA, rain: RGBA) -> [UInt8] {
        let w = f.w, h = f.h
        var out = [UInt8](repeating: 0, count: w * h * 4)
        let px = Float(1 / pixelsPerPoint)
        let boxH = Float(height)
        let base = Float(baseY)
        let dark = rgb(top, scale: 0.85)
        let mid = lift(rgb(body, scale: 1), 0.18)
        let rimC = rgb(rim, scale: 1)
        let litC = mixed(mid, rimC, 0.35)
        let rainC = rgb(rain, scale: 1)
        // The light: ahead, above and toward the viewer.
        let lx: Float = 0.55, ly: Float = 0.5, lz: Float = 0.67
        let ln = (lx * lx + ly * ly + lz * lz).squareRoot()
        let shift = max(Int((14 * Float(pixelsPerPoint)).rounded()), 1)
        let sx = Int((Float(shift) * 0.74).rounded()), sy = Int((Float(shift) * 0.67).rounded())
        func at(_ i: Int, _ j: Int) -> Float {
            let ii = min(max(i, 0), w - 1), jj = min(max(j, 0), h - 1)
            return f.bump[jj * w + ii]
        }
        for j in 0..<h {
            let y = boxH - (Float(j) + 0.5) * px
            let v = smooth(base, 690, y)
            for i in 0..<w {
                let k = j * w + i
                let fade = leftFadeK(x: (Float(i) + 0.5) * px)
                let d = f.depth[k]
                let a = cloudAlpha(depth: d, y: y)
                var c: (Float, Float, Float) = (0, 0, 0)
                if a > 0.001 {
                    let gx = (at(i + 1, j) - at(i - 1, j)) / (2 * px)
                    let gy = (at(i, j - 1) - at(i, j + 1)) / (2 * px)
                    let nn = (gx * gx + gy * gy + 1).squareRoot()
                    let diff = max(0, (-gx * lx - gy * ly + lz) / (nn * ln))
                    let occ = min(max((at(i + sx, j - sy) - f.bump[k]) / 50, 0), 1)
                    let light = diff * (1 - 0.5 * occ)
                    let depthK = min(max(d / 160, 0), 1)
                    let shade = min(max(0.05 + 0.6 * light + 0.4 * v - 0.15 * depthK * (1 - v) + 0.16 * f.tone[k], 0), 1)
                    c = mixed(dark, mid, shade)
                    c = mixed(c, litC, smooth(0.7, 1.0, shade))
                    let rr = light * light * light.squareRoot() * smooth(2, 12, d) * (1 - smooth(12, 46, d))
                        * (0.5 + 0.5 * v) * rimStrength
                    c = (min(1, c.0 + rimC.0 * rr), min(1, c.1 + rimC.1 * rr), min(1, c.2 + rimC.2 * rr))
                }
                let ra = f.rain[k] * (1 - a)
                let alpha = min(max(a + ra, 0), 1)
                // Premultiplied, so the behind-edge fade scales all four channels.
                out[k * 4] = byte((c.0 * a + rainC.0 * ra) * fade)
                out[k * 4 + 1] = byte((c.1 * a + rainC.1 * ra) * fade)
                out[k * 4 + 2] = byte((c.2 * a + rainC.2 * ra) * fade)
                out[k * 4 + 3] = byte(alpha * fade)
            }
        }
        return out
    }

    /// A lightning glow inside the cloud: white, premultiplied, the cloud's alpha × a soft disc (σ = `radius` / 2)
    /// around `spot`, at 1/`step` of the field's resolution. Drawn additively over the cloud with the same frame, so
    /// the glow never shows outside it.
    static func glowPixels(_ f: Field, spot: CGPoint, radius: CGFloat, step: Int) -> (w: Int, h: Int, bytes: [UInt8]) {
        let s = max(step, 1)
        let w = max(f.w / s, 1), h = max(f.h / s, 1)
        var out = [UInt8](repeating: 0, count: w * h * 4)
        let sigma = Float(max(radius, 1)) * 0.5
        let ppp = Float(pixelsPerPoint)
        for j in 0..<h {
            for i in 0..<w {
                let fi = i * s + s / 2, fj = j * s + s / 2
                let x = (Float(fi) + 0.5) / ppp
                let y = Float(height) - (Float(fj) + 0.5) / ppp
                let dx = x - Float(spot.x), dy = y - Float(spot.y)
                let g = exp(-(dx * dx + dy * dy) / (2 * sigma * sigma))
                let fk = min(fj, f.h - 1) * f.w + min(fi, f.w - 1)
                let a = cloudAlpha(depth: f.depth[fk], y: y) * g * leftFadeK(x: x)
                let b = byte(a)
                let k = (j * w + i) * 4
                out[k] = b
                out[k + 1] = b
                out[k + 2] = b
                out[k + 3] = b
            }
        }
        return (w, h, out)
    }

    // MARK: The backing (R11)

    /// The storm's backing, one premultiplied RGBA8 colour per row (row 0 at the top, `h` rows): the tinted cloud
    /// `px` (`w` × `h`) averaged across its body (nominal x from `leftFade` + 40 to `leftFade` + 300), then blurred
    /// down the rows (two box passes of ±10 rows, ≈ ±25 pt). It has no fine detail, so stretching it to any width (the
    /// storm running on off screen behind the cloud, at any catch sweep or recoil) can never streak or smear.
    static func backingProfile(_ px: [UInt8], w: Int, h: Int) -> [UInt8] {
        guard w > 1, h > 0, px.count >= w * h * 4 else { return [UInt8](repeating: 0, count: max(h, 0) * 4) }
        let ppp = Float(pixelsPerPoint)
        let i0 = min(max(Int((Float(leftFade) + 40) * ppp), 0), w - 1)
        let i1 = min(max(Int((Float(leftFade) + 300) * ppp), i0 + 1), w)
        let n = Float(i1 - i0)
        var rows = [Float](repeating: 0, count: h * 4)
        for j in 0..<h {
            for i in i0..<i1 {
                let k = (j * w + i) * 4
                for c in 0..<4 { rows[j * 4 + c] += Float(px[k + c]) }
            }
            for c in 0..<4 { rows[j * 4 + c] /= n }
        }
        // Rows outside the texture count as empty, so nothing is pulled up into its top or bottom.
        let r = 10
        let window = Float(2 * r + 1)
        for _ in 0..<2 {
            var next = rows
            for j in 0..<h {
                var sum: [Float] = [0, 0, 0, 0]
                for jj in max(j - r, 0)...min(j + r, h - 1) {
                    for c in 0..<4 { sum[c] += rows[jj * 4 + c] }
                }
                for c in 0..<4 { next[j * 4 + c] = sum[c] / window }
            }
            rows = next
        }
        // And a taper over the top 24 rows and the bottom 12, so the sprite's top and bottom rows are always empty.
        for j in 0..<h {
            let k = smooth(0, 24, Float(j)) * smooth(0, 12, Float(h - 1 - j))
            for c in 0..<4 { rows[j * 4 + c] *= k }
        }
        var out = [UInt8](repeating: 0, count: h * 4)
        for j in 0..<h {
            let a = min(max(rows[j * 4 + 3], 0), 255)
            out[j * 4 + 3] = UInt8(a + 0.5 > 255 ? 255 : a + 0.5)
            for c in 0..<3 {
                // Premultiplied: a colour channel never exceeds the alpha.
                let v = min(max(rows[j * 4 + c], 0), a)
                out[j * 4 + c] = UInt8(v + 0.5 > 255 ? 255 : v + 0.5)
            }
        }
        return out
    }

    // MARK: Noise

    /// A 256 × 256 grid of values in 0 ..< 1 (cosmetic `SceneRNG`, fixed seed: the same cloud every launch).
    static func noiseGrid() -> [Float] {
        var rng = SceneRNG(seed: 0x570A11)
        var g = [Float](repeating: 0, count: 256 * 256)
        for i in 0..<g.count { g[i] = Float(rng.unit()) }
        return g
    }

    /// Value noise with a quintic fade, wrapping every 256 cells.
    static func noise(_ g: UnsafeBufferPointer<Float>, _ x: Float, _ y: Float) -> Float {
        guard g.count >= 256 * 256, x.isFinite, y.isFinite, abs(x) < 1e6, abs(y) < 1e6 else { return 0.5 }
        let xf = x.rounded(.down), yf = y.rounded(.down)
        let fx = x - xf, fy = y - yf
        let ux = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
        let uy = fy * fy * fy * (fy * (fy * 6 - 15) + 10)
        let x0 = Int(xf) & 255, y0 = Int(yf) & 255
        let x1 = (x0 + 1) & 255, y1 = (y0 + 1) & 255
        let a = g[y0 * 256 + x0], b = g[y0 * 256 + x1], c = g[y1 * 256 + x0], d = g[y1 * 256 + x1]
        return a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy
    }

    /// fbm, each octave rotated by about 37° so nothing lines up on the grid ("bricks"). 0 … 1, mean ≈ 0.5.
    static func fbm(_ g: UnsafeBufferPointer<Float>, _ x: Float, _ y: Float, _ octaves: Int) -> Float {
        let rc: Float = 0.796_084, rs: Float = 0.605_186   // cos / sin 0.65
        var sum: Float = 0, amp: Float = 1, norm: Float = 0
        var px = x, py = y
        for o in 0..<max(octaves, 1) {
            sum += amp * noise(g, px + Float(o) * 17.3, py + Float(o) * 9.1)
            norm += amp
            amp *= 0.5
            let nx = (px * rc - py * rs) * 2.03
            let ny = (px * rs + py * rc) * 2.03
            px = nx
            py = ny
        }
        return sum / max(norm, 0.0001)
    }

    // MARK: The envelope

    /// A depth-like value (pt) inside the cumulonimbus silhouette, before erosion.
    private static func envelope(_ g: UnsafeBufferPointer<Float>, _ x0: Float, _ y0: Float) -> Float {
        let base = Float(baseY)
        // A low-frequency domain warp keeps every outline organic.
        let x = x0 + warp * (fbm(g, x0 / 320, y0 / 320, 2) - 0.5)
        let y = y0 + warp * 0.6 * (fbm(g, x0 / 320 + 7.7, y0 / 320 + 3.1, 2) - 0.5)
        let t = min(max((y - base) / (towerTop - base), 0), 1)
        let face = designFront - 40 - lean * t * t.squareRoot() - x
        let top = anvilTop - y
        let bottom = y0 - base
        let d = smin(smin(face, top, 80), bottom, 50)
        // The anvil's overhang: a layer running forward from the tower top, its underside rounding up to the tip.
        let tipX = designFront - overhang
        let rootX = designFront - lean - 120
        let along = min(max((x - rootX) / (tipX - rootX), 0), 1)
        let under = anvilTop - anvilThick * (1 - 0.6 * along * along)
        let o = smin(smin(y - under, anvilTop - y, 40), tipX - x, 60)
        return -smin(-d, -o, 60)
    }

    // MARK: Small maths

    static func smooth(_ a: Float, _ b: Float, _ x: Float) -> Float {
        let t = min(max((x - a) / max(b - a, 0.0001), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private static func smin(_ a: Float, _ b: Float, _ k: Float) -> Float {
        let h = max(k - abs(a - b), 0) / k
        return min(a, b) - h * h * k * 0.25
    }

    private static func rgb(_ c: RGBA, scale: Float) -> (Float, Float, Float) {
        (Float(c.r) * scale, Float(c.g) * scale, Float(c.b) * scale)
    }

    private static func lift(_ c: (Float, Float, Float), _ t: Float) -> (Float, Float, Float) {
        mixed(c, (1, 1, 1), t)
    }

    private static func mixed(_ a: (Float, Float, Float), _ b: (Float, Float, Float), _ t: Float) -> (Float, Float, Float) {
        (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
    }

    private static func byte(_ v: Float) -> UInt8 {
        guard v.isFinite else { return 0 }
        return UInt8(min(max(v * 255 + 0.5, 0), 255))
    }
}
