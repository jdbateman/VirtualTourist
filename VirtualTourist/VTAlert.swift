//
//  VTAlert.swift
//  VirtualTourist
//
//  Created by john bateman on 10/7/15.
//  Copyright (c) 2015 John Bateman. All rights reserved.
//

import UIKit
import Foundation

class VTAlert {
    
    var controller: UIViewController?
    
    /* designated initializer */
    init(viewController: UIViewController) {
        controller = viewController
    }
    
    /* 
    @brief display an UIAlertView presenting the error to the end user
    usage: 
        VTAlert(viewController:self).displayErrorAlertView("error_title", message: "error_message \(some_var)")
    */
    func displayErrorAlertView(title: String, message: String) {
        // Make the alert controller
        var alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        
        // Create and add the actions
        var okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default) { UIAlertAction in
            // do nothing on OK
        }
        alertController.addAction(okAction)
        
        // Present the Alert controller
        dispatch_async(dispatch_get_main_queue()) {
            if let controller = self.controller {
                controller.presentViewController(alertController, animated: true, completion: nil)
            }
        }
    }
}