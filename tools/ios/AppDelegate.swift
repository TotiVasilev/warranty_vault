import Foundation

// Pure geometry: convert independent OCR boxes into horizontal table rows.
struct WVTextBox {
    let text: String
    let rect: CGRect // top-left origin, same coordinate space for all boxes
}

func wvRows(_ input: [WVTextBox]) -> String {
    let boxes = input.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.rect.width > 0 && $0.rect.height > 0 }
    let sorted = boxes.sorted { $0.rect.midY == $1.rect.midY ? $0.rect.minX < $1.rect.minX : $0.rect.midY < $1.rect.midY }
    var rows: [[WVTextBox]] = []
    for box in sorted {
        // Match the nearest vertically overlapping row; avoid joining adjacent lines.
        var best: Int? = nil
        var distance = CGFloat.infinity
        for i in rows.indices {
            let reference = rows[i][0].rect
            let delta = abs(reference.midY - box.rect.midY)
            let overlap = min(reference.maxY, box.rect.maxY) - max(reference.minY, box.rect.minY)
            if overlap >= min(reference.height, box.rect.height) * 0.5 && delta <= max(reference.height, box.rect.height) * 0.55 && delta < distance {
                best = i; distance = delta
            }
        }
        if let index = best { rows[index].append(box) } else { rows.append([box]) }
    }
    return rows.map { row in
        row.sorted { $0.rect.minX < $1.rect.minX }.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: " ")
    }.joined(separator: "\n")
}

#if WV_OCR_SELF_TEST
// Run with swift -D WV_OCR_SELF_TEST tools/ios/AppDelegate.swift
func box(_ text: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat = 70) -> WVTextBox {
    WVTextBox(text: text, rect: CGRect(x: x, y: y, width: width, height: 14))
}
let shuffled = [box("96 months", 330, 82), box("SERIAL", 210, 10), box("RAM 8 GB", 10, 82), box("RAM 16 GB", 10, 60), box("DESCRIPTION", 10, 10), box("ABC123456", 210, 61), box("36 months", 330, 39), box("WARRANTY", 330, 10), box("Motherboard", 10, 38), box("DEF234567", 210, 39), box("96 months", 330, 60), box("GHI345678", 210, 82)]
let expected = "DESCRIPTION SERIAL WARRANTY\nMotherboard DEF234567 36 months\nRAM 16 GB ABC123456 96 months\nRAM 8 GB GHI345678 96 months"
precondition(wvRows(shuffled) == expected, wvRows(shuffled))
precondition(wvRows([]).isEmpty)
precondition(wvRows([box("Описание", 0, 0), box("Serial number", 100, 1), box("Гаранция", 230, 0)]) == "Описание Serial number Гаранция")
print("OCR geometry self-test passed (row order, mixed scripts, empty input).")
#else
import Flutter
import UIKit
import Vision
import ImageIO
import SwiftyTesseract

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let ocrQueue = DispatchQueue(label: "warranty.vault.ocr", qos: .userInitiated)
    private var ocrChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        // Use the same legacy startup path as the working iOS v2 build.
        if let registrar = self.registrar(forPlugin: "WarrantyVaultNativeOCR") {
            let channel = FlutterMethodChannel(name: "warranty_vault/ios_ocr", binaryMessenger: registrar.messenger())
            ocrChannel = channel
            channel.setMethodCallHandler { [weak self] call, result in
                guard call.method == "recognize" else { result(FlutterMethodNotImplemented); return }
                guard let args = call.arguments as? [String: Any], let path = args["path"] as? String, let language = args["language"] as? String, let self = self else {
                    result(FlutterError(code: "bad_args", message: "Missing OCR image or language", details: nil)); return
                }
                let useVision = args["vision"] as? Bool ?? true
                let pageMode = args["layout"] as? String ?? "6"
                self.ocrQueue.async {
                    do {
                        let texts = try autoreleasepool { try self.recognize(path: path, language: language, useVision: useVision, pageMode: pageMode) }
                        DispatchQueue.main.async { result(texts) }
                    } catch {
                        DispatchQueue.main.async { result(FlutterError(code: "ocr_failed", message: error.localizedDescription, details: nil)) }
                    }
                }
            }
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func recognize(path: String, language: String, useVision: Bool, pageMode: String) throws -> [String] {
        // ImageIO honors EXIF orientation and avoids decoding a huge camera image at full size.
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 3200,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else {
            throw NSError(domain: "WarrantyVaultOCR", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not decode the photo."])
        }
        var candidates: [String] = []
        // Apple's OCR is an additional candidate, not a replacement for languages it lacks.
        if useVision {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false // preserve IDs and product codes
            let mapping = ["eng":"en", "bul":"bg", "deu":"de", "nld":"nl", "fra":"fr", "spa":"es", "ita":"it", "ron":"ro", "pol":"pl", "por":"pt", "ell":"el", "tur":"tr", "rus":"ru", "ukr":"uk"]
            let supported = (try? request.supportedRecognitionLanguages()) ?? []
            let preferred = language.split(separator: "+").compactMap { mapping[String($0)] }
            let chosen = preferred.compactMap { prefix in supported.first { $0 == prefix || $0.hasPrefix(prefix + "-") } }
            if !chosen.isEmpty {
                request.recognitionLanguages = chosen
                if #available(iOS 16.0, *) { request.automaticallyDetectsLanguage = true }
                do {
                    try VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:]).perform([request])
                    let boxes: [WVTextBox] = (request.results ?? []).compactMap { observation in
                        guard let text = observation.topCandidates(1).first?.string else { return nil }
                        let r = observation.boundingBox
                        return WVTextBox(text: text, rect: CGRect(x: r.minX, y: 1 - r.maxY, width: r.width, height: r.height))
                    }
                    candidates.append(wvRows(boxes))
                } catch { /* Tesseract below remains available. */ }
            }
        }
        // Existing bundled language models support all 14 selectable languages.
        // Check the files first: older SwiftyTesseract aborts if initialization fails.
        let langs = language.split(separator: "+").map(String.init)
        let allowed: Set<String> = ["eng","bul","deu","nld","fra","spa","ita","ron","pol","por","ell","tur","rus","ukr"]
        let directory = Bundle.main.bundleURL.appendingPathComponent("tessdata", isDirectory: true)
        if !langs.isEmpty && langs.allSatisfy({ allowed.contains($0) && FileManager.default.fileExists(atPath: directory.appendingPathComponent($0 + ".traineddata").path) }) {
            let reader = SwiftyTesseract(language: .custom(language))
            reader.preserveInterwordSpaces = true
            let primary = Int(pageMode) ?? 6
            let modes = [primary, primary == 6 ? 3 : 6]
            // Use the requested layout plus one genuinely different layout.
            for mode in modes {
                reader.wvSetPageLayout(mode)
                if case .success(let text) = reader.performOCR(on: UIImage(cgImage: cg)) {
                    candidates.append(text)
                    if case .success(let blocks) = reader.recognizedBlocks(for: .word) {
                        candidates.append(wvRows(blocks.map { WVTextBox(text: $0.text, rect: $0.boundingBox) }))
                    }
                }
            }
        }
        return candidates.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
#endif
