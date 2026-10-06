// Génère la lueur floutée (Resources/AppIcon.icon/Assets/glow.png) : swift Scripts/make-glow.swift
import AppKit
import CoreImage

let size = 1024
let space = CGColorSpace(name: CGColorSpace.displayP3)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let rect = CGRect(x: 204, y: 204, width: 616, height: 616)
let path = CGPath(roundedRect: rect, cornerWidth: 182, cornerHeight: 182, transform: nil)
ctx.addPath(path)
ctx.setLineWidth(80)
ctx.replacePathWithStrokedPath()
ctx.clip()
let colors = [CGColor(red: 1, green: 0.54, blue: 0.36, alpha: 0.9), CGColor(red: 1, green: 0.31, blue: 0.63, alpha: 0.9),
              CGColor(red: 0.54, green: 0.36, blue: 1, alpha: 0.9)] as CFArray
let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 1])!
// Repère CoreGraphics : y vers le haut → orange en bas à gauche, violet en haut à droite.
ctx.drawLinearGradient(gradient, start: CGPoint(x: 150, y: 150), end: CGPoint(x: 874, y: 874), options: [])
let full = CGRect(x: 0, y: 0, width: size, height: size)
// Deux flous superposés : une lueur serrée autour de l'anneau + un voile large qui éclaire le fond noir.
let base = CIImage(cgImage: ctx.makeImage()!).clampedToExtent()
let tight = base.applyingGaussianBlur(sigma: 34).cropped(to: full)
let wide = base.applyingGaussianBlur(sigma: 120).cropped(to: full)
    .applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.55)])
let blurred = tight.composited(over: wide)
let out = CIContext().createCGImage(blurred, from: full, format: .RGBA8, colorSpace: space)!
let rep = NSBitmapImageRep(cgImage: out)
try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: "Resources/AppIcon.icon/Assets/glow.png"))
