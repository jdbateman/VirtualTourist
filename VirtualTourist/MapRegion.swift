//
//  MapRegion.swift
//  VirtualTourist
//
//  Created by john bateman on 9/18/15.
//  Copyright (c) 2015 John Bateman. All rights reserved.
//

import Foundation
import CoreData
import MapKit
import CoreLocation

@objc(MapRegion)

class MapRegion : NSManagedObject {
    
    @NSManaged var latitude: NSNumber
    @NSManaged var longitude: NSNumber
    @NSManaged var spanLatitude: NSNumber
    @NSManaged var spanLongitude: NSNumber
    
    struct Keys {
        static let latitude: String = "latitude"
        static let longitude: String = "longitude"
        static let spanLatitude: String = "spanLatitude"
        static let spanLongitude: String = "spanLongitude"
    }
    
    static let entityName = "MapRegion"
    
    var region: MKCoordinateRegion {
        get {
            let region = MKCoordinateRegion(center: coordinate, span: span)
            return region
        }
    }
    
    var coordinate: CLLocationCoordinate2D {
        get {
            let coordinate = CLLocationCoordinate2DMake(latitude.doubleValue, longitude.doubleValue)
            return coordinate
        }
    }
    
    var span: MKCoordinateSpan {
        get {
            let span = MKCoordinateSpanMake(spanLatitude.doubleValue, spanLongitude.doubleValue)
            return span
        }
    }
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
 
    init(dictionary: [String: AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName(MapRegion.entityName, inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        latitude = dictionary[Keys.latitude] as! Double
        longitude = dictionary[Keys.longitude] as! Double
        spanLatitude = dictionary[Keys.spanLatitude] as! Double
        spanLongitude = dictionary[Keys.spanLongitude] as! Double
    }
}