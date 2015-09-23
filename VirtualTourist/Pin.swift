//
//  Pin.swift
//  VirtualTourist
//
//  Created by john bateman on 9/17/15.
//  Copyright (c) 2015 John Bateman. All rights reserved.
//

import Foundation
import CoreData
import MapKit
import CoreLocation

@objc(Pin)

class Pin: NSManagedObject {
    
    @NSManaged var latitude: NSNumber
    @NSManaged var longitude: NSNumber
    @NSManaged var photos: [Photo]
    
    struct Keys {
        static let latitude: String = "latitude"
        static let longitude: String = "longitude"
        static let photos = "photos"
    }
    
    static let entityName = "Pin"
    
    var annotation: MKPointAnnotation {
        get {
            var annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            return annotation
        }
    }
    
    var coordinate: CLLocationCoordinate2D {
        get {
            let coordinate = CLLocationCoordinate2D(latitude: latitude.doubleValue, longitude: longitude.doubleValue )
            return coordinate
        }
    }
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String: AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName(Pin.entityName, inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        latitude = dictionary[Keys.latitude] as! Double
        longitude = dictionary[Keys.longitude] as! Double
    }
}
