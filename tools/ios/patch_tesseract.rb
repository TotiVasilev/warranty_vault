# Applied by CocoaPods on macOS only. Adds a narrow layout API to the existing
# SwiftyTesseract 3.x source; fails the build if its expected API changes.
def wv_patch_tesseract(installer)
  root = installer.sandbox.root.to_s
  candidates = Dir.glob(File.join(root, 'SwiftyTesseract', '**', 'SwiftyTesseract.swift')).select do |path|
    File.read(path).include?('private let tesseract: TessBaseAPI')
  end
  raise 'Expected SwiftyTesseract 3.x OCR source; cannot safely enable page layouts' unless candidates.length == 1
  path = candidates.first
  source = File.read(path)
  unless source.include?('func wvSetPageLayout(')
    # CocoaPods may mark downloaded source read-only.
    File.chmod(File.stat(path).mode | 0200, path)
    File.open(path, 'a') do |f|
      f.write <<~SWIFT

        // Warranty Vault: select a real Tesseract page segmentation mode.
        extension SwiftyTesseract {
          public func wvSetPageLayout(_ layout: Int) {
            switch layout {
            case 3: TessBaseAPISetPageSegMode(tesseract, PSM_AUTO)
            case 11: TessBaseAPISetPageSegMode(tesseract, PSM_SPARSE_TEXT)
            default: TessBaseAPISetPageSegMode(tesseract, PSM_SINGLE_BLOCK)
            }
          }
        }
      SWIFT
    end
  end
  puts 'Warranty Vault: native Tesseract page layout API ready'
end
