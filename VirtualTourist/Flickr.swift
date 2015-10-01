//
//  Flickr.swift
//  VirtualTourist
//
//  Created by john bateman on 9/21/15.
//  Copyright (c) 2015 John Bateman. All rights reserved.
//
// Acknowledgement: Based on code from the flickr project.

import Foundation
import UIKit

/* This protocol allows the flickr class to return the number of images to be downloaded immediately upon determining that value. */
protocol flickrDelegate {
    func numberOfPhotosToReturn(flickr: Flickr, count: Int)
}

class Flickr {
    
    /* Flickr REST api constants */
    struct Constants {
        static let BASE_URL: String = "https://api.flickr.com/services/rest/"
        static let METHOD_NAME: String = "flickr.photos.search"
        static let API_KEY: String = "fd2dca183606947b2f6c7ef036ae4e32"
        static let EXTRAS: String = "url_m"
        static let SAFE_SEARCH = "1"
        static let DATA_FORMAT: String = "json"
        static let NO_JSON_CALLBACK: String = "1"
    }
    
    /* Keys for the dictionary returned by the Flickr api. */
    struct FlickrDictionaryKeys {
        static let URL: String = "url_m"
        static let ID: String = "id"
        static let TITLE: String = "title"
    }
    
    /* Keys for dictionary returned by the searchFlickrForImageMetadataWith method. */
    struct FlickrImageMetadataKeys {
        static let URL: String = "url"
        static let ID: String = "id"
        static let TITLE: String = "title"
    }
    
    /* Implements the flickrDelegate protocol. The Flickr instance will report the count of images to download to the delegate.*/
    var delegate: flickrDelegate?
    
    /* The maximum number of images to return for a page of images */
    static let MAX_PHOTOS_TO_FETCH = 15
    
