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

// TODO: NSFetchedResultsControllerDelegate
// TODO: placeholder images for cells in configureCell2
// TODO: keep a counter in Flickr class (or caller) to the flickr search method instead of returning a random page
// TODO: add metadata from flickr to Photo class to support sort descriptors in NSFetchedResultsController searches



import UIKit
import CoreData
import MapKit

class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, flickrDelegate, NSFetchedResultsControllerDelegate {

    var activityIndicator : UIActivityIndicatorView = UIActivityIndicatorView(frame: CGRectMake(0, 0, 50, 50)) as UIActivityIndicatorView

    let BOUNDING_BOX_HALF_WIDTH = 1.0
    let BOUNDING_BOX_HALF_HEIGHT = 1.0
    let LAT_MIN = -90.0
    let LAT_MAX = 90.0
    let LON_MIN = -180.0
    let LON_MAX = 180.0
    
    private let sectionInsets = UIEdgeInsets(top: 5.0, left: 5.0, bottom: 5.0, right: 5.0)
    
    /* the map at the top of the view */
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var noImagesLabel: UILabel!
    
    var newCollectionButton: UIBarButtonItem? = nil
    
    let flickr = Flickr()
    
    /* The pin to be displayed on the map. Should be set by the source view controller. */
    var pin:Pin?
    
    // The selected indexes array keeps all of the indexPaths for cells that are "selected". The array is
    // used inside cellForItemAtIndexPath to lower the alpha of selected cells.
    var selectedIndexes = [NSIndexPath]()
    
    // These arrays are used to track insertions, deletions, and updates to the collection view.
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!
    
    //var flickrImage: UIImage?
    //var flickrImages = [UIImage]()
    var flickrPhotos = [Photo]()
    // TODO flickrPhotos keeps growing every time I do a search
    // TODO photos are no longer filling in after deletes
    
    // TODO - load placeholder images for each cell why images are downloading. determine how many images to load.
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize the fetchResultsController from the core data store.
        fetchPhotos()

        // set the UICollectionView data source and delegate
        self.collectionView.dataSource = self
        self.collectionView.delegate = self
        
        // set the Flickr delegate
        flickr.delegate = self
        
        // set the NSFetchedResultsControllerDelegate
        fetchedResultsController.delegate = self
        
        if let pin = pin {
            showPinOnMap(pin)
        }
        
        // configure the toolbar items
        let flexButtonLeft = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
        newCollectionButton = UIBarButtonItem(title: "New Collection", style: .Plain, target: self, action: "onNewCollectionButtonTap")
        let flexButtonRight = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
        self.setToolbarItems([flexButtonLeft, newCollectionButton!, flexButtonRight], animated: true)

        // enable display of the navigation controller's toolbar
        self.navigationController?.setToolbarHidden(false, animated: true)
        
        // Initialize flickrPhotos from the view controller's current pin.photos.
        if let pin = pin {
            flickrPhotos = pin.photos
            
            // TODO - need to replace above line with a fetchRequest for all Photos associated with this pin.
            
            // enable the New Collection button
            newCollectionButton!.enabled = true
        }
        
        // Initialize flickrPhotos from flickr if the current pin did not contain any photos.
        if flickrPhotos.count == 0 {
            initializePhotos()
        }
        
