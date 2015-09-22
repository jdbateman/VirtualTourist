/*!
@header PhotoAlbumViewController.swift

VirtualTourist

The PhotoAlbumViewController class displays a MapView containing a single annotation (refered to as a pin), and a collection of images in a UICollectionView. The controller supports the following functionality:
- The controller dowloads images through the Flickr api based on the geo coordinates of the pin.
- The New Collection button deletes all existing images associated with a pin and downloads a new set of images from Flickr.
- Select an image to mark it for delete. This toggles the "New Collection" button to a "Remove Selected Pictures" button.
- Delete images by selecting the "Remove Selected Pictures" button. This toggles the "Remove Selected Pictures" button back to "New Collection".
- Select the Done button to change interaction back to AddPin mode.

@author John Bateman. Created on 9/19/15
@copyright Copyright (c) 2015 John Bateman. All rights reserved.
*/

import UIKit
import CoreData
import MapKit

class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate/*, NSFetchedResultsControllerDelegate*/ {

    let BOUNDING_BOX_HALF_WIDTH = 1.0
    let BOUNDING_BOX_HALF_HEIGHT = 1.0
    let LAT_MIN = -90.0
    let LAT_MAX = 90.0
    let LON_MIN = -180.0
    let LON_MAX = 180.0
    
//    let BASE_URL = "https://api.flickr.com/services/rest/"
//    let METHOD_NAME = "flickr.photos.search"
//    let API_KEY = "fd2dca183606947b2f6c7ef036ae4e32"
//    let EXTRAS = "url_m"
//    let SAFE_SEARCH = "1"
//    let DATA_FORMAT = "json"
//    let NO_JSON_CALLBACK = "1"
//    let BOUNDING_BOX_HALF_WIDTH = 1.0
//    let BOUNDING_BOX_HALF_HEIGHT = 1.0
//    let LAT_MIN = -90.0
//    let LAT_MAX = 90.0
//    let LON_MIN = -180.0
//    let LON_MAX = 180.0
    
    /* the map at the top of the view */
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    /* The pin to be displayed on the map. Should be set by the source view controller. */
    var pin:Pin?
    
    // The selected indexes array keeps all of the indexPaths for cells that are "selected". The array is
    // used inside cellForItemAtIndexPath to lower the alpha of selected cells.
    var selectedIndexes = [NSIndexPath]()
    
    // These arrays are used to track insertions, deletions, and updates to the collection view.
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!
    
    var flickrImage: UIImage?
    var flickrImages = [UIImage]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let pin = pin {
            showPinOnMap(pin)
        }
        
        // set the layout for the collection view
//        setCollectionViewLayout()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /* Lay out the collection view so that cells take up 1/3 of the width, no collection border, with no space in between each cell.
    Acknowledgement: Based on code from the ColorCollection example.
    */
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Lay out the collection view so that cells take up 1/3 of the width,
        // with no space in between.
        let layout : UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let width = floor(self.collectionView.frame.size.width/3)
        layout.itemSize = CGSize(width: width, height: width)
        collectionView.collectionViewLayout = layout
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    /* Display the specified pin on the MKMapView. This function sets the span. */
    func showPinOnMap(pin: Pin) {
        // Add the annotation to a local array of annotations.
        var annotations = [MKPointAnnotation]()
        annotations.append(pin.annotation)
        
        // Add the annotation(s) to the map.
        self.mapView.addAnnotations(annotations)
        
        // set the mapview span
        let span = MKCoordinateSpanMake(0.15, 0.15)
        self.mapView.region.span = span
        
        // Center the map on the coordinate(s).
        self.mapView.setCenterCoordinate(pin.coordinate, animated: true)
        
        // Tell the OS that the mapView needs to be refreshed.
        self.mapView.setNeedsDisplay()
        
        searchPhotosByLatLon()
    }
    
    
    // MARK: - UICollectionView
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1 // TODO - replace with fetchedResultsController
        //return self.fetchedResultsController.sections?.count ?? 0
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.flickrImages.count // TODO - replace with fetchedResultsController
//        let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
//        
//        println("number Of Cells: \(sectionInfo.numberOfObjects)")
//        return sectionInfo.numberOfObjects
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoAlbumCellID", forIndexPath: indexPath) as! PhotoAlbumCell
        
