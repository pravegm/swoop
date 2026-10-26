import Foundation

// MARK: - Birds (GAME-DESIGN §8): cosmetic, all balanced the same. Personality = wing shape and trail colour.

public enum BirdCatalog {

    public static var all: [Bird] {
        return birds
    }

    public static func bird(_ id: BirdID) -> Bird {
        for b in birds where b.id == id { return b }
        return birds[0]
    }

    private static let birds: [Bird] = [
        Bird(id: .gull, name: "Gull", blurb: "Bold, loud and at home on any swell.",
             body: RGBA(hex: 0xF4F2EE), wing: RGBA(hex: 0x9AA5B1), wingTip: RGBA(hex: 0x2B2F36),
             beak: RGBA(hex: 0xF2B33D), trail: RGBA(hex: 0xD8F1FF),
             span: 1.0, pointiness: 0.55, unlockRank: 0),
        Bird(id: .tern, name: "Tern", blurb: "A sea swallow. Light, quick, never still.",
             body: RGBA(hex: 0xFAFAF7), wing: RGBA(hex: 0xC9D3DC), wingTip: RGBA(hex: 0x1E2228),
             beak: RGBA(hex: 0xE84A2F), trail: RGBA(hex: 0xBFE8F2),
             span: 0.95, pointiness: 0.8, unlockRank: 2),
        Bird(id: .puffin, name: "Puffin", blurb: "Stubby wings, huge heart, brilliant beak.",
             body: RGBA(hex: 0x2A2C33), wing: RGBA(hex: 0x1E2026), wingTip: RGBA(hex: 0x121318),
             beak: RGBA(hex: 0xF26B2A), trail: RGBA(hex: 0xFFD6B0),
             span: 0.72, pointiness: 0.15, unlockRank: 4),
        Bird(id: .swift, name: "Swift", blurb: "Scythe wings. Sleeps on the wind.",
             body: RGBA(hex: 0x3B3A40), wing: RGBA(hex: 0x4A4950), wingTip: RGBA(hex: 0x2A292E),
             beak: RGBA(hex: 0x1F1E22), trail: RGBA(hex: 0xC7D8FF),
             span: 0.85, pointiness: 1.0, unlockRank: 6),
        Bird(id: .albatross, name: "Albatross", blurb: "Eleven feet of wing. Circles the world.",
             body: RGBA(hex: 0xFFFFFF), wing: RGBA(hex: 0x3D3F45), wingTip: RGBA(hex: 0x26282C),
             beak: RGBA(hex: 0xF4C9A0), trail: RGBA(hex: 0xE9F6FF),
             span: 1.35, pointiness: 0.95, unlockRank: 8),
        Bird(id: .petrel, name: "Storm Petrel", blurb: "Dances on the waves ahead of the weather.",
             body: RGBA(hex: 0x2B2730), wing: RGBA(hex: 0x342F3A), wingTip: RGBA(hex: 0x1D1A21),
             beak: RGBA(hex: 0x141216), trail: RGBA(hex: 0xA9E7E0),
             span: 0.78, pointiness: 0.7, unlockRank: 10),
        Bird(id: .heron, name: "Night Heron", blurb: "Slow, broad wings. Flies by moonlight.",
             body: RGBA(hex: 0x9DA7B5), wing: RGBA(hex: 0x6E7B8C), wingTip: RGBA(hex: 0x3E4A5A),
             beak: RGBA(hex: 0x2C2F36), trail: RGBA(hex: 0xB8A6FF),
             span: 1.15, pointiness: 0.3, unlockRank: 12),
        Bird(id: .gannet, name: "Golden Gannet", blurb: "The legend of the Storm Riders. Dives like a dart.",
             body: RGBA(hex: 0xFFF6E0), wing: RGBA(hex: 0xF2C14E), wingTip: RGBA(hex: 0x9C6B1E),
             beak: RGBA(hex: 0x8FA3B8), trail: RGBA(hex: 0xFFD36E),
             span: 1.2, pointiness: 0.85, unlockRank: 14),
    ]
}

// MARK: - Skies (GAME-DESIGN §8). The storm is always a slate front, tinted to sit in each sky.

public enum SkyCatalog {

    public static var all: [Sky] {
        return skies
    }

    public static func sky(_ id: SkyID) -> Sky {
        for s in skies where s.id == id { return s }
        return skies[0]
    }

    private static let skies: [Sky] = [
        Sky(id: .goldenHour, name: "Golden Hour",
            zenith: RGBA(hex: 0x4A78B5), horizon: RGBA(hex: 0xFFC27A), sun: RGBA(hex: 0xFFE3A3),
            seaNear: RGBA(hex: 0x1F5E7A), seaFar: RGBA(hex: 0x3E86A0), foam: RGBA(hex: 0xFFF4E0),
            storm: RGBA(hex: 0x3B4452), unlockRank: 0),
        Sky(id: .roseDusk, name: "Rose Dusk",
            zenith: RGBA(hex: 0x5B4C8C), horizon: RGBA(hex: 0xF59BA0), sun: RGBA(hex: 0xFFD2B8),
            seaNear: RGBA(hex: 0x3A3F6E), seaFar: RGBA(hex: 0x6C6A9A), foam: RGBA(hex: 0xFCE9EE),
            storm: RGBA(hex: 0x3A3B4E), unlockRank: 3),
        Sky(id: .northernLights, name: "Northern Lights",
            zenith: RGBA(hex: 0x0B1630), horizon: RGBA(hex: 0x1E6B6A), sun: RGBA(hex: 0xB9FFE1),
            seaNear: RGBA(hex: 0x0B2433), seaFar: RGBA(hex: 0x15404D), foam: RGBA(hex: 0xCFFAF0),
            storm: RGBA(hex: 0x2C3440), unlockRank: 6),
        Sky(id: .monsoon, name: "Monsoon",
            zenith: RGBA(hex: 0x5E7480), horizon: RGBA(hex: 0xC9D6CF), sun: RGBA(hex: 0xF4F1D8),
            seaNear: RGBA(hex: 0x2E5650), seaFar: RGBA(hex: 0x4E7A72), foam: RGBA(hex: 0xEEF5F0),
            storm: RGBA(hex: 0x37434A), unlockRank: 9),
        Sky(id: .moonrise, name: "Moonrise",
            zenith: RGBA(hex: 0x101A3A), horizon: RGBA(hex: 0x39507E), sun: RGBA(hex: 0xF2F0E6),
            seaNear: RGBA(hex: 0x0E1E3A), seaFar: RGBA(hex: 0x233A63), foam: RGBA(hex: 0xDCE6FF),
            storm: RGBA(hex: 0x2A3142), unlockRank: 12),
    ]
}
