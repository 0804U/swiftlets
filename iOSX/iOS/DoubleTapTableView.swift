//
//  DoubleTapTableView.swift
//  swiftlets
//
//  Created by Frank Vernon on 12/2/15.
//  Copyright © 2015 Frank Vernon. All rights reserved.
//

import UIKit

protocol DoubleTapTableViewDelegate: UITableViewDelegate {
    func tableView(tableView: UITableView, didDoubleTapRowAtIndexPath indexPath: NSIndexPath)
}

/**
     UITableView subclass and delegate that automatically detects double tap gestures on table view rows
*/
class DoubleTapTableView: UITableView {
    var doubleTapDelegate: DoubleTapTableViewDelegate? {
        get {
            return self.delegate as? DoubleTapTableViewDelegate
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch:UITouch in touches {
            if touch.tapCount == 2 {
                if let row:IndexPath = indexPathForRow(at: touch.location(in: self)) {
                    doubleTapDelegate?.tableView(tableView: self, didDoubleTapRowAtIndexPath: row as NSIndexPath)
                }
            }
        }

        super.touchesEnded(touches, with: event)
    }
}
