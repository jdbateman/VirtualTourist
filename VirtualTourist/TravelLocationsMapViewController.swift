/*!
@header TravelLocationsMapViewController.swift

VirtualTourist

The TravelLocationsMapViewController class is the initial view controller. It displays a MapView and collection of annotations (also refered to as pins) persisted with CoreData. The controller supports two interaction modes: AddPin mode and Edit mode. The controller supports the following functionality:
- The controller starts in AddPin mode. Long press on the MapView to drop a new pin on the map.
- Tap a pin to launch the PhotoAlbumViewController.
- Select the Edit button to change interaction to Edit mode. In edit mode selecting a pin deletes the pin.
- Select the Done button to change interaction back to AddPin mode.

@author John Bateman. Created on 9/15/15
@copyright Copyright (c) 2015 John Bateman. All rights reserved.
*/

import UIKit
import CoreData
import CoreLocation
import MapKit

class TravelLocationsMapViewController: UIViewController, /*NSFetchedResultsControllerDelegate,*/ MKMapViewDelegate, UIGestureRecognizerDelegate  {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var mapContainerView: UIView!
    @IBOutlet weak var hintContainerView: UIView!
    
    var mapRegion: MapRegion?
    
    /* The user interaction state of the view controller. */
    enum ControllerState {
        case AddPin     // press and hold on map view to add a pin
        case Edit       // tap a pin to delete it
    }
    
    /* Holds the current user interaction state of the controller. */
    var state: ControllerState = .AddPin
    
    /* To detect long taps on the MKMapView. */
    var longPressRecognizer: UILongPressGestureRecognizer? = nil
    
    /* core data managed object context */
    lazy var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add edit button to nav bar.
        let editButton = UIBarButtonItem(barButtonSystemItem: .Edit, target: self, action: "onEditButtonTap")
        self.navigationItem.rightBarButtonItem = editButton
        
        // Hide the edit mode hint view.
        hintContainerView.hidden = true
        
        // set map view delegate.
        mapView.delegate = self
        
        // Initialize the longTapRecognizer.
        initLongPressRecognizer()
        
        // Initialize the fetchResultsController.
//        initFetchedResultsController()
        
        // Initialize the map region
        initMapRegion()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Add the long press gesture recognizer to the map view.
        addLongPressRecognizer()
        
        // redraw all pins on mapview
        refreshPins()
        
        // turn the navigation controller's toolbar off
        self.hidesBottomBarWhenPushed = true
    }
    
//    override func viewDidAppear(animated: Bool) {
//        super.viewDidAppear(animated)
//        
//        UIView.animateWithDuration(1.5, animations: {
//            self.hintContainerView.alpha = 1.0
//        })
//    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Remove the long press gesture recognizer from the map view.
        removeLongPressRecognizer()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // MARK: Button Handlers
    
    /* The edit button was selected. Modify UI and state to put the controller in edit mode. */
    func onEditButtonTap() {
        // Dispay "Tap Pins to Delete" label. Animate in from bottom.
        hintContainerView.hidden = false
        //self.hintContainerView.alpha = 0.0
        
        // Set initial position of hintContainerView beyond the bottom of the visible screen.
        self.hintContainerView.frame = CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y + self.view.frame.size.height, self.view.frame.size.width, 80)
        
        // Animate
        UIView.animateWithDuration(0.5, animations: {
            // Shrink height of mapContainerView by 80.
            self.mapContainerView.frame = CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y + 64.0 - 80, self.view.frame.size.width, self.view.frame.size.height)
            
            // Move hintContainerView up 80 (into visible region of view).
            self.hintContainerView.frame = CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y + self.view.frame.size.height - 80, self.view.frame.size.width, 80)
            
            //self.hintContainerView.alpha = 1.0
        })
        
        // Hide the Edit button. Show the Done button.
        let doneButton = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "onDoneButtonTap")
        self.navigationItem.rightBarButtonItem = doneButton
        
        // Change the VC state to edit mode.
        state = .Edit
    }
    
    /* The done button was selected. Modify UI and state to put the controller in AddPin mode. */
    func onDoneButtonTap() {
        println("Done button tapped.")
        
        // Remove the "Tap Pins to Delete" label. Animate down.
        
        // Animate
        UIView.animateWithDuration(0.5, animations: {
            // Increase the height of the mapContainerView by 80.
            self.mapContainerView.frame = CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y + 64, self.view.frame.size.width, self.view.frame.size.height - 64)
            
            // Increase the height of the mapView by 80
            self.mapView.frame = CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y - 64, self.view.frame.size.width, self.view.frame.size.height)
            
            // move hintContainerView down 80 (off visible screen).
            self.hintContainerView.frame = CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y + self.view.frame.size.height, self.view.frame.size.width, 80)
            },
            completion: {
                (value: Bool) in
                // Remove the "Tap Pins to Delete" label.
                self.hintContainerView.hidden = true
            })
        
        // Hide the Done button. Show the Edit button.
        let editButton = UIBarButtonItem(barButtonSystemItem: .Edit, target: self, action: "onEditButtonTap")
        self.navigationItem.rightBarButtonItem = editButton
        
        // Change the VC state to AddPin mode.
        state = .AddPin
    }
    

    // MARK: - Segues
