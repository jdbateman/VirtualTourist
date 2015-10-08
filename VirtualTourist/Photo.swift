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
        static let pin: String = "pin"
        static let imageUrl: String = "imageUrl"
        static let title: String = "title"
        static let id: String = "id"
    }
    
    static let entityName = "Photo"
    
    /* Pin object to which the image belongs */
    @NSManaged var pin: Pin?
    
    /* url identifying the location of the image prior to download to the local device. */
    @NSManaged var imageUrl: String?
    
    /* title bestowed on image by flickr user */
    @NSManaged var title: String?
    
    /* ID of flickr image. Used as the base of the filename for the file containing the associated NSData. The file is stored on the local disk and can be managed with the image management helper methods of this class. */
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
        
        pin = dictionary[InitKeys.pin] as? Pin
        imageUrl = dictionary[InitKeys.imageUrl] as? String
        title = dictionary[InitKeys.title] as? String
        id = dictionary[InitKeys.id] as? String
    }
        
    /* 
    @brief Acquire the UIImage for this Photo object.
    @discussion The image is retrieved using the following sequence:
        1. cache
        2. filesystem
        3. download the image from self.imageUrl.
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
                
                // Cache the image in memory.
                self.cacheImage(image)
                
                completion(success: true, error: nil, image: image)
                return
            }
        }
        
        // Load the image from the server asynchronously on a background queue.
        if let url = self.imageUrl {
            self.dowloadImageFrom(url) { success, error, theImage in
                if success {
                    if let theImage = theImage {
                        self.cacheImageAndWriteToFile(theImage)
                    }
                    println("image downloaded from server")
                    completion(success: true, error: nil, image: theImage)
                    return
                } else {
                    // The download failed. Retry the download once.
                    self.dowloadImageFrom(url) { success, error, theImage in
                        if success {
                            if let theImage = theImage {
                                self.cacheImageAndWriteToFile(theImage)
                            }
                            println("image downloaded from server")
                            completion(success: true, error: nil, image: theImage)
                            return
                        } else {
                            let vtError = VTError(errorString: "Image download from Flickr service failed.", errorCode: VTError.ErrorCodes.FLICKR_FILE_DOWNLOAD_ERROR)
                            completion(success: false, error: vtError.error, image: nil)
                        }
                    }
                }
            }
        }
    }
    
    /*
    @brief Initialization helper: Create a Photo instance initialized to the contents of the imageMetadata parameter for every object in the imageMetadata dicstionary.
    @discussion Since Photo objects are NSManagedObjects they are persisted to Core Data. The Photo is associate with the view controller's current pin using the inverse relationship (by setting the photo's pin property to the VC's current pin).
    @param imageMetadata (in) - a dictionary containing multiple image metadata dictionaries. Each miage metadata dictionary contains an image title, id (used for local filename), and image url.
    @param forPin (in) - the Pin object to associate with the photo.
    */
    class func initPhotosFrom(imageMetadata: [[String: AnyObject?]]?, forPin: Pin?) {
        dispatch_async(dispatch_get_main_queue()) {
            
            // create a new Photo instance
            var dict = [String: AnyObject]()
            dict[Photo.InitKeys.pin] = forPin
            
            // set the image metaData obtained from the flickr api for this photo
            if let imageMetadata = imageMetadata {
                for metadataDictionary in imageMetadata {
                    // image url
                    if let url = metadataDictionary[Flickr.FlickrImageMetadataKeys.URL] as? String {
                        dict[Photo.InitKeys.imageUrl] = url
                    } else {
                        dict[Photo.InitKeys.imageUrl] = nil
                    }
                    
                    // image title
                    if let title = metadataDictionary[Flickr.FlickrImageMetadataKeys.TITLE] as? String {
                        dict[Photo.InitKeys.title] = title
                    } else {
                        dict[Photo.InitKeys.title] = nil
                    }
                    
                    // image's flickr ID
                    if let id = metadataDictionary[Flickr.FlickrImageMetadataKeys.ID] as? String {
                        dict[Photo.InitKeys.id] = id
                    } else {
                        dict[Photo.InitKeys.id] = nil
                    }
                    
                    // Add the Photo to the Core Data shared context
                    var photo = Photo(dictionary:dict, context: Photo.sharedContext)
                    
                    // Acquire the image data for this Photo object.
                    photo.getImage( { success, error, image in
                        if success {
                            println("successfully downloaded image \(photo.id): \(photo.title)")
                        } else {
                            println("error acquiring image \(photo.id): \(photo.title)")
                        }
                    })
                }
            }
            
            // Persist all the photos we added to the Core Data shared context
            CoreDataStackManager.sharedInstance().saveContext()
        }
    }
    
    /*
    @brief This method is called by Core Data when this Photo object is about to be deleted from Core Data. Here any data associated with the Photo object are removed from the cache and file system.
    */
    override func prepareForDeletion() {
        self.removeFromCache()
        self.deleteFileFromFileSystem()
    }
    
    /*
    @brief Remove this Photo object from Core data.
    @discussion If the photo contains a file containing image data on the filesystem that file is also deleted. Any cached image data associated with the photo is also deleted.
    @param bSaveContext (in) - true call saveContext on the Core Data shared instance. false is a noop.
    */
    func deletePhoto(bSaveContext: Bool) {
        
        // Note: Commented out below because cache and filesystem cleanup are now handled automatically in prepareForDeletion().
        // clean up data in filesystem and in cache
//        self.removeFromCache()
//        self.deleteFileFromFileSystem()
        
        // delete from Core Data
        Photo.sharedContext.deleteObject(self)
        if bSaveContext {
            CoreDataStackManager.sharedInstance().saveContext()
        }
    }
    
    
    // MARK: - Core Data
    
    /* core data managed object context */
    static var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }()
}