        // set the layout for the collection view - TODO: figure out how to get spaces between cells
//        setCollectionViewLayout()
    }
    
    override func viewDidDisappear(animated: Bool) {
        fetchedResultsController.delegate = nil
    }
    
    /* Initialize photos... TODO - update description */
    func initializePhotos() {
        self.startActivityIndicator()
        
        // disable the New Collection button until the images are downloaded from flickr.
        newCollectionButton!.enabled = false
        
        // TODO - need to pull new images from flickr and store in this VC's collection and persist to core data for the current pin.
        // That function needs to be changed to return after the fetch so that we can execute the rest of this function.
        searchPhotosByLatLon2() {
            success, error, pictures in
            if success == true {
                // Persist each photo returned by the search as a new Photo instance, save it in the VC's flickrPhotos collection, & associate it with the view controller's current pin using the inverse relationship (by setting the photo's pin property to the VC's current pin).
//                for image in pictures {
//                    self.saveImageAsPhoto(image)
//                }
//                CoreDataStackManager.sharedInstance().saveContext()
                self.saveImagesAsPhotos(pictures)
                
                // Now that all the images have been saved to the context, update the fetchedResultsController from core data.
//                dispatch_async(dispatch_get_main_queue()) {
//                    self.fetchPhotos()
//                }
                
                // halt the activity indicator
                self.stopActivityIndicator()
                
                // enable the New Collection button.
                self.newCollectionButton!.enabled = true
                
                // force the cells to update now that the images have been downloaded
                dispatch_async(dispatch_get_main_queue()) { // TODO: sometimes on the main thread, sometimes not. How to handle?
                    
                    // TODO - why the delay in enabling the newCollectionButton? Which of the following calls is prefered to trigger a redraw?
//                    self.view.setNeedsLayout()
//                    self.view.setNeedsDisplay()
                    
                    // TODO: try resetting the delegates before calling reloadData to get the data source to update it's count properly
//                    self.collectionView.dataSource = self
//                    self.collectionView.delegate = self
                    
                    //self.view.setNeedsDisplay()
                    self.collectionView.reloadData() // TODO - tried disabling. no effect.
                }
            } else {
                // halt the activity indicator
                self.stopActivityIndicator()
                
                // TODO - report error to user
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /* Lay out the collection view so that cells take up 1/3 of the width, no collection border, with no space in between each cell.
    Acknowledgement: Based on code from the ColorCollection example.
    */
//    override func viewDidLayoutSubviews() {
//        super.viewDidLayoutSubviews()
//        
//        // Lay out the collection view so that cells take up 1/3 of the width,
//        // with no space in between.
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

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: buttons
    
    func onNewCollectionButtonTap() {
        println("New Collection button selected.")
        
        // empty the photo album - TODO: remove this line
        //self.flickrImages.removeAll(keepCapacity: true)
        self.flickrPhotos.removeAll(keepCapacity: true) // TODO - remove.
        
        // remove all photos associated with this pin in core data store
        if let pin = pin {
            for photo in pin.photos {
                deletePhoto(photo)
            }
            
            // Now that all the pin's photos have been deleted, update the fetchedResultsController by refetching the Photos.
//            dispatch_async(dispatch_get_main_queue()) { // TODO - called on main already?
//                self.fetchPhotos()
//            }
        }
        
        // TODO: instead of iterating all Photo objects in the pin, aren't they already stored by the NSFetchedResultsController? Can we just use the NSFetchedResultsController to nuke all of them in one call?
        
        // fetch a new set of images
        //searchPhotosByLatLon()
        initializePhotos()
        
        // disable the New Collection button.
        //newCollectionButton!.enabled = false
    }
    
    
    // MARK: UICollectionViewDataSource protocol
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return self.fetchedResultsController.sections?.count ?? 0
        
        //return 1 // TODO - replace with fetchedResultsController
        //return self.fetchedResultsController.sections?.count ?? 0
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        println("numberOfItemsInSection reports number of Photos = \(sectionInfo.numberOfObjects) in section \(section)")
        let count = sectionInfo.numberOfObjects
        //let count =  self.flickrPhotos.count  // TODO - remove: self.flickrImages.count
        
        if count > 0 {
            self.noImagesLabel.hidden = true
            self.collectionView.hidden = false
        } else {
            self.noImagesLabel.hidden = false
            self.collectionView.hidden = true
        }
        
        return count
        
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
    
    // MARK: UICollectionViewDelegate protocol
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        // remove the image from the VC's collection - TODO: remove this line
        //self.flickrImages.removeAtIndex(indexPath.row)
        
//        // remove the Photo object from the core data store.
//        deletePhoto(self.flickrPhotos[indexPath.row])
//        
//        // remove the Photo from the VC's collection
//        self.flickrPhotos.removeAtIndex(indexPath.row)
        
        // remove the Photo object from the core data store.
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        sharedContext.deleteObject(photo)
        CoreDataStackManager.sharedInstance().saveContext()
        
        // update the fetchedResultsController with the new data in core data.
        //fetchPhotos() // TODO - reenable to support NSFetchedResultsControllerDelegate?
        
        // force the cells to update now that the image has been downloaded
        //dispatch_async(dispatch_get_main_queue()) { // TODO - already on the main thread here so don't need dispatch_async
            self.collectionView.reloadData()
        //}
    }

    
    // MARK: - Core Data
    
    /* core data managed object context */
    lazy var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }()
    
    
    /* 
    @brief Persist a new Photo instance of the specified UIImage.
    @discussion This function sets the Photo's inverse relationship to it's Pin, and saves the new Photo to the view controller's flickrPhotos collection.
    */
    func saveImageAsPhoto(image: UIImage?) {
        
//        dispatch_async(dispatch_get_main_queue()) {
            
            if let image = image {
                
                // create a new Photo instance
                var dict = [String: AnyObject]()
                dict[Photo.keys.imageData] = UIImageJPEGRepresentation(image, 1)
                if self.pin == nil {
                    println("******** PhotoAlbumViewController pin is nil! ********")
                }
                dict[Photo.keys.pin] = self.pin
                
                dispatch_async(dispatch_get_main_queue()) {
                    var photo = Photo(dictionary:dict, context: self.sharedContext) // TODO: on background thread here!
                }
                
                // save the Photo to the View controller's collection of Photo objects
                //self.flickrPhotos.append(photo) // TODO: convert to NSFetchedResultsController
                
                println("saveImageAsPhoto about to call CoreDataStackManager.sharedInstance().saveContext()")
                
                // save the core data context
                //CoreDataStackManager.sharedInstance().saveContext() // being called on the main thread. Moved to end of for loop that calls saveImageAsPhoto for each downloaded image.
                println("saveImageAsPhoto called CoreDataStackManager.sharedInstance().saveContext()")
            }
//        }
    }
    
    /* 
    @brief Persist each image in images as a Photo object in Core Data.
    @discussion This function sets the Photo's inverse relationship to it's Pin, and saves the new Photo to the view controller's flickrPhotos collection.
    */
    func saveImagesAsPhotos(images: [UIImage]) {
        dispatch_async(dispatch_get_main_queue()) {
            
            // TODO: Test creating a new pin instance with the same coordinates.
//            if let pin = self.pin {
//                var dict = [String: AnyObject]()
//                dict[Pin.Keys.latitude] = self.pin!.latitude
//                dict[Pin.Keys.longitude] = self.pin!.longitude
//                self.pin = Pin(dictionary: dict, context: self.sharedContext)
//                println("(\(self.pin!.latitude), \(self.pin!.longitude))")
//            }
            
            for image in images {
//                let data: NSData? = UIImageJPEGRepresentation(image, 1)
//                if data == nil {
//                    println("image data is nil")
//                }
                // create a new Photo instance
                var dict = [String: AnyObject]()
                dict[Photo.keys.imageData] = UIImageJPEGRepresentation(image, 1)
                dict[Photo.keys.pin] = self.pin

                var photo = Photo(dictionary:dict, context: self.sharedContext)
            }
            CoreDataStackManager.sharedInstance().saveContext()
        }
    }
    
    // TODO - replace flickrPhotos with NSFetchedResultsController
    
    /* Remove the Photo object from the Core data store */
    func deletePhoto(photo: Photo) {
        self.sharedContext.deleteObject(photo)
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    
    // MARK: - Fetched results controller
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        // Create the fetch request
        let fetchRequest = NSFetchRequest(entityName: Photo.entityName) // TODO: check that this should not be Pin.entityName.
        
        // Add a sort descriptor to enforce a sort order on the results.
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "pin", ascending: false)] // TODO: does this work? can you sort on any class?
//        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "imageData" /*Photo.keys.imageData*/, ascending: false)] // TODO - causes exception on saveContext!
        // TODO: store some other metadata about a Photo in it's properties and sort based on one of those properties here. E.g. title.
        
        if let pin = self.pin {
            fetchRequest.predicate = NSPredicate(format: "pin == %@", pin)
        } else {
            assert(self.pin != nil, "self.pin == nil in PhotoAlbumViewController") // TODO
        }
        