// TODO
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail" {
//            if let indexPath = self.tableView.indexPathForSelectedRow() {
//            let object = self.fetchedResultsController.objectAtIndexPath(indexPath) as! NSManagedObject
//            (segue.destinationViewController as! DetailViewController).detailItem = object
//            }
        }
    }
/*
    // MARK: - Fetched results controller
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        // Create the fetch request
        let fetchRequest = NSFetchRequest(entityName: Pin.entityName)
        
        // Add a sort descriptors to enforce a sort order on the results.
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: false), NSSortDescriptor(key: "longitude", ascending: false)]
        
        // Create the Fetched Results Controller
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext:
            self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        
        // Return the fetched results controller. It will be the value of the lazy variable
        return fetchedResultsController
    } ()
    
    /* Perform fetch to initialize the fetchedResultsController. */
    func initFetchedResultsController() {
        var error: NSError? = nil
        
        fetchedResultsController.performFetch(&error)
        
        if let error = error {
            println("Unresolved error in fetchedResultsController.performFetch \(error), \(error.userInfo)")
            // TODO: Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate.
            abort()
        }
    }

    func controllerWillChangeContent(controller: NSFetchedResultsController) {
//        self.tableView.beginUpdates()
    }

    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
            case .Insert:
            println("insert")
//                self.tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
            case .Delete:
            println("delete")
//                self.tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
            default:
                return
        }
    }

    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
            case .Insert:
            println("insert")
//                tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
            case .Delete:
            println("delete")
//                tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            case .Update:
            println("update")
//                self.configureCell(tableView.cellForRowAtIndexPath(indexPath!)!, atIndexPath: indexPath!)
            case .Move:
            println("move")
//                tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
//                tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
            default:
                return
        }
    }

    func controllerDidChangeContent(controller: NSFetchedResultsController) {
//        self.tableView.endUpdates()
    }

    /*
     // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
     
     func controllerDidChangeContent(controller: NSFetchedResultsController) {
         // In the simplest, most efficient, case, reload the table view.
         self.tableView.reloadData()
     }
     */
