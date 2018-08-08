//
//  UIColor+Utilities.swift
//  swiftlets
//
//  Created by Frank Vernon on 4/30/16.
//  Copyright © 2016 Frank Vernon. All rights reserved.
//

import UIKit

extension UIColor {
    /**
     Convenience initializer for creating UIColor from HTML hex formats: #RRGGBB
     
     - parameters:
     - htmlHex: HTML style hex description of RGB color: [#]RRGGBB[AA]
     
     - note: The leading # and trailing alpha valuse are optional.
     
     - returns: The color specified by the hex string or the the color white in the event parsing fails.
     */
    public convenience init?(htmlHex:String) {
        guard let color = htmlHex.colorForHex() else {
            return nil
        }
        
        self.init(cgColor: color.cgColor)
    }
}

extension String {
    public func colorForHex() -> UIColor? {
        //creating temp string so we can manipulate as necessary
        var working = self
        
        //remove leading # if present
        if working.hasPrefix("#") {
            working.remove(at: startIndex)
        }
        
        //ensure string fits length requirements
        switch working.count {
        case ...5, 7, 9...:
            //ilegal lengths
            return nil
            
        case 6:
            //RRGGBB
            //add alpha for ease of processing below
            working.append("FF")
            
        case 8:
             //RRGGBBAA
            break
            
        default:
            //just to keep compiler happy
            return nil
        }
        
        var rgbaInt:UInt64 = 0
        guard Scanner(string: working).scanHexInt64(&rgbaInt) else {
            return nil
        }
        
        let red = CGFloat((rgbaInt & 0xFF000000) >> 24)/255.0
        let green = CGFloat((rgbaInt & 0x00FF0000) >> 16)/255.0
        let blue = CGFloat((rgbaInt & 0x0000FF00) >> 8)/255.0
        let alpha = CGFloat((rgbaInt & 0x000000FF))/255.0

        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