//        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: false), NSSortDescriptor(key: "longitude", ascending: false)]
        
        // Create the Fetched Results Controller
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext:
            self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        
        // Return the fetched results controller. It will be the value of the lazy variable
        return fetchedResultsController
        } ()
    
    /* Perform a fetch of Photo objects to update the fetchedResultsController with the current data from the core data store. */
    func fetchPhotos() {
        var error: NSError? = nil
        
        fetchedResultsController.performFetch(&error)
        
        println("fetchPhotos was called ")
        
        if let error = error {
            println("Unresolved error in fetchedResultsController.performFetch \(error), \(error.userInfo)")
            // TODO: Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate.
            abort()
        }
    }
    
    
    // MARK: NSFetchedResultsControllerDelegate
    
    // Any change to Core Data causes these delegate methods to be called.
    
    // Initialize arrays of index paths which identify objects that will need to be changed.
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        println("start controllerWillChangeContent")
        
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()
        
        println("end controllerWillChangeContent")
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        // Our project does not use sections. So we can ignore these invocations.
        println("in didChangeSection")
    }
    
    // Save the index path of each object that is added, deleted, or updated as the change is identified by Core Data.
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        switch type{
            
        case .Insert:
            println("Insert an item")
            // A new Photo has been added to Core Data. Save the "newIndexPath" parameter so the cell can be added later.
            insertedIndexPaths.append(newIndexPath!)
            break
        case .Delete:
            println("Delete an item")
            // A Photo has been deleted from Core Data. Save the "indexPath" parameter so the corresponding cell can be removed later.
            deletedIndexPaths.append(indexPath!)
            break
        case .Update:
            println("Update an item.")
            // A change was made to an existing object in Core Data.
            // (For example, when an images is downloaded from Flickr in the Virtual Tourist app)
            updatedIndexPaths.append(indexPath!)
            break
        case .Move:
            println("Move an item. Not implemnted in this app.")
            break
        default:
            break
        }
    }
    
    // Do an update of all changes in the current batch.
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        println("in controllerDidChangeContent. changes.count: \(insertedIndexPaths.count + deletedIndexPaths.count + updatedIndexPaths.count)")
        
        collectionView.performBatchUpdates({() -> Void in
            
            // added
            for indexPath in self.insertedIndexPaths {
                self.collectionView.insertItemsAtIndexPaths([indexPath])
                println("inserted items")
            }
            
            // deleted
            for indexPath in self.deletedIndexPaths {
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
                println("deleted items")
            }
            
            // updated
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItemsAtIndexPaths([indexPath])
                println("reloaded items")
            }
            
            }, completion: nil)
    }

    
    
    // MARK: helper functions
    
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
        self.mapView.setCenterCoordinate(pin.coordinate, animated: false)
        
        // Tell the OS that the mapView needs to be refreshed.
        self.mapView.setNeedsDisplay()
    }
    
    /* show activity indicator */
    func startActivityIndicator() {
        activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.WhiteLarge
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        
//        println("startActivityIndicator()")
    }
    
    /* hide acitivity indicator */
    func stopActivityIndicator() {
        dispatch_async(dispatch_get_main_queue()) {
            self.activityIndicator.stopAnimating()
        }
        
//        println("stopActivityIndicator()")
    }
    
    /* Set cell image to Photo.image. If no image exists yet do nothing. */
    func configureCell(cell: PhotoAlbumCell, atIndexPath indexPath: NSIndexPath) {
        
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        var image: UIImage? = photo.image
        
        //var image: UIImage? = self.flickrImages[indexPath.row] // TODO - remove
//        var image: UIImage? = (self.flickrPhotos[indexPath.row] as Photo).image
        // TODO: convert to NSFetchedResultsController
        
        if let image = image {
            cell.imageView.image = image
        }
//        else {
//            cell.imageView.image = UIImage(named: "pluto.jpg")
//        }
    }
    
    /* Set cell image to the placeholder image. If no image is identified in the Photo object download the image from Flickr. */
    func configureCell2(cell: PhotoAlbumCell, atIndexPath indexPath: NSIndexPath) {
        
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        // set placeholder image
        cell.imageView.image = UIImage(named: "placeholder.jpg") //TODO get rid of placeholder-photo.jpg
        //TODO - remove cell.setPictureForCell(picture)
        
        if photo.image == nil {
            // download image
            println("photo.image == nil")
        }
    }
    
    // TODO: may no longer need this function:
    /* Delete Photo object associated with the selected cell. */
