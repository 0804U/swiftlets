//
//  Miscellaneous.swift
//  swiftlets
//
//  Created by Frank Vernon on 5/31/16.
//  Copyright © 2016 Frank Vernon. All rights reserved.
//

import Foundation
import QuartzCore

extension CGRect {
    var center:CGPoint {
        return CGPoint(x: self.midX, y: self.midY);
    }
    
    static func rectCenteredOn(_ center:CGPoint, radius:CGFloat) -> CGRect {
        return CGRect(x: floor(center.x - radius), y: floor(center.y - radius), width: floor(radius*2.0), height: floor(radius*2.0))
    }

    var top:CGFloat {
        return self.origin.y - self.size.height
    }

    var bottom:CGFloat {
        return self.origin.y
    }

    var left:CGFloat {
        return self.origin.x
    }

    var right:CGFloat {
        return self.origin.x + self.size.width
    }
}

extension CGSize {
    func maxDimension() -> CGFloat {
        return width > height ? width : height
    }

    func minDimension() -> CGFloat {
        return width > height ? height : width
    }
}

extension TimeInterval {
    func toPicoseconds() -> Double {
        return self * 1000.0 * 1000.0 * 1000.0 * 1000.0
    }

    func toNanoseconds() -> Double {
        return self * 1000.0 * 1000.0 * 1000.0
    }

    func toMicroseconds() -> Double {
        return self * 1000.0 * 1000.0
    }

    func toMilliseconds() -> Double {
        return self * 1000.0
    }

    func toMinutes() -> Double {
        return self/60.0
    }
    
    func toHours() -> Double {
        return self/60.0/60.0
    }
    
    func toDays() -> Double {
        return self/60.0/60.0/24.0
    }

    /**
     Returns a localized human readable description of the time interval.

     - note: The result is limited to Days, Hours, and Minutes and includes an indication of approximation.

     Examples:
     * About 14 minutes
     * About 1 hour, 7 minutes
     */
    func approximateDurationLocalizedDescription() -> String {
        let start = Date()
        let end = Date(timeInterval: self, since: start)

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.includesApproximationPhrase = true
        formatter.includesTimeRemainingPhrase = false
        formatter.allowedUnits = [.weekday, .hour, .minute]
        formatter.maximumUnitCount = 2
        
        return formatter.string(from: start, to: end) ?? ""
    }
}

extension UserDefaults {
    ///setObject(forKey:) where value != nil, removeObjectForKey where value == nil
    func setOrRemoveObject(_ value: Any?, forKey defaultName: String) {
        if value != nil {
            UserDefaults.standard.set(value, forKey: defaultName)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultName)
        }
    }
}

extension CGAffineTransform {
    ///returns the current rotation of the transform in radians
    func rotationInRadians() -> Double {
        return Double(atan2f(Float(self.b), Float(self.a)))
    }

    ///returns the current rotation of the transform in degrees 0.0 - 360.0
    func rotationInDegrees() -> Double {
        var result = Double(rotationInRadians()) * (180.0/M_PI)
        if result < 0.0 {
            result = 360.0 - result
        }
        return result
    }
}

///Trivial indexing generator that wraps back to startIndex when reaching endIndex
class WrappingIndexingGenerator<C: Collection>: IteratorProtocol {
    var _colletion: C
    var _index: C.Index
    func next() -> C.Iterator.Element? {
        var item:C.Iterator.Element?
        if _index == _colletion.endIndex {
            _index = _colletion.startIndex
        }
        item = _colletion[_index]
        _index = _colletion.index(after: _index)
        return item
    }
    init(_ colletion: C) {
        _colletion = colletion;
        _index = _colletion.startIndex
    }
}
