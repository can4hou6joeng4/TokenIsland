#!/usr/bin/env swift
import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct AppIconGenerator {
    let repositoryRoot: URL
    let resourcesDirectory: URL
    let iconsetDirectory: URL
    let outputICNS: URL
    let previewPNG: URL

    init(repositoryRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) {
        self.repositoryRoot = repositoryRoot
        self.resourcesDirectory = repositoryRoot.appendingPathComponent("Resources", isDirectory: true)
        self.iconsetDirectory = resourcesDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
        self.outputICNS = resourcesDirectory.appendingPathComponent("AppIcon.icns")
        self.previewPNG = resourcesDirectory.appendingPathComponent("AppIcon.png")
    }

    func run() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: resourcesDirectory, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: iconsetDirectory.path) {
            try fileManager.removeItem(at: iconsetDirectory)
        }
        try fileManager.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

        let canvas = try drawIcon(size: 1024)
        try writePNG(canvas, to: previewPNG)

        let variants: [(name: String, pixels: Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024),
        ]
        for variant in variants {
            let image = try drawIcon(size: variant.pixels)
            try writePNG(image, to: iconsetDirectory.appendingPathComponent(variant.name))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconsetDirectory.path, "-o", outputICNS.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "TokenIsland.AppIconGenerator",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "iconutil failed with status \(process.terminationStatus)"]
            )
        }

        try fileManager.removeItem(at: iconsetDirectory)
        print("Generated \(outputICNS.path)")
        print("Generated \(previewPNG.path)")
    }

    private func drawIcon(size: Int) throws -> CGImage {
        let dimension = CGFloat(size)
        let scale = dimension / 1024.0
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(
                domain: "TokenIsland.AppIconGenerator",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap context for \(size)x\(size) icon"]
            )
        }

        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        context.scaleBy(x: scale, y: scale)

        drawRoundedBackground(in: context)
        drawNotch(in: context)
        drawPulse(in: context)
        drawStatusDots(in: context)
        drawEdgeHighlight(in: context)

        guard let image = context.makeImage() else {
            throw NSError(
                domain: "TokenIsland.AppIconGenerator",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to render \(size)x\(size) icon"]
            )
        }
        return image
    }

    private func drawRoundedBackground(in context: CGContext) {
        let rect = CGRect(x: 74, y: 74, width: 876, height: 876)
        let path = CGPath(roundedRect: rect, cornerWidth: 214, cornerHeight: 214, transform: nil)
        context.saveGState()
        context.addPath(path)
        context.clip()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                NSColor(red: 0.12, green: 0.16, blue: 0.24, alpha: 1).cgColor,
                NSColor(red: 0.06, green: 0.09, blue: 0.15, alpha: 1).cgColor,
                NSColor(red: 0.02, green: 0.03, blue: 0.07, alpha: 1).cgColor,
            ] as CFArray,
            locations: [0.0, 0.56, 1.0]
        )!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 120, y: 944),
            end: CGPoint(x: 930, y: 104),
            options: []
        )

        context.setFillColor(NSColor.white.withAlphaComponent(0.055).cgColor)
        context.fillEllipse(in: CGRect(x: 176, y: 646, width: 560, height: 220))
        context.setFillColor(NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.18).cgColor)
        context.fillEllipse(in: CGRect(x: 346, y: 76, width: 620, height: 250))
        context.restoreGState()
    }

    private func drawNotch(in context: CGContext) {
        let rect = CGRect(x: 328, y: 736, width: 368, height: 102)
        let path = CGPath(roundedRect: rect, cornerWidth: 51, cornerHeight: 51, transform: nil)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -8), blur: 16, color: NSColor.black.withAlphaComponent(0.36).cgColor)
        context.setFillColor(NSColor(red: 0.005, green: 0.01, blue: 0.025, alpha: 0.98).cgColor)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(path)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.08).cgColor)
        context.setLineWidth(3)
        context.strokePath()
        context.restoreGState()
    }

    private func drawPulse(in context: CGContext) {
        let glowPath = CGMutablePath()
        glowPath.move(to: CGPoint(x: 206, y: 482))
        glowPath.addCurve(to: CGPoint(x: 318, y: 578), control1: CGPoint(x: 250, y: 548), control2: CGPoint(x: 276, y: 576))
        glowPath.addCurve(to: CGPoint(x: 455, y: 560), control1: CGPoint(x: 370, y: 580), control2: CGPoint(x: 405, y: 536))
        glowPath.addCurve(to: CGPoint(x: 611, y: 506), control1: CGPoint(x: 516, y: 588), control2: CGPoint(x: 552, y: 498))
        glowPath.addCurve(to: CGPoint(x: 816, y: 614), control1: CGPoint(x: 696, y: 516), control2: CGPoint(x: 728, y: 606))

        context.saveGState()
        context.addPath(glowPath)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(76)
        context.setShadow(offset: .zero, blur: 34, color: NSColor(red: 0.25, green: 0.74, blue: 0.92, alpha: 0.42).cgColor)
        context.replacePathWithStrokedPath()
        context.clip()
        drawPulseGradient(in: context)
        context.restoreGState()

        let signalPath = CGMutablePath()
        signalPath.move(to: CGPoint(x: 222, y: 424))
        signalPath.addLine(to: CGPoint(x: 334, y: 424))
        signalPath.addLine(to: CGPoint(x: 386, y: 548))
        signalPath.addLine(to: CGPoint(x: 470, y: 338))
        signalPath.addLine(to: CGPoint(x: 554, y: 646))
        signalPath.addLine(to: CGPoint(x: 622, y: 424))
        signalPath.addLine(to: CGPoint(x: 796, y: 424))

        context.saveGState()
        context.addPath(signalPath)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.96).cgColor)
        context.setLineWidth(34)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 8, color: NSColor.black.withAlphaComponent(0.28).cgColor)
        context.strokePath()
        context.restoreGState()
    }

    private func drawPulseGradient(in context: CGContext) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                NSColor(red: 0.20, green: 0.83, blue: 0.55, alpha: 1).cgColor,
                NSColor(red: 0.22, green: 0.74, blue: 0.96, alpha: 1).cgColor,
                NSColor(red: 0.96, green: 0.62, blue: 0.12, alpha: 1).cgColor,
            ] as CFArray,
            locations: [0.0, 0.56, 1.0]
        )!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 184, y: 376),
            end: CGPoint(x: 842, y: 642),
            options: []
        )
    }

    private func drawStatusDots(in context: CGContext) {
        let dots: [(CGFloat, NSColor)] = [
            (358, NSColor(red: 0.20, green: 0.83, blue: 0.55, alpha: 1)),
            (462, NSColor(red: 0.22, green: 0.74, blue: 0.96, alpha: 1)),
            (566, NSColor(red: 0.96, green: 0.62, blue: 0.12, alpha: 1)),
            (670, NSColor(red: 0.75, green: 0.52, blue: 0.96, alpha: 1)),
        ]

        for (x, color) in dots {
            context.saveGState()
            context.setShadow(offset: .zero, blur: 16, color: color.withAlphaComponent(0.42).cgColor)
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: CGRect(x: x, y: 206, width: 52, height: 52))
            context.restoreGState()
        }
    }

    private func drawEdgeHighlight(in context: CGContext) {
        let rect = CGRect(x: 74, y: 74, width: 876, height: 876)
        let path = CGPath(roundedRect: rect, cornerWidth: 214, cornerHeight: 214, transform: nil)
        context.saveGState()
        context.addPath(path)
        context.setLineWidth(5)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.11).cgColor)
        context.strokePath()
        context.restoreGState()
    }

    private func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(
                domain: "TokenIsland.AppIconGenerator",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create PNG destination for \(url.path)"]
            )
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(
                domain: "TokenIsland.AppIconGenerator",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Unable to encode PNG for \(url.path)"]
            )
        }
    }
}

do {
    try AppIconGenerator().run()
} catch {
    fputs("Failed to generate app icon: \(error.localizedDescription)\n", stderr)
    exit(1)
}
