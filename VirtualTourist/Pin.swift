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

    /* The index of the page to request when the next flickr search query is made for this Pin. */
    @NSManaged var flickrPage: NSNumber

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
            annotation.title = "select to view photos"
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
        flickrPage = 1
    }
}

/* Allows Pin instances to be compared.*/
extension Pin: Equatable {}
func ==(lhs: Pin, rhs: Pin) -> Bool {
    return ( (lhs.latitude == rhs.latitude) && (lhs.longitude == rhs.longitude) )
}