    /*!
    @brief Makes an https Get request using the Flickr api to search for an image
    @discussion The Function makes two requests to the Flickr api: the first request is to get a random page, the second request is to get an image belonging to the random page.
    @param methodArgumets (in) Contains parameters to be passed to the Flickr api as query string parameters.
    @param page (in) the page index of images to request
    @param completionHandler (in):
        success (out) true if call succeeded and image data was retrieved, else false if an error occurred.
        error (out) An NSError if an error occurred, else nil.
        arrayOfDictionaries (out) An Array of Dictionaries containing image metadata. Nil if an error occurred or no images were found. Use the Keys structure members to access the values stored in each dictionary in the returned array.
        nextPage
    @return void (out) The next page in the sequence of images for this gps location.
    */
    func searchFlickrForImageMetadataWith(methodArguments: [String : AnyObject], page: Int, completionHandler: (success: Bool, error: NSError?, arrayOfDictionaries: [[String: AnyObject?]]?, nextPage: Int) -> Void) {
        
        let session = NSURLSession.sharedSession()
        let urlString = Constants.BASE_URL + escapedParameters(methodArguments)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            if let error = downloadError {
                println("Could not complete the request \(error)")
            } else {
                
                var parsingError: NSError? = nil
                let parsedResult = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &parsingError) as! NSDictionary
                
                if let photosDictionary = parsedResult.valueForKey("photos") as? [String:AnyObject] {
                    
                    if let totalPages = photosDictionary["pages"] as? Int {
                        
                        // Flickr API - will only return up to 4000 images (100 per page * 40 page max)
                        let pageLimit = min(totalPages, 40)
                        
                        // Roll over page number when it exceeds the page limit identified by flickr for this search.
                        var pageNum = page
                        if pageNum > pageLimit {
                            pageNum = 1
                        }
                        
                        // generate a random page number in the limit
                        //let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
                        
                        // Search a particular page of results.
                        self.searchFlickrForImageMetadataByPageWith(methodArguments, pageNumber: pageNum) {
                            success, error, arrayOfDicts in
                            completionHandler(success: success, error: error, arrayOfDictionaries: arrayOfDicts, nextPage: ++pageNum)
                        }
                        
                    } else {
                        println("Cant find key 'pages' in \(photosDictionary)")
                        var error: NSError = NSError(domain: "Cant find key 'pages' in \(photosDictionary)", code: 905, userInfo: nil)
                        completionHandler(success: false, error: error, arrayOfDictionaries: nil, nextPage: page)
                    }
                } else {
                    println("Cant find key 'photos' in \(parsedResult)")
                    var error: NSError = NSError(domain: "Cant find key 'photos' in response to the Flickr api search request.", code: 906, userInfo: nil)
                    completionHandler(success: false, error: error, arrayOfDictionaries: nil, nextPage: page)
                }
            }
        }
        
        task.resume()
    }

    /*!
    @brief Makes an https Get request using the Flickr api to search for images give a specific page number.
    @param methodArgumets (in) Contains parameters to be passed to the Flickr api as query string parameters.
    @param pageNumber (in) The number of the page of image results to request from the Flickr service.
    @param completionHandler (in):
        success (out) true if call succeeded and image data was retrieved, else false if an error occurred.
        error (out) An NSError if an error occurred, else nil.
        arrayOfDicts (out) An Array of Dictionaries containing metadata for each image. Nil if an error occurred or if no image data was found.
    @return void
    */
    func searchFlickrForImageMetadataByPageWith(methodArguments: [String : AnyObject], pageNumber: Int, completionHandler: (success: Bool, error: NSError?, arrayOfDicts: [[String: AnyObject?]]?) -> Void) {
        
        /* Add the page to the method's arguments */
        var withPageDictionary = methodArguments
        withPageDictionary["page"] = pageNumber
        
        let session = NSURLSession.sharedSession()
        let urlString = Constants.BASE_URL + escapedParameters(withPageDictionary)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            if let error = downloadError {
                println("Could not complete the request \(error)")
                let error = NSError(domain: "request failed", code: 902, userInfo: nil)
                completionHandler(success: false, error: error, arrayOfDicts: nil)
            } else {
                var parsingError: NSError? = nil
                let parsedResult = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &parsingError) as! NSDictionary
                
                if let photosDictionary = parsedResult.valueForKey("photos") as? [String:AnyObject] {
                    
                    var totalPhotosVal = 0
                    if let totalPhotos = photosDictionary["total"] as? String {
                        totalPhotosVal = (totalPhotos as NSString).integerValue
                    }
                    
                    if totalPhotosVal > 0 {
                        if let photosArray = photosDictionary["photo"] as? [[String: AnyObject]] {
                            
                            var picturesToReturn = [UIImage]()
                            var dictionariesToReturn = [[String: AnyObject?]]()
                            
                            //let numPhotosToFetch = min(/*totalPhotosVal*/ photosArray.count, Flickr.MAX_PHOTOS_TO_FETCH)
                            let numPhotosToFetch = photosArray.count
                            
                            println("Flickr.getImageUrlsFromFlickrBySearchWithPage reports \(photosArray.count) photos found on page \(pageNumber).")
                            
                            // send delegate the number of photos that will be returned
                            if let delegate = self.delegate {
                                delegate.numberOfPhotosToReturn(self, count: numPhotosToFetch)
                            }
                            
                            for i in 0..<numPhotosToFetch {
                                let photoDictionary = photosArray[i] as [String: AnyObject]
                                
                                // for photoDictionary in photosArray {
                                
                                // get the metadata for this photo
                                let photoTitle = photoDictionary[FlickrDictionaryKeys.TITLE] as? String
                                let imageUrlString = photoDictionary[FlickrDictionaryKeys.URL] as? String
                                let id = photoDictionary[FlickrDictionaryKeys.ID] as? String
                                
                                // save metadata for this image in the array of image dictionaries
                                var imageMetadataDict = [String: AnyObject?]()
                                imageMetadataDict["title"] = photoTitle
                                imageMetadataDict["url"] = imageUrlString
                                imageMetadataDict["id"] = id
                                dictionariesToReturn.append(imageMetadataDict)
                            }
                            
                            completionHandler(success: true, error: nil, arrayOfDicts: dictionariesToReturn)
                        } else {
                            println("Cant find key 'photo' in \(photosDictionary)")
                            let error = NSError(domain: "Cant find key 'photo' in \(photosDictionary)", code: 903, userInfo: nil)
                            completionHandler(success: false, error: error, arrayOfDicts: nil)
                        }
                    } else {
                        // No photos found. Return an empty list.
                        completionHandler(success: true, error: nil, arrayOfDicts: nil)
                    }
                } else {
                    println("Cant find key 'photos' in \(parsedResult)")
                    
                    var error: NSError = NSError(domain: "Cant find key 'photos' in \(parsedResult)", code: 901, userInfo: nil)
                    completionHandler(success: false, error: error, arrayOfDicts: nil)
                }
            }
        }
        
        task.resume()
    }
    
    /* Helper function: Given a dictionary of parameters, convert to a string for a url */
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
            
        }
        
        return (!urlVars.isEmpty ? "?" : "") + join("&", urlVars)
    }

}

