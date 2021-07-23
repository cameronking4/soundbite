//
//  SBExtensions.swift
//  SoundBite


import UIKit

extension UIViewController {
    
    func showAlert(title: String?, message: String?) {

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .default, handler: nil)
        
        alert.addAction(ok)
        present(alert, animated: true, completion: nil)
    }
    
    func showAlert(_ alert: UIAlertController) {
        guard self.presentedViewController != nil else {
            self.present(alert, animated: true, completion: nil)
            return
        }
    }

}

extension UIColor {
    
    var alpha: CGFloat {
        var alphaVal: CGFloat = 0
        
        getRed(nil, green: nil, blue: nil, alpha: &alphaVal)

        return alphaVal
    }
    
    /*
     Available Formats: rgba
         - **"abc"**
         - **"abc7"**
         - **"#abc7"**
         - **"00FFFF"**
         - **"#00FFFF"**
         - **"00FFFF77"**
     
     */
    fileprivate static func normalize(_ hex: String?) -> String {
        guard var hexString = hex else {
            return "00000000"
        }
        
        if hexString.hasPrefix("#") {
            hexString = String(hexString.dropFirst())
        }
        if hexString.count == 3 || hexString.count == 4 {
            hexString = hexString.map { "\($0)\($0)" } .joined()
        }
        let hasAlpha = hexString.count > 7
        if !hasAlpha {
            hexString += "ff"
        }
        return hexString
    }
    
    convenience init(hex: Any?) {
        var hexStr: String?
        if let val = hex as? Int {
            hexStr = String(format:"%06X", val)
        }else {
            hexStr = hex as? String
        }
        
        self.init(hex:hexStr)
    }
    
    convenience init(hex: String?) {
        let normalizedHexString: String = UIColor.normalize(hex)
        
        let scanner = Scanner(string: normalizedHexString)
        scanner.scanLocation = 0
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: "#")
        
        var rgbValue: UInt64 = 0
        
        scanner.scanHexInt64(&rgbValue)
        
        let r = (rgbValue & 0xff000000) >> 24
        let g = (rgbValue & 0x00ff0000) >> 16
        let b = (rgbValue & 0x0000ff00) >> 8
        let a = rgbValue & 0x000000ff
        
        self.init(
            red: CGFloat(r) / 0xff,
            green: CGFloat(g) / 0xff,
            blue: CGFloat(b) / 0xff,
            alpha: CGFloat(a) / 0xff
        )
    }
    
    func hexString() -> String {
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let hexString = String(format: "#%02X%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255), Int(alpha * 255))
        return hexString
    }
    
    func rgbInteger() -> Int {
        var fRed : CGFloat = 0
        var fGreen : CGFloat = 0
        var fBlue : CGFloat = 0
        var fAlpha: CGFloat = 0
        
        self.getRed(&fRed, green: &fGreen, blue: &fBlue, alpha: &fAlpha)
        
        let iRed = Int(fRed * 255.0)
        let iGreen = Int(fGreen * 255.0)
        let iBlue = Int(fBlue * 255.0)
        let _ = Int(fAlpha * 255.0)

        //  (Bits 16-23 are red, 8-15 are green, 0-7 are blue).
        let rgb =  (iRed << 16) + (iGreen << 8) + iBlue
        return rgb
    }
    
}