/* Image management helper functions */
extension Photo {
    
    /* Save the image to the local cache and file system. */
    func cacheImageAndWriteToFile(theImage: UIImage) {
        // save the image data to the file system
        if let id = self.id {
            let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
            dispatch_async(backgroundQueue, {
                self.saveImageToFileSystem(id, image: theImage)
            })
        }
        
        // save the image to the image cache in memory
        self.cacheImage(theImage)
    }
    
    /* Save the image data to the image cache in memory. */
    func cacheImage(theImage: UIImage) {
        if let url = self.imageUrl {
            let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
            dispatch_async(backgroundQueue, {
                NSCache.sharedInstance.setObject(theImage, forKey: url)
            })
        }
    }
    
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
    
    
    /* 
    @brief Delete the file in the Documents directory associated with this photo.
    @discussion Uses the id property as the base of the filename.
    */
    func deleteFileFromFileSystem() {
        if let id = self.id {
            let path = pathForImageFileWith(id)
            if let path = path {
                if NSFileManager.defaultManager().fileExistsAtPath(path) {
                    var error:NSErrorPointer = NSErrorPointer()
                    NSFileManager.defaultManager().removeItemAtPath(path, error: error)
                    println("deleted file at \(path)")
                    if error != nil {
                        println(error.debugDescription)
                    }
                }
            }
        }
    }
    
    /* Delete any cached image data associated with this Photo object. */
    func removeFromCache() {
        if let url = self.imageUrl {
            NSCache.sharedInstance.removeObjectForKey(url)
            println("removed \(url) from cache")
        }
    }
    
    /* Download the image identified by imageUrlString in a background thread, convert it to a UIImage object, and return the object. */
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
                    let vtError = VTError(errorString: "Cannot convert image data.", errorCode: VTError.ErrorCodes.IMAGE_CONVERSION_ERROR)
                    completion(success: false, error: vtError.error, image: nil)
                }
                
            } else {
                let vtError = VTError(errorString: "Image does not exist at \(imageURL)", errorCode: VTError.ErrorCodes.FILE_NOT_FOUND_ERROR)
                completion(success: false, error: vtError.error, image: nil)
            }
        })
    }
}

/* Allows Photo instances to be compared.*/
extension Photo: Equatable {}
func ==(lhs: Photo, rhs: Photo) -> Bool {
    return ( lhs.id == rhs.id )
}