        self.configureCell(cell, atIndexPath: indexPath)
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoAlbumCell
        
        // Whenever a cell is tapped we will toggle its presence in the selectedIndexes array
        if let index = find(selectedIndexes, indexPath) {
            selectedIndexes.removeAtIndex(index)
        } else {
            selectedIndexes.append(indexPath)
        }
        
        // Then reconfigure the cell
        configureCell(cell, atIndexPath: indexPath)
        
        // And update the bottom button
        //TODO - use in future: updateBottomButton()
    }


    // MARK: helper functions
    
    /* Lay out the collection view so that cells take up 1/3 of the width, no collection border, with 5 pixels of space in between each cell.
    Acknowledgement: Based on code from the ColorCollection example.
    */
//    func setCollectionViewLayout() {
//        
//        let layout : UICollectionViewFlowLayout = UICollectionViewFlowLayout()
//        
//        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
//        layout.minimumLineSpacing = 0
//        layout.minimumInteritemSpacing = 0
//        
//        let width = floor(self.collectionView.frame.size.width/3)
//        layout.itemSize = CGSize(width: width, height: width)
//        collectionView.collectionViewLayout = layout
//    }
    

    
    // Configure Cell
    func configureCell(cell: PhotoAlbumCell, atIndexPath indexPath: NSIndexPath) {
        
        var image: UIImage? = self.flickrImages[indexPath.row]
        if let image = image {
            cell.imageView.image = image
        } else {
            cell.imageView.image = UIImage(named: "pluto.jpg")
        }
        
//        let color = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Color
//
//        cell.color = color.value
//
        // If the cell is "selected" it's color panel is grayed out
        // we use the Swift `find` function to see if the indexPath is in the array

        if let index = find(selectedIndexes, indexPath) {
            cell.imageView.alpha = 0.05
        } else {
            cell.imageView.alpha = 1.0
        }
    }
    
    
     func searchPhotosByLatLon() {
        
//        if !self.latitudeTextField.text.isEmpty && !self.longitudeTextField.text.isEmpty {
            if validLatitude(pin?.coordinate.latitude) && validLongitude(pin?.coordinate.longitude) {
                //self.photoTitleLabel.text = "Searching..."
                let methodArguments = [
                    "method": Flickr.Constants.METHOD_NAME,
                    "api_key": Flickr.Constants.API_KEY,
                    "bbox": createBoundingBoxString(),
                    "safe_search": Flickr.Constants.SAFE_SEARCH,
                    "extras": Flickr.Constants.EXTRAS,
                    "format": Flickr.Constants.DATA_FORMAT,
                    "nojsoncallback": Flickr.Constants.NO_JSON_CALLBACK
                ]
                Flickr.getImageFromFlickrBySearch(methodArguments) {
                    success, errorString, pictures in
                    
                    // save the picture
//                    if pictures.count > 0 {
//                        self.flickrImage = pictures[0]
//                    }
                    
                    // save the pictures to this view controller's collection
                    self.flickrImages = pictures
                    
                    // force the cells to update now that the image has been downloaded
                    dispatch_async(dispatch_get_main_queue()) {
                        self.collectionView.reloadData()
                    }
                }
            } else {
                println("invalid latitude or longitude")
//                if !validLatitude(self.pin?.coordinate.latitude) && !validLongitude(self.pin?.coordinate.longitude) {
//                    self.photoTitleLabel.text = "Lat/Lon Invalid.\nLat should be [-90, 90].\nLon should be [-180, 180]."
//                } else if !validLatitude(self.pin?.coordinate.latitude) {
//                    self.photoTitleLabel.text = "Lat Invalid.\nLat should be [-90, 90]."
//                } else {
//                    self.photoTitleLabel.text = "Lon Invalid.\nLon should be [-180, 180]."
//                }
            }
//        } else {
//            if self.latitudeTextField.text.isEmpty && self.longitudeTextField.text.isEmpty {
//                self.photoTitleLabel.text = "Lat/Lon Empty."
//            } else if self.latitudeTextField.text.isEmpty {
//                self.photoTitleLabel.text = "Lat Empty."
//            } else {
//                self.photoTitleLabel.text = "Lon Empty."
//            }
//        }
    }
    
