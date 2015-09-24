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

/* This protocol allos the flickr class to return the number of images to be downloaded to the delegate prior to starting the download. */
protocol flickrDelegate {
    func numberOfPhotosToReturn(flickr: Flickr, count: Int)
}

class Flickr {
    
    struct Constants {
        static let BASE_URL: String = "https://api.flickr.com/services/rest/"
        static let METHOD_NAME: String = "flickr.photos.search"
        static let API_KEY: String = "fd2dca183606947b2f6c7ef036ae4e32"
        static let EXTRAS: String = "url_m"
        static let SAFE_SEARCH = "1"
        static let DATA_FORMAT: String = "json"
        static let NO_JSON_CALLBACK: String = "1"
    }
    
    /* Implements the flickrDelegate protocol. The Flickr instance will report the count of images to download to the delegate.*/
    var delegate: flickrDelegate?
    
    /* The maximum number of images to return for a page of images */
    static let MAX_PHOTOS_TO_FETCH = 15
    
    /*!
    @brief Makes an https Get request using the Flickr api to search for an image
    @discussion The Function makes two requests to the Flickr api: the first request is to get a random page, the second request is to get an image belonging to the random page.
    @param methodArgumets (in) Contains parameters to be passed to the Flickr api as query string parameters.
    @param completionHandler (in):
        success (out) true if call succeeded and image data was retrieved, else false if an error occurred.
        error (out) An NSError if an error occurred, else nil.
        pictures (out) An Array of UIImage objects if 1 or more images were found, else contains an empty array.
    @return void
    */
    func getImageFromFlickrBySearch(methodArguments: [String : AnyObject], completionHandler: (success: Bool, error: NSError?, pictures: [UIImage]) -> Void) {
        
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
                        
                        /* Flickr API - will only return up the 4000 images (100 per page * 40 page max) */
                        let pageLimit = min(totalPages, 40)
                        let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
                        self.getImageFromFlickrBySearchWithPage(methodArguments, pageNumber: randomPage) {
                            success, error, pictures in
                            completionHandler(success: success, error: error, pictures: pictures)
                        }
                        
                    } else {
                        println("Cant find key 'pages' in \(photosDictionary)")
                        var error: NSError = NSError(domain: "Cant find key 'pages' in \(photosDictionary)", code: 905, userInfo: nil)
                        completionHandler(success: false, error: error, pictures: [] as [UIImage])
                    }
                } else {
                    println("Cant find key 'photos' in \(parsedResult)")
                    var error: NSError = NSError(domain: "Cant find key 'photos' in response to the Flickr api search request.", code: 906, userInfo: nil)
                    completionHandler(success: false, error: error, pictures: [] as [UIImage])
                }
            }
        }
        
        task.resume()
    }
    
    /*!
    @brief Makes an https Get request using the Flickr api to search for an image by page number.
    @param methodArgumets (in) Contains parameters to be passed to the Flickr api as query string parameters.
    @param pageNumber (in) The number of the page of image results to request from the Flickr service.
    @param completionHandler (in):
        success (out) true if call succeeded and image data was retrieved, else false if an error occurred.
        error (out) An NSError if an error occurred, else nil.
        pictures (out) An Array of UIImage objects if 1 or more images were found, else contains an empty array.
    @return void
    */
    func getImageFromFlickrBySearchWithPage(methodArguments: [String : AnyObject], pageNumber: Int, completionHandler: (success: Bool, error: NSError?, pictures: [UIImage]) -> Void) {
        
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
                completionHandler(success: false, error: error, pictures: [] as [UIImage])
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
                            
//                            let randomPhotoIndex = Int(arc4random_uniform(UInt32(photosArray.count)))
//                            let photoDictionary = photosArray[randomPhotoIndex] as [String: AnyObject]
                            
                            var picturesToReturn = [UIImage]()
                            
                            let numPhotosToFetch = min(/*totalPhotosVal*/ photosArray.count, Flickr.MAX_PHOTOS_TO_FETCH)
                            
                            // send delegate the number of photos that will be returned
                            if let delegate = self.delegate {
                                delegate.numberOfPhotosToReturn(self, count: numPhotosToFetch)
                                
                                // return array of url_m values to delegate along with the count.
                            }
                            
                            for i in 0..<numPhotosToFetch {
//                            for var i = 0; i<numPhotosToFetch; i++ {
                                let photoDictionary = photosArray[i] as [String: AnyObject]
                                
                            // for photoDictionary in photosArray {
                            
                                // get the metadata for this photo
                                let photoTitle = photoDictionary["title"] as? String
                                let imageUrlString = photoDictionary["url_m"] as? String
                                let id = photoDictionary["id"] as? String
                                
                                // TODO - now that we have the metadata could a Photo object be created and returned that contains all the metadata?
                                
                                // get the binary image data
                                let imageURL = NSURL(string: imageUrlString!)
                                if let imageData = NSData(contentsOfURL: imageURL!) {
//                                    dispatch_async(dispatch_get_main_queue(), {
    //                                    //self.defaultLabel.alpha = 0.0
    //                                    self.flickrImage = UIImage(data: imageData)
                                        
                                        // force the cells to update now that the image has been downloaded
    //                                    dispatch_async(dispatch_get_main_queue()) {
    //                                        self.collectionView.reloadData() // TODO - move to view controller
    //                                    }
                                        
                                        //                                    if methodArguments["bbox"] != nil {
                                        //                                        self.photoTitleLabel.text = "\(self.getLatLonString()) \(photoTitle!)"
                                        //                                    } else {
                                        //                                        self.photoTitleLabel.text = "\(photoTitle!)"
                                        //                                    }
                                    
                                    
                                        // Convert the image data to a UIImage object and append to the array to be returned.
                                        if let image = UIImage(data: imageData) {
                                            picturesToReturn.append(image)
                                            //completionHandler(success: true, error: nil, pictures: [image])
                                        }
//                                        else {
//                                            let error = NSError(domain: "cannot convert image data", code: 904, userInfo: nil)
//                                            completionHandler(success: false, error: error, pictures: [] as [UIImage])
//                                        }
//                                    })
                                } else {
                                    println("Image does not exist at \(imageURL)")
                                    let error = NSError(domain: "Image does not exist at \(imageURL)", code: 904, userInfo: nil)
                                    completionHandler(success: false, error: error, pictures: [] as [UIImage])
                                }
                            }
                            
                            completionHandler(success: true, error: nil, pictures: picturesToReturn)
                        } else {
                            println("Cant find key 'photo' in \(photosDictionary)")
                            let error = NSError(domain: "Cant find key 'photo' in \(photosDictionary)", code: 903, userInfo: nil)
                            completionHandler(success: false, error: error, pictures: [] as [UIImage])
                        }
                    } else {
                        // No photos found. Return an empty list.
                        completionHandler(success: true, error: nil, pictures: [] as [UIImage])
                        
//                        dispatch_async(dispatch_get_main_queue(), { //TODO - what is with the comma?
//                            println("No Photos Found.")
//                            // TODO: Display a text string that indicates no images found.
//                            //                            self.photoTitleLabel.text = "No Photos Found. Search Again."
//                            //                            self.defaultLabel.alpha = 1.0
////                            self.flickrImage = nil
//                            
//
//                        })
                    }
                } else {
                    println("Cant find key 'photos' in \(parsedResult)")
                    
                    var error: NSError = NSError(domain: "Cant find key 'photos' in \(parsedResult)", code: 901, userInfo: nil)
                    completionHandler(success: false, error: error, pictures: [] as [UIImage])
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