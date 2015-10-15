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
    static let MAX_PHOTOS_TO_FETCH = 24
    
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
    func searchFlickrForImageMetadataWith(methodArguments: [String : AnyObject], page: Int32, completionHandler: (success: Bool, error: NSError?, arrayOfDictionaries: [[String: AnyObject?]]?, nextPage: Int32) -> Void) {
        
        let session = NSURLSession.sharedSession()
        let urlString = Constants.BASE_URL + escapedParameters(methodArguments)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            if let error = downloadError {
                let vtError = VTError(errorString: "Could not complete http request to Flickr service. \(error)", errorCode: VTError.ErrorCodes.FLICKR_REQUEST_ERROR)
                completionHandler(success: false, error: vtError.error, arrayOfDictionaries: nil, nextPage: page)
            } else {
                var parsingError: NSError? = nil
                let parsedResult = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &parsingError) as! NSDictionary
                
                if let photosDictionary = parsedResult.valueForKey("photos") as? [String:AnyObject] {
                    
                    if let totalPages = photosDictionary["pages"] as? Int {
                        
                        // Flickr API - will only return up to 4000 images (100 per page * 40 page max)
                        let pageLimit = min(totalPages, 40)
                        
                        // Roll over page number when it exceeds the page limit identified by flickr for this search.
                        var pageNum: Int = Int(page)
                        if pageNum > pageLimit {
                            pageNum = 1
                        }
                        
                        // Search a particular page of results.
                        self.searchFlickrForImageMetadataByPageWith(methodArguments, pageNumber: pageNum) { success, error, arrayOfDicts in
                            completionHandler(success: success, error: error, arrayOfDictionaries: arrayOfDicts, nextPage: Int32(++pageNum))
                        }
                    } else {
                        let vtError = VTError(errorString: "Cant find key 'pages' in response to the Flickr api search request.", errorCode: VTError.ErrorCodes.JSON_PARSE_ERROR)
                        completionHandler(success: false, error: vtError.error, arrayOfDictionaries: nil, nextPage: page)
                    }
                } else {
                    let vtError = VTError(errorString: "Cant find key 'photos' in response to the Flickr api search request.", errorCode: VTError.ErrorCodes.JSON_PARSE_ERROR)
                    completionHandler(success: false, error: vtError.error, arrayOfDictionaries: nil, nextPage: page)
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
                let vtError = VTError(errorString: "Could not complete http request to Flickr service. \(error)", errorCode: VTError.ErrorCodes.FLICKR_REQUEST_ERROR)
                completionHandler(success: false, error: vtError.error, arrayOfDicts: nil)
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
                            
                            let numPhotosToFetch = min(/*totalPhotosVal*/ photosArray.count, Flickr.MAX_PHOTOS_TO_FETCH)
                            // TODO: reenable: 
                            // let numPhotosToFetch = photosArray.count
                            
                            println("Flickr.searchFlickrForImageMetadataByPageWith reports \(photosArray.count) photos found on page \(pageNumber).")
                            
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
                            let vtError = VTError(errorString: "Cant find key 'photo' in response to the Flickr api search request.", errorCode: VTError.ErrorCodes.JSON_PARSE_ERROR)
                            completionHandler(success: false, error: vtError.error, arrayOfDicts: nil)
                        }
                    } else {
                        // No photos found. Return an empty list.
                        completionHandler(success: true, error: nil, arrayOfDicts: nil)
                    }
                } else {
                    let vtError = VTError(errorString: "Cant find key 'photos' in response to the Flickr api search request.", errorCode: VTError.ErrorCodes.JSON_PARSE_ERROR)
                    completionHandler(success: false, error: vtError.error, arrayOfDicts: nil)
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

/* Flickr api convenience method and supporting helper functions. */
extension Flickr {
    
    static let BOUNDING_BOX_HALF_WIDTH = 0.5
    static let BOUNDING_BOX_HALF_HEIGHT = 0.5
    static let LATITUDE_MIN = -90.0
    static let LATITUDE_MAX = 90.0
    static let LONGITUDE_MIN = -180.0
    static let LONGITUDE_MAX = 180.0

    /*
    @brief Query the flickr api for images associated with the specified 2D coordinates.
    @param completionHandler (in)
    success (out) true if flickr api search was successful, else false.
    error (out) nil if success == true, else contains an NSError.
    arrayOfDictionaries (out) An Array of Dictionaries containing image metadata. Nil if an error occurred or no images were found. Use the Keys structure members to access the values stored in each dictionary in the returned array.
    @return Void
    */
    func searchPhotosBy2DCoordinates(pin: Pin,
        completionHandler: (success: Bool, error: NSError?, imageMetadata: [[String: AnyObject?]]?) -> Void) {
        
        //self.photoTitleLabel.text = "Searching..."
        let methodArguments = [
            "method": Flickr.Constants.METHOD_NAME,
            "api_key": Flickr.Constants.API_KEY,

            /* geo (or bounding box) queries will only return 250 results per page. */
            "bbox": getBoundingBox(pin.coordinate.latitude, longitude: pin.coordinate.longitude),
    
            "safe_search": Flickr.Constants.SAFE_SEARCH,
            "extras": Flickr.Constants.EXTRAS,
            "format": Flickr.Constants.DATA_FORMAT,
            "nojsoncallback": Flickr.Constants.NO_JSON_CALLBACK
        ]
        
        var flickrPage = pin.flickrPage
        
        self.searchFlickrForImageMetadataWith(methodArguments, page: flickrPage.intValue) {
            success, error, metaData, nextPage in
            
            // Update the page number to request for this coordinate when the next flickr request is made.
            dispatch_async(dispatch_get_main_queue()) {
                pin.flickrPage = NSNumber(int: nextPage)
            }
            
            if success == true {
                completionHandler(success: true, error: nil, imageMetadata: metaData)
            } else {
                completionHandler(success: false, error: error, imageMetadata: nil)
            }
        }
    }
    
    /* Return a string defining two points of a box which bounds the specified coordinate.*/
    func getBoundingBox(latitude: Double, longitude: Double) -> String {
        let bottomLeftLongitude = max(longitude - Flickr.BOUNDING_BOX_HALF_WIDTH, Flickr.LONGITUDE_MIN)
        let bottomLeftLatitude = max(latitude - Flickr.BOUNDING_BOX_HALF_HEIGHT, Flickr.LATITUDE_MIN)
        let topRightLongitude = min(longitude + Flickr.BOUNDING_BOX_HALF_HEIGHT, Flickr.LONGITUDE_MAX)
        let topRightLatitude = min(latitude + Flickr.BOUNDING_BOX_HALF_HEIGHT, Flickr.LATITUDE_MAX)
        
        return "\(bottomLeftLongitude),\(bottomLeftLatitude),\(topRightLongitude),\(topRightLatitude)"
    }
}