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

// TODO: properly define NSError strings as in CoreDataStackManager.swift. Update NSError objects in the app.
// Question: Why does the New Collection button take so long to enable?
// Question: suggestion for how to optimize management/download of photos during scrolling? - what if i quickly scroll halfway down the list
// Question: is there a way to use the fetched results controller to delete all Photo objects for a pin, instead of iterating all Photo objects in the pin and deleting them one at a time?
// Question: An image has been downloaded and is available in memory to be rendered on a cell in PhotoAlbumViewController. Can I eliminate the delay between the time cell.stopActivityIndicator() is called in the PhotoAlbumViewController.configureCell method, and the time when the image is actually rendered for that cell? The delay can be a couple of seconds. I tried calling setNeedsDisplay() but that didn't seem to help.

import UIKit
import CoreData
import MapKit

class PhotoAlbumViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, flickrDelegate, NSFetchedResultsControllerDelegate {

    var activityIndicator : UIActivityIndicatorView = UIActivityIndicatorView(frame: CGRectMake(0, 0, 50, 50)) as UIActivityIndicatorView
    
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
        
        // Initialize flickrPhotos from flickr if the current pin did not contain any photos.
        if let pin = pin {
            // enable the New Collection button
            newCollectionButton!.enabled = true
            
            // Fetch images from flickr if there are none associated with the currently selected pin.
            if pin.photos.count == 0 {
                initializePhotos()
            }
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        fetchedResultsController.delegate = nil
    }
    
    /* 
    @brief Search flickr for images by gps coordinates. Create a Photo object for each set of image meta returned. Insert each into the shared Core Data context.
    @discussion The data is returned from the Flickr object as an array of dictionaries, where each dictionary contains metadata for a particular image. The data does not contain the actual image data, but instead a url identifying the location of the image.
    */
    func initializePhotos() {
        self.startActivityIndicator()
        
        // disable the New Collection button until the images are downloaded from flickr.
        newCollectionButton!.enabled = false
        
        if let pin = self.pin {
            self.flickr.searchPhotosBy2DCoordinates(pin) {
                success, error, imageMetadata in
                if success == true {
                    // Persist each photo returned by the search as a new Photo instance, save it in the VC's flickrPhotos collection, & associate it with the view controller's current pin using the inverse relationship (by setting the photo's pin property to the VC's current pin).
                    self.saveImageMetadataAsPhotos(imageMetadata)
            
                    // halt the activity indicator
                    self.stopActivityIndicator()
                    
                    // enable the New Collection button.
                    self.newCollectionButton!.enabled = true
                    
                    // force the cells to update now that the images have been downloaded
                    dispatch_async(dispatch_get_main_queue()) {
                        //self.view.setNeedsDisplay()
                        self.collectionView.reloadData()
                    }
                } else {
                    // halt the activity indicator
                    self.stopActivityIndicator()
                    
                    // TODO - report error to user
                }
            }
        }
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: buttons
    
    func onNewCollectionButtonTap() {
        println("New Collection button selected.")
        
        // remove all photos associated with this pin in core data store
        if let pin = pin {
            for photo in pin.photos {
                self.sharedContext.deleteObject(photo)
            }
            CoreDataStackManager.sharedInstance().saveContext()
        }
        
        // fetch a new set of images
        initializePhotos()
    }
    
    
    // MARK: UICollectionViewDataSource protocol
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        println("numberOfItemsInSection reports number of Photos = \(sectionInfo.numberOfObjects) in section \(section)")
        let count = sectionInfo.numberOfObjects
        
        if count > 0 {
            self.noImagesLabel.hidden = true
            self.collectionView.hidden = false
        } else {
            self.noImagesLabel.hidden = false
            self.collectionView.hidden = true
        }
        
        return count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoAlbumCellID", forIndexPath: indexPath) as! PhotoAlbumCell
        
        self.configureCell(cell, atIndexPath: indexPath)
        
        return cell
    }
    
    // MARK: UICollectionViewDelegate protocol
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        // remove the Photo object from the core data store.
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        sharedContext.deleteObject(photo)
        CoreDataStackManager.sharedInstance().saveContext()
        
        // force the cells to update now that the image has been downloaded
        self.collectionView.reloadData()
    }

    
    // MARK: - Core Data
    
    /* core data managed object context */
    lazy var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }()
    
    /*
    @brief Persist each imageMetaData dictionary as a Photo object in Core Data.
    @discussion This function sets the Photo's inverse relationship to it's Pin, and saves the new Photo to the view controller's flickrPhotos collection.
    */
    func saveImageMetadataAsPhotos(imageMetadata: [[String: AnyObject?]]?) {
        dispatch_async(dispatch_get_main_queue()) {

            // create a new Photo instance
            var dict = [String: AnyObject]()
            dict[Photo.InitKeys.imageData] = nil // UIImageJPEGRepresentation(image, 1)
            dict[Photo.InitKeys.pin] = self.pin
            
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
                    var photo = Photo(dictionary:dict, context: self.sharedContext)
                }
            }

            // Persist all the photos we added to the Core Data shared context
            CoreDataStackManager.sharedInstance().saveContext()
        }
    }
    
    /* Remove the Photo object from the Core data store */
    func deletePhoto(photo: Photo) {
        self.sharedContext.deleteObject(photo)
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    
    // MARK: - Fetched results controller
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        // Create the fetch request
        let fetchRequest = NSFetchRequest(entityName: Photo.entityName)
        
        // Define the predicate (filter) for the query.
        if let pin = self.pin {
            fetchRequest.predicate = NSPredicate(format: "pin == %@", pin)
        } else {
            assert(self.pin != nil, "self.pin == nil in PhotoAlbumViewController") // TODO
        }
        
        // Add a sort descriptor to enforce a sort order on the results.
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        
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
    }
    
    /* hide acitivity indicator */
    func stopActivityIndicator() {
        dispatch_async(dispatch_get_main_queue()) {
            self.activityIndicator.stopAnimating()
        }
    }
    
    /* Set the cell image. */
    func configureCell(cell: PhotoAlbumCell, atIndexPath indexPath: NSIndexPath) {
        
        cell.startActivityIndicator()
        
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        // set placeholder image
        cell.imageView.image = UIImage(named: "placeholder.jpg")
        
        // Acquire the image from the Photo object.
        photo.getImage( { success, error, image in
            if success {
                cell.imageView.image = image
                cell.stopActivityIndicator()
                //self.collectionView.setNeedsDisplay()
            } else {
                cell.stopActivityIndicator()
            }
        })
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
        
        // calculate the cell size
        let nCells = 4
        let nSpaces = nCells - 1
        let widthSpaces: CGFloat = (4 * sectionInsets.left) + (4 * sectionInsets.right)
        let cellWidth = (collectionView.frame.size.width -  widthSpaces ) / 4
        return CGSize(width: cellWidth, height: cellWidth)
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        return sectionInsets
    }
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