*/
    
    // MARK: MKMapViewDelegate
    
    /* Create an accessory view for the pin annotation callout when it is added to the map view */
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.pinColor = .Purple
            pinView!.rightCalloutAccessoryView = UIButton.buttonWithType(.DetailDisclosure) as! UIButton  // DetailDisclosure, InfoLight, InfoDark, ContactAdd
            pinView!.animatesDrop = true
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    /* Handler for touch on a pin. */
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        println("pin selected")
        
        // get the annotation for the annotation view
        let annotation: MKAnnotation = view.annotation
        
        // fetch pin by coordinate from the context
        var pin: Pin? = fetchPin(atCoordinate: annotation.coordinate)
        
        switch state {
        case .AddPin:
            // display PhotoAlbumViewController
            var storyboard = UIStoryboard (name: "Main", bundle: nil)
            var controller = storyboard.instantiateViewControllerWithIdentifier("PhotoAlbumControllerID") as! PhotoAlbumViewController
            controller.pin = pin
            self.navigationController?.pushViewController(controller, animated: true)
        case .Edit:
            // delete the selected pin
            if let pin = pin {
                deletePin(pin)
            }
            
            // TODO: - need to remove the annotation from the MKMapView
            self.mapView.removeAnnotation(annotation)
            
        default:
            return
        }
        
    }
    
    //TODO - remove...
    /* This delegate method is implemented to respond to taps. It presents the PhotoAlbumViewController. */
    func mapView(mapView: MKMapView!, annotationView: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        println("mapView:mapView:annotationView:calloutAccessoryControlTapped:")
        if control == annotationView.rightCalloutAccessoryView {
//            if let urlString = annotationView.annotation.subtitle {
//                showUrlInEmbeddedBrowser(urlString)
//            }
        }
    }
    
    /* The region displayed by the mapview has just changed. */
    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        println("region changed: \(mapView.region.center.latitude, mapView.region.center.longitude)")
        updateAndSaveMapRegion()
    }
    
    /* 
    @brief Return the Pin instance from the persistent store that matches the specified coordinate.
    @discussion Typically we would only expect a single pin to match coordinate. It is possible that more than one pin has the same map coordinate. However, even in that case it is a better user experience to delete a single pin per tap in Edit mode. Therefor, this function will only return the first pin matching the specified coordinate.
    */
    func fetchPin(atCoordinate coordinate: CLLocationCoordinate2D) -> Pin? {
        // Create and execute the fetch request
        let error: NSErrorPointer = nil
        let fetchRequest = NSFetchRequest(entityName: Pin.entityName)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: false), NSSortDescriptor(key: "longitude", ascending: false)]
        let predicateLat = NSPredicate(format: "latitude == %@", NSNumber(double: coordinate.latitude))
        let predicateLon = NSPredicate(format: "longitude == %@", NSNumber(double: coordinate.longitude))
        let predicate = NSCompoundPredicate(type: NSCompoundPredicateType.AndPredicateType, subpredicates: [predicateLat, predicateLon])
        fetchRequest.predicate = predicate
        let results = sharedContext.executeFetchRequest(fetchRequest, error: error)
  
        // Check for Errors
        if error != nil {
            println("Error in fectchAllActors(): \(error)")
        }
        
        // Return the first result, or nil
        if let results = results {
            return (results[0] as! Pin)
        } else {
            return nil
        }
    }
    
    /* Query context for all pins. Return array of Pin instances, or an empty array if no results or query failed. */
    func fetchAllPins() -> [Pin] {
        let errorPointer: NSErrorPointer = nil
        let fetchRequest = NSFetchRequest(entityName: Pin.entityName)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: false), NSSortDescriptor(key: "longitude", ascending: false)]
        let results = sharedContext.executeFetchRequest(fetchRequest, error:errorPointer)
        if errorPointer != nil {
            println("Error in fectchAllActors(): \(errorPointer)")
        }
        return results as? [Pin] ?? [Pin]()
    }
    
    /* Query the CoreData context for the MapRegion entity */
    func fetchMapRegion() -> [MapRegion] {
        // Create and execute the fetch request
        let error: NSErrorPointer = nil
        let fetchRequest = NSFetchRequest(entityName: MapRegion.entityName)
        let results = sharedContext.executeFetchRequest(fetchRequest, error: error)
        
        // Check for Errors
        if error != nil {
            println("Error in fetchMapRegion(): \(error)")
        }
        
        return results as? [MapRegion] ?? [MapRegion]()
    }
    
    /* Query context for all MapRegion objects. Return array of MapRegion instances, or an empty array if no results or query failed. */
    func fetchAllMapRegions() -> [MapRegion] {
        let errorPointer: NSErrorPointer = nil
        let fetchRequest = NSFetchRequest(entityName: MapRegion.entityName)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: false), NSSortDescriptor(key: "longitude", ascending: false)]
        let results = sharedContext.executeFetchRequest(fetchRequest, error:errorPointer)
        if errorPointer != nil {
            println("Error in fetchAllMapRegions(): \(errorPointer)")
        }
        return results as? [MapRegion] ?? [MapRegion]()
    }
    
    
    // MARK: Long press gesture recognizer
    
    func initLongPressRecognizer() {
        longPressRecognizer = UILongPressGestureRecognizer(target: self, action: Selector("handleLongPress:"))
    }
    
    /* Add the long press recognizer to the MKMapView */
    func addLongPressRecognizer() {
        if let longPressRecognizer = longPressRecognizer {
            self.mapView.addGestureRecognizer(longPressRecognizer)
            println("longPressRecognizer added to mapView")
        }
        self.mapView.userInteractionEnabled = true
    }
    
    /* remove the long press gesture recognizer */
    func removeLongPressRecognizer() {
        if let longPressRecognizer = longPressRecognizer {
            mapView.removeGestureRecognizer(longPressRecognizer)
        }
    }
    
    /* User long pressed on the map view. Add a pin if in .AddPin mode, else ignore. */
    func handleLongPress(recognizer: UILongPressGestureRecognizer) {
        
        if(recognizer.state == UIGestureRecognizerState.Began) {
            // gesture started
            println("UIGestureRecognizerStateBegan: long press on pin")
            
            switch state {
            case .AddPin:
                // get coordinates of touch in view
                let viewPoint: CGPoint = recognizer.locationInView(self.mapView) //TODO - remove:locationOfTouch(0, inView: self.mapView)
                println("viewPoint = \(viewPoint)")  // TODO: remove
                
                // Create a new Pin instance, display on the map, and save to the context.
                createPinAtPoint(viewPoint)
            case .Edit:
                return
            default:
                return
            }
        }
        
        if(recognizer.state == UIGestureRecognizerState.Changed) {
            // Called while the finger is still down, if position moves by amount > tolerance
            println("UIGestureRecognizerStateChanged")
        }
        
        if(recognizer.state == UIGestureRecognizerState.Ended) {
            // gesture has finished (finger was lifted)
            println("UIGestureRecognizerStateEnded")
        }
    }
    
    
    // MARK: MapRegion functions
    
    /* 
    @brief Set the mapView's region to either the persisted region or to a default centered on North America.
    @discussion Setting the MKMapView's region causes the mapView to call it's mapView:mapView:regionDidChangeAnimated: delegate function. In that function the self.mapRegion will be updated, and the self.mapRegion instance will be created if necessary.
    */
    func initMapRegion() {
        
        // Get persisted MapRegion instance from Core data (if any exists) and save it to both the view controller's private mapRegion property, and the mapView's region.
        let regions = fetchMapRegion()
        if regions.count > 0 {
            // Use the persisted value for the region.
            
            // set the view controller's mapRegion property
            self.mapRegion = regions[0]
            
            // Set the mapView's region.
            self.mapView.region = regions[0].region
        } else {
            // Set the default region.
            let location = CLLocationCoordinate2DMake(39.50, -98.35) // center of North America
            let span = MKCoordinateSpanMake(30, 30)
            
            if self.mapRegion != nil {
                // set the existing mapRegion property instance to the default region.
                self.mapRegion!.latitude = location.latitude
                self.mapRegion!.longitude = location.longitude
                self.mapRegion!.spanLatitude = span.latitudeDelta
                self.mapRegion!.spanLongitude = span.longitudeDelta
                
            } else {
                // Create a default map region instance and save it to this view controllers mapRegion property.
                var dict = [String: AnyObject]()
                dict[MapRegion.Keys.latitude] = location.latitude
                dict[MapRegion.Keys.longitude] = location.longitude
                dict[MapRegion.Keys.spanLatitude] = span.latitudeDelta
                dict[MapRegion.Keys.spanLongitude] = span.longitudeDelta
                self.mapRegion = MapRegion(dictionary: dict, context: sharedContext)
            }
            
            // set the MapView's default region
            let region = MKCoordinateRegionMake(location, span)
            self.mapView.region = region
        }
        
        logMapViewRegion()
    }
    
    /* Save this view controller's mapRegion to the context after updating it to the mapView's current region. */
    func updateAndSaveMapRegion() {
        
        if let region = self.mapRegion {
            // Set the mapRegion property to the mapView's current region.
            self.mapRegion!.latitude = self.mapView.region.center.latitude
            self.mapRegion!.longitude = self.mapView.region.center.longitude
            self.mapRegion!.spanLatitude = self.mapView.region.span.latitudeDelta
            self.mapRegion!.spanLongitude = self.mapView.region.span.longitudeDelta
            
            //println("updated existing MapRegion: \(self.mapRegion)")
        } else {
            // Create a map region instance initialized to the mapView's current region.
            var dict = [String: AnyObject]()
            dict[MapRegion.Keys.latitude] = self.mapView.region.center.latitude
            dict[MapRegion.Keys.longitude] = self.mapView.region.center.longitude
            dict[MapRegion.Keys.spanLatitude] = self.mapView.region.span.latitudeDelta
            dict[MapRegion.Keys.spanLongitude] = self.mapView.region.span.longitudeDelta
            self.mapRegion = MapRegion(dictionary: dict, context: sharedContext)
            
            //println("created a new MapRegion: \(self.mapRegion)")
        }
        
        
        // persist the controller's mapRegion property
        CoreDataStackManager.sharedInstance().saveContext()
        
        //println("persisted self.mapRegion: \(self.mapRegion!.latitude, self.mapRegion!.longitude, self.mapRegion!.spanLatitude, self.mapRegion!.spanLongitude)")
    }
    
    /* Delete any existing MapRegion values in the Core Data store. */
    func deleteAllPersistedMapRegions() {
        
        var regions = fetchAllMapRegions()
        for region: MapRegion in regions {
            println("deleting a persisted region: \(region.latitude, region.longitude, region.spanLatitude, region.spanLongitude)")
            sharedContext.deleteObject(region)
            CoreDataStackManager.sharedInstance().saveContext()
        }
    }
    
    func logMapViewRegion() {
        
        let region = self.mapView.region
        println("map region: \(region.center.latitude, region.center.longitude, region.span.latitudeDelta, region.span.longitudeDelta)")
    }
    
    
    // MARK: Pin manipulation
    
    /* 
    @brief Create a new Pin instance for the specified point in the view, display it on the map, and save to the context.
    @param (in) viewPoint - parent UIView of mapView
    */
    func createPinAtPoint(viewPoint: CGPoint) {
        
        // get coordinates of touch in view
//        let viewPoint: CGPoint = recognizer.locationInView(self.mapView) //TODO - remove:locationOfTouch(0, inView: self.mapView)
//        println("viewPoint = \(viewPoint)")  // TODO: remove
        
        // get coordinates of touch in the map's gps coordinate space.
        let mapPoint: CLLocationCoordinate2D = self.mapView.convertPoint(viewPoint, toCoordinateFromView: self.mapView)
        println("mapPoint = \(mapPoint.latitude), \(mapPoint.longitude)") // TODO: remove
        
        // Create a pin (annotation) based on the calculated gps coordinates.
        let pin: Pin = createPinAtCoordinate(latitude: mapPoint.latitude, longitude: mapPoint.longitude)
        
        // Display the pin on the map.
        showPinOnMap(pin)
        
        // TODO: persist the pin
        savePin()
    }
    
    /* Create a new Pin at the specified 2D map coordinate and return it. */
    func createPinAtCoordinate(#latitude: Double, longitude: Double) -> Pin {
        var dict = [String: AnyObject]()
        dict[Pin.Keys.latitude] = latitude
        dict[Pin.Keys.longitude] = longitude
        let pin = Pin(dictionary: dict, context: sharedContext)
        return pin
    }
    
    /* Save the specified annotation to the context. */
    func savePin() {
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    /* Remove the specified pin instance from the context. */
    func deletePin(pin: Pin) {
        sharedContext.deleteObject(pin)
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    /* Display the specified pin on the MKMapView */
    func showPinOnMap(pin: Pin) {
        // Add the annotation to a local array of annotations.
        var annotations = [MKPointAnnotation]()
        annotations.append(pin.annotation)
        
        // Add the annotation(s) to the map.
        self.mapView.addAnnotations(annotations)
        
        // Center the map on the coordinate(s).
        //self.mapView.setCenterCoordinate(pin.coordinate, animated: true)
        
        // Tell the OS that the mapView needs to be refreshed.
        self.mapView.setNeedsDisplay()
    }
    
    /* Redraw all the persisted pins on the mapview. */
    func refreshPins() {
        // clear all pins from the mapView
        let annotations = mapView.annotations //add this if you want to leave the pin of the user's current location .filter { $0 !== mapView.userLocation }
        mapView.removeAnnotations(annotations)
        
        // query the context for all pins
        let pins = fetchAllPins()
        
        var annotationsToAdd = [MKAnnotation]()
        for pin in pins {
            annotationsToAdd.append(pin.annotation)
            //showPinOnMap(pin)
        }
        
        // add all the pins to the mapView
        mapView.addAnnotations(annotationsToAdd)
        
        // draw the pins
        dispatch_async(dispatch_get_main_queue()) {
            self.mapView.setNeedsDisplay()
        }
    }
}


/*
var fetchedResultsController: NSFetchedResultsController {
if _fetchedResultsController != nil {
return _fetchedResultsController!
}

let fetchRequest = NSFetchRequest()
// Edit the entity name as appropriate.
let entity = NSEntityDescription.entityForName("Event", inManagedObjectContext: self.sharedContext)
fetchRequest.entity = entity

// Set the batch size to a suitable number.
fetchRequest.fetchBatchSize = 20

// Edit the sort key as appropriate.
let sortDescriptor = NSSortDescriptor(key: "timeStamp", ascending: false)
let sortDescriptors = [sortDescriptor]

fetchRequest.sortDescriptors = [sortDescriptor]

// Edit the section name key path and cache name if appropriate.
// nil for section name key path means "no sections".
let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: "Master")
aFetchedResultsController.delegate = self
_fetchedResultsController = aFetchedResultsController

var error: NSError? = nil
if !_fetchedResultsController!.performFetch(&error) {
// Replace this implementation with code to handle the error appropriately.
// abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//println("Unresolved error \(error), \(error.userInfo)")
abort()
}

return _fetchedResultsController!
}
var _fetchedResultsController: NSFetchedResultsController? = nil
*/

//    func insertNewObject(sender: AnyObject) {
//        let context = self.fetchedResultsController.managedObjectContext
//        let entity = self.fetchedResultsController.fetchRequest.entity!
//        let newManagedObject = NSEntityDescription.insertNewObjectForEntityForName(entity.name!, inManagedObjectContext: context) as! NSManagedObject
//
//        // If appropriate, configure the new managed object.
//        // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
//        newManagedObject.setValue(NSDate(), forKey: "timeStamp")
//
//        // Save the context.
//        var error: NSError? = nil
//        if !context.save(&error) {
//            // Replace this implementation with code to handle the error appropriately.
//            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//            //println("Unresolved error \(error), \(error.userInfo)")
//            abort()
//        }
//    }

///* Create a new Pin and save the context. */
//func insertNewObject(sender: AnyObject) {
//    let pin = Pin(context: sharedContext)
//    
//    pin.timeStamp = NSDate()
//    
//    CoreDataStackManager.sharedInstance().saveContext()
//}

/*
// MARK: - Table View

override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
return self.fetchedResultsController.sections?.count ?? 0
}

override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
return sectionInfo.numberOfObjects
}

override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as! UITableViewCell
self.configureCell(cell, atIndexPath: indexPath)
return cell
}

override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
// Return false if you do not want the specified item to be editable.
return true
}

override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
if editingStyle == .Delete {
let context = self.fetchedResultsController.managedObjectContext
context.deleteObject(self.fetchedResultsController.objectAtIndexPath(indexPath) as! NSManagedObject)

var error: NSError? = nil
if !context.save(&error) {
// Replace this implementation with code to handle the error appropriately.
// abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//println("Unresolved error \(error), \(error.userInfo)")
abort()
}
}
}

func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
let object = self.fetchedResultsController.objectAtIndexPath(indexPath) as! NSManagedObject
cell.textLabel!.text = object.valueForKey("timeStamp")!.description
}
*/

// DEBUG:
//println("\nonDoneButtonTap(): after animation -------------------------------------")
//println("view frame final (y, height) = \(self.view.frame.origin.y), \(self.view.frame.size.height)")
//println("mapContainerView frame final (y, height) = \(self.mapContainerView.frame.origin.y), \(self.mapContainerView.frame.size.height)")
//println("mapView frame final (y, height) = \(self.mapView.frame.origin.y), \(self.mapView.frame.size.height)")
//println("hintContainerView frame final (y, height) = \(self.hintContainerView.frame.origin.y), \(self.hintContainerView.frame.size.height)")

//        dispatch_async(dispatch_get_main_queue()) {
//            self.mapView.setNeedsDisplay()
//            self.view.setNeedsDisplay()
//        }