/* Flickr convenience extension. */
extension Flickr {
    
    static let BOUNDING_BOX_HALF_WIDTH = 1.0
    static let BOUNDING_BOX_HALF_HEIGHT = 1.0
    static let LAT_MIN = -90.0
    static let LAT_MAX = 90.0
    static let LON_MIN = -180.0
    static let LON_MAX = 180.0

    /*
    @brief Initializes the photo album (self.flickrPhotos) with the results of a flickr api image search by geo coordinates.
    @param completionHandler (in)
    success (out) true if flickr api search was successful, else false.
    error (out) nil if success == true, else contains an NSError.
    arrayOfDictionaries (out) An Array of Dictionaries containing image metadata. Nil if an error occurred or no images were found. Use the Keys structure members to access the values stored in each dictionary in the returned array.
    @return Void
    */
    func searchPhotosByLatLon2(pin: Pin, completionHandler: (success: Bool, error: NSError?, imageMetadata: [[String: AnyObject?]]?) -> Void) {
        
        //self.photoTitleLabel.text = "Searching..."
        let methodArguments = [
            "method": Flickr.Constants.METHOD_NAME,
            "api_key": Flickr.Constants.API_KEY,
            "bbox": createBoundingBoxString(pin.coordinate.latitude, longitude: pin.coordinate.longitude),
            "safe_search": Flickr.Constants.SAFE_SEARCH,
            "extras": Flickr.Constants.EXTRAS,
            "format": Flickr.Constants.DATA_FORMAT,
            "nojsoncallback": Flickr.Constants.NO_JSON_CALLBACK
        ]
        
        var flickrPage = pin.flickrPage
//        if let pageIndex = pin.flickrPage {
//            flickrPage = pageIndex
//        }
        
        self.searchFlickrForImageMetadataWith(methodArguments, page: flickrPage) {
            success, error, metaData, updatedPage in
            
//            if let pin = self.pin {
                pin.flickrPage = updatedPage  // TODO - ensure this can update the pin (it should since pin is a reference type object)
//            }
            
            if success == true {
                completionHandler(success: true, error: nil, imageMetadata: metaData)
            } else {
                completionHandler(success: false, error: error, imageMetadata: nil)
            }
        }
    }
    
    /* Ensure box is bounded by minimum and maximums */
    func createBoundingBoxString(latitude: Double, longitude: Double) -> String {
        
//        let latitude = pin?.coordinate.latitude
//        let longitude = pin?.coordinate.longitude
        
        let bottom_left_lon = max(longitude - Flickr.BOUNDING_BOX_HALF_WIDTH, Flickr.LON_MIN)
        let bottom_left_lat = max(latitude - Flickr.BOUNDING_BOX_HALF_HEIGHT, Flickr.LAT_MIN)
        let top_right_lon = min(longitude + Flickr.BOUNDING_BOX_HALF_HEIGHT, Flickr.LON_MAX)
        let top_right_lat = min(latitude + Flickr.BOUNDING_BOX_HALF_HEIGHT, Flickr.LAT_MAX)
        
        return "\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)"
    }
}