//    func deleteCell(cell: PhotoAlbumCell, atIndexPath indexPath: NSIndexPath) {
//        
//        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
//        sharedContext.deleteObject(photo)
//        CoreDataStackManager.sharedInstance().saveContext()
//    }
    
    /*
    @brief Initializes the photo album (self.flickrPhotos) with the results of a flickr api image search by geo coordinates.
    @param completionHandler (in)
    success (out) true if flickr api search was successful, else false.
    error (out) nil if success == true, else contains an NSError.
    pictures (out) an array of UIImage objects, else empty array if an error occurred. (Note: a successful search can return an empty list.)
    @return Void
    */
    func searchPhotosByLatLon2(completionHandler: (success: Bool, error: NSError?, pictures: [UIImage]) -> Void) {
        
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
            
            //startActivityIndicator() // TODO - move this to caller
            
            flickr.getImageFromFlickrBySearch(methodArguments) {
                success, error, pictures in
                
                if success == true {
                    completionHandler(success: true, error: nil, pictures: pictures)
                } else {
                    completionHandler(success: false, error: error, pictures: [] as [UIImage])
                }
            }
        } else {
            println("invalid latitude or longitude")
            let error = NSError(domain: "invalid latitude or longitude", code: 907, userInfo: nil)
            completionHandler(success: true, error: error, pictures: [] as [UIImage])
        }
    }
    
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

