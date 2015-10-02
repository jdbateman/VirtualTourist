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
    
    struct InitKeys {
        static let imageData: String = "imageData"
        static let pin: String = "pin"
        static let imageUrl: String = "imageUrl"
        static let title: String = "title"
        static let id: String = "id"
    }
    
    static let entityName = "Photo"
    
    /* JPEG image data for the Photo. */
    @NSManaged var imageData: NSData?   // TODO: remove @NSManaged and remove from xcdatamodeld
    
    /* Pin object to which the image belongs */
    @NSManaged var pin: Pin?
    
    /* url identifying the location of the image prior to download to the local device. */
    @NSManaged var imageUrl: String?
    
    /* title bestowed on image by flickr user */
    @NSManaged var title: String?
    
    /* id of flickr image. Used as base of filename for associated NSData stored on local disk. */
    @NSManaged var id: String?
    
    /* The UIImage representation of the picture data. Acquire using the getImage method. */
    var image: UIImage?
    
    /* Core Data init method */
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    /* Init instance with a dictionary of values, and a core data context. */
    init(dictionary: [String: AnyObject], context: NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        imageData = dictionary[InitKeys.imageData] as? NSData
        pin = dictionary[InitKeys.pin] as? Pin
        imageUrl = dictionary[InitKeys.imageUrl] as? String
        title = dictionary[InitKeys.title] as? String
        id = dictionary[InitKeys.id] as? String
    }
    
    /* 
    @brief Acquire the UIImage for this Photo object.
    @discussion The image is retrieved using the following sequence:
        If the image has not previously been downloaded, then download the image from self.imageUrl.
        else build the image from NSData stored in Core Data
        TODO - finish description when logic is updated for caching and file system storage
    @param completion (in)
    @param success (out) - true if image successfully acquired, else false.
    @param error (out) - NSError object if an error occurred, else nil.
    @param image (out) - the retrieved UIImage. May be nil if no image was found, or if an error occurred.
    */
    func getImage(completion: (success: Bool, error: NSError?, image: UIImage?) -> Void ) {
        
        // Try loading the image from the image cache.
        if let url = self.imageUrl {
            if let theImage: UIImage = NSCache.sharedInstance.objectForKey(url) as? UIImage {
                println("image loaded from cache")
                completion(success: true, error: nil, image: theImage)
                return
            }
        }
        
        // Try loading the data from the file system.
        if let id = self.id {
            if let image = getImageFromFileSystem(id) {
                println("image loaded from file system")
                completion(success: true, error: nil, image: image)
                return
            }
        }
        
//        // Try loading the data from Core Data.
//        if let imageData = self.imageData {
//            println("image loaded from core data")
//            completion(success: true, error: nil, image: UIImage(data: imageData))
//            return
//        }

        // Load the image from the server asynchronously on a background queue.
        if let url = self.imageUrl {
            self.dowloadImageFrom(url) { success, error, theImage in
                if success {
                    if let theImage = theImage {
                        // retrieve the image data
                        let imageData = UIImageJPEGRepresentation(theImage, 1)
                        
//                        // save the image data to the Photo property (Will be captured in Core Data on next saveContext)
//                        self.imageData = imageData
                        
                        // save the image data to the file system
                        if let id = self.id {
                            let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
                            dispatch_async(backgroundQueue, {
                                self.saveImageToFileSystem(id, image: theImage)
                            })
                        }
                        
                        // save the image to the image cache
                        if let url = self.imageUrl {
                            let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
                            dispatch_async(backgroundQueue, {
                                NSCache.sharedInstance.setObject(theImage, forKey: url)
                            })
                        }
                    }
                    println("image downloaded from server")
                    completion(success: true, error: nil, image: theImage)
                    return
                } else {
                    // TODO - handle the failed download by retrying once?
                    println("failed to download image. stick with placholder image.")
                    var error: NSError = NSError(domain: "Image download failed.", code: 909, userInfo: nil)
                    completion(success: false, error: error, image: nil)
                }
            }
        }
    }
}

/* Image management helper functions */
extension Photo {
    
    /* Save image to a file with the name filename on the filesystem in the Documents directory. */
    func saveImageToFileSystem(filename: String, image: UIImage?) {
        if let image = image {
            let imageData = UIImageJPEGRepresentation(image, 1)
            let path = pathForImageFileWith(filename)
            if let path = path {
                imageData.writeToFile(path, atomically: true)
            }
        }
    }
    
    /* Load the data from filename and return as a UIImage object. */
    func getImageFromFileSystem(filename: String) -> UIImage? {
        let path = pathForImageFileWith(filename)
        if let path = path {
            if NSFileManager.defaultManager().fileExistsAtPath(path) {
                let imageData = NSFileManager.defaultManager().contentsAtPath(path)
                if let imageData = imageData {
                    let image = UIImage(data: imageData)
                    return image
                }
            }
        }
        return nil
    }
    
    /* Return the path to filename in the app’s Documents directory */
    func pathForImageFileWith(filename: String) -> String? {
        // the Documents directory's path is returned as a one-element array.
        let dirPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! String
        let pathArray = [dirPath, filename]
        let fileURL =  NSURL.fileURLWithPathComponents(pathArray)!
        return fileURL.path
    }
    
    // Download the image identified by imageUrlString in a background thread, convert it to a UIImage object, and return the object.
    func dowloadImageFrom(imageUrlString: String?, completion: (success: Bool, error: NSError?, image: UIImage?) -> Void) {
        
        let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
        dispatch_async(backgroundQueue, {
            // get the binary image data
            let imageURL = NSURL(string: imageUrlString!)
            if let imageData = NSData(contentsOfURL: imageURL!) {
                
                // Convert the image data to a UIImage object and append to the array to be returned.
                if let picture = UIImage(data: imageData) {
                    completion(success: true, error: nil, image: picture)
                }
                else {
                    let error = NSError(domain: "cannot convert image data", code: 908, userInfo: nil)
                    completion(success: false, error: error, image: nil)
                }
                
            } else {
                println("Image does not exist at \(imageURL)")
                let error = NSError(domain: "Image does not exist at \(imageURL)", code: 904, userInfo: nil)
                completion(success: false, error: error, image: nil)
            }
        })
    }
}

/* Allows Photo instances to be compared.*/
extension Photo: Equatable {}
func ==(lhs: Photo, rhs: Photo) -> Bool {
    return ( lhs.id == rhs.id )
}