/*
    /* Function makes first request to get a random page, then it makes a request to get an image with the random page */
    func getImageFromFlickrBySearch(methodArguments: [String : AnyObject]) {
        
        let session = NSURLSession.sharedSession()
        let urlString = BASE_URL + escapedParameters(methodArguments)
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
                        self.getImageFromFlickrBySearchWithPage(methodArguments, pageNumber: randomPage)
                        
                    } else {
                        println("Cant find key 'pages' in \(photosDictionary)")
                    }
                } else {
                    println("Cant find key 'photos' in \(parsedResult)")
                }
            }
        }
        
        task.resume()
    }
    
    func getImageFromFlickrBySearchWithPage(methodArguments: [String : AnyObject], pageNumber: Int) {
        
        /* Add the page to the method's arguments */
        var withPageDictionary = methodArguments
        withPageDictionary["page"] = pageNumber
        
        let session = NSURLSession.sharedSession()
        let urlString = BASE_URL + escapedParameters(withPageDictionary)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            if let error = downloadError {
                println("Could not complete the request \(error)")
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
                            
                            let randomPhotoIndex = Int(arc4random_uniform(UInt32(photosArray.count)))
                            let photoDictionary = photosArray[randomPhotoIndex] as [String: AnyObject]
                            
                            let photoTitle = photoDictionary["title"] as? String
                            let imageUrlString = photoDictionary["url_m"] as? String
                            let imageURL = NSURL(string: imageUrlString!)
                            
                            if let imageData = NSData(contentsOfURL: imageURL!) {
                                dispatch_async(dispatch_get_main_queue(), {
                                    //self.defaultLabel.alpha = 0.0
                                    self.flickrImage = UIImage(data: imageData)
                                    
                                    // force the cells to update now that the image has been downloaded
                                    dispatch_async(dispatch_get_main_queue()) {
                                        self.collectionView.reloadData()
                                    }
                                    
//                                    if methodArguments["bbox"] != nil {
//                                        self.photoTitleLabel.text = "\(self.getLatLonString()) \(photoTitle!)"
//                                    } else {
//                                        self.photoTitleLabel.text = "\(photoTitle!)"
//                                    }
                                    
                                })
                            } else {
                                println("Image does not exist at \(imageURL)")
                            }
                        } else {
                            println("Cant find key 'photo' in \(photosDictionary)")
                        }
                    } else {
                        dispatch_async(dispatch_get_main_queue(), { //TODO - what is with the comma?
                            println("No Photos Found.")
                            // TODO: Display a text string that indicates no images found.
//                            self.photoTitleLabel.text = "No Photos Found. Search Again."
//                            self.defaultLabel.alpha = 1.0
                            self.flickrImage = nil
                        })
                    }
                } else {
                    println("Cant find key 'photos' in \(parsedResult)")
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
*/
    /* Check to make sure the latitude falls within [-90, 90] */
    func validLatitude(lat: Double?) -> Bool {
        if let latitude : Double? = lat {
            if latitude < LAT_MIN || latitude > LAT_MAX {
                return false
            }
        } else {
            return false
        }
        return true
    }
    
    /* Check to make sure the longitude falls within [-180, 180] */
    func validLongitude(lon: Double?) -> Bool {
        if let longitude : Double? = lon {
            if longitude < LON_MIN || longitude > LON_MAX {
                return false
            }
        } else {
            return false
        }
        return true
    }
    
    func createBoundingBoxString() -> String {
        
        let latitude = pin?.coordinate.latitude
        let longitude = pin?.coordinate.longitude
        
        /* Fix added to ensure box is bounded by minimum and maximums */
        let bottom_left_lon = max(longitude! - BOUNDING_BOX_HALF_WIDTH, LON_MIN)
        let bottom_left_lat = max(latitude! - BOUNDING_BOX_HALF_HEIGHT, LAT_MIN)
        let top_right_lon = min(longitude! + BOUNDING_BOX_HALF_HEIGHT, LON_MAX)
        let top_right_lat = min(latitude! + BOUNDING_BOX_HALF_HEIGHT, LAT_MAX)
        
        return "\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)"
    }
}

extension String {
    func toDouble() -> Double? {
        return NSNumberFormatter().numberFromString(self)?.doubleValue
    }
}