/* Set the layout of the UICollectionView cells. */
extension PhotoAlbumViewController : UICollectionViewDelegateFlowLayout {
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
            
//        let flickrPhoto =  photoForIndexPath(indexPath)
//        if var size = flickrPhoto.thumbnail?.size {
//            size.width += 10
//            size.height += 10
//            return size
//        }
        
        // calculate the cell size
        let nCells = 4
        let nSpaces = nCells - 1
        //let widthSpaces = nSpaces * (sectionInsets.left + sectionInsets.right) + sectionInsets.left + sectionInsets.right
        let widthSpaces: CGFloat = (4 * sectionInsets.left) + (4 * sectionInsets.right)
        let cellWidth = (collectionView.frame.size.width -  widthSpaces ) / 4
//        println("cellWidth = \(cellWidth)")
        return CGSize(width: cellWidth, height: cellWidth)
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        return sectionInsets
    }

    // TODO - delete
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
}

/* Implement placeholder images to occupy cells while the final image is downloaded from Flickr. */
extension PhotoAlbumViewController : flickrDelegate {
    
    // Flickr reports the number of images that will be downloaded. Use this information to create placeholder images for each cell.
    func numberOfPhotosToReturn(flickr: Flickr, count: Int) {
        println("flickrDelegate protocol reports \(count) images will be downloaded.")
        
        // Create a Photo object for each url_m returned from the flickr instance and give each a default image.
        
        // Later when the actual images are returned match them by url_m with the placeholder objects and update the placeholder object instead of creating a new Photo object. This means returning url_m with the UIImage data. Perhaps I should just return url_m instead of UIImage data, and download the UIImage data from this class.
    }
}


// let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoAlbumCell
//        // Whenever a cell is tapped we will toggle its presence in the selectedIndexes array
//        if let index = find(selectedIndexes, indexPath) {
//            selectedIndexes.removeAtIndex(index)
//        } else {
//            selectedIndexes.append(indexPath)
//        }
//
//        // Then reconfigure the cell
//        configureCell(cell, atIndexPath: indexPath)
//
//        // And update the bottom button
//        //TODO - use in future: updateBottomButton()