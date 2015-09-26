//
//  Photo.swift
//  VirtualTourist
//
//  Created by john bateman on 9/22/15.
//  Copyright (c) 2015 John Bateman. All rights reserved.
//

import Foundation
import CoreData
import UIKit

@objc(Photo)

class Photo : NSManagedObject {
    
    struct keys {
        static let imageData: String = "imageData"
        static let pin: String = "pin"
    }
    
    static let entityName = "Photo"
    
    // JPEG image data for the meme picture
    @NSManaged var imageData: NSData?
    
    // pin to which the image belongs
    @NSManaged var pin: Pin?
    
    // UIImage computed from imageData property
    var image: UIImage? {
        get {
            if let theData = imageData {
                return UIImage(data: theData)
            } else {
                return nil
            }
        }
    }
    
    /* Core Data init method */
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    /* Init instance with a dictionary of values, and a core data context. */
    init(dictionary: [String: AnyObject], context: NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        imageData = dictionary[keys.imageData] as? NSData
        pin = dictionary[keys.pin] as? Pin
    }
    
}

/* Allows Photo instances to be compared.*/
extension Photo: Equatable {}
func ==(lhs: Photo, rhs: Photo) -> Bool {
    println("Photo Equatable called")
    return ( /*(lhs.imageData == rhs.imageData) && */(lhs.pin == rhs.pin) )  // TODO - update to use other metadata for comparison like title or url_m
}
