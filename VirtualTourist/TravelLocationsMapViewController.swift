/*!
@header TravelLocationsMapViewController.swift

VirtualTourist

The TravelLocationsMapViewController class is the initial view controller. It displays a MapView and collection of annotations (refered to as pins). The controller supports two interaction modes: AddPin mode and Edit mode. The controller supports the following functionality:
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

class TravelLocationsMapViewController: UIViewController, NSFetchedResultsControllerDelegate, MKMapViewDelegate, UIGestureRecognizerDelegate  {

    @IBOutlet weak var mapView: MKMapView!
    
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
        
        // set map view delegate
        mapView.delegate = self
        
        // Initialize the longTapRecognizer
        initLongPressRecognizer()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Add the long press gesture recognizer to the map view.
        addLongPressRecognizer()
    }
    
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
        println("Edit button tapped.")
        
        // TODO: Dispay "Tap Pins to Delete" label. Animate in from bottom.
        
        // TODO: Hide the Edit button. Show the Done button.
        let doneButton = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "onDoneButtonTap")
        self.navigationItem.rightBarButtonItem = doneButton
        
        // TODO: Change the VC state to edit mode.
        state = .Edit
    }
    
    /* The done button was selected. Modify UI and state to put the controller in AddPin mode. */
    func onDoneButtonTap() {
        println("Done button tapped.")
        
        // TODO: Remove the "Tap Pins to Delete" label. Animate down.
        
        // TODO: Hide the Done button. Show the Edit button.
        let editButton = UIBarButtonItem(barButtonSystemItem: .Edit, target: self, action: "onEditButtonTap")
        self.navigationItem.rightBarButtonItem = editButton
        
        // TODO: Change the VC state to AddPin mode.
        state = .AddPin
    }
    
    func insertNewObject(sender: AnyObject) {
        let context = self.fetchedResultsController.managedObjectContext
        let entity = self.fetchedResultsController.fetchRequest.entity!
        let newManagedObject = NSEntityDescription.insertNewObjectForEntityForName(entity.name!, inManagedObjectContext: context) as! NSManagedObject
             
        // If appropriate, configure the new managed object.
        // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
        newManagedObject.setValue(NSDate(), forKey: "timeStamp")
             
        // Save the context.
        var error: NSError? = nil
        if !context.save(&error) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            //println("Unresolved error \(error), \(error.userInfo)")
            abort()
        }
    }

    // MARK: - Segues

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail" {
//            if let indexPath = self.tableView.indexPathForSelectedRow() {
//            let object = self.fetchedResultsController.objectAtIndexPath(indexPath) as! NSManagedObject
//            (segue.destinationViewController as! DetailViewController).detailItem = object
//            }
        }
    }
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
*/
    func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
            let object = self.fetchedResultsController.objectAtIndexPath(indexPath) as! NSManagedObject
        cell.textLabel!.text = object.valueForKey("timeStamp")!.description
    }

    // MARK: - Fetched results controller

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
    
    // Recognize tap on pin
    func mapView(mapView: MKMapView!, didDeselectAnnotationView view: MKAnnotationView!) {
        println("pin selected")
        
        // TODO - display PhotoAlbumViewController
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

    
    // MARK: Tap gesture recognizer
    
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
    
    /* User long pressed on the map view. Add a pin. */
    func handleLongPress(recognizer: UILongPressGestureRecognizer) {
        
        if(recognizer.state == UIGestureRecognizerState.Began) {
            // gesture started
            println("UIGestureRecognizerStateBegan: long press on pin")
            
            // get coordinates of touch in view
            let viewPoint: CGPoint = recognizer.locationInView(self.mapView) //TODO - remove:locationOfTouch(0, inView: self.mapView)
            println("viewPoint = \(viewPoint)")  // TODO: remove
            
            // get coordinates of touch in the map's gps coordinate space.
            let mapPoint: CLLocationCoordinate2D = self.mapView.convertPoint(viewPoint, toCoordinateFromView: self.mapView)
            println("mapPoint = \(mapPoint.latitude), \(mapPoint.longitude)") // TODO: remove
            
            // Display a pin on the map at the calculated gps coordinates.
            showPinOnMap(latitude: mapPoint.latitude, longitude: mapPoint.longitude)
            
            // TODO: persist the pin
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
   
    /* Display a pin on the MKMapView at the specified gps coordinates, and center the map on it. */
    func showPinOnMap(#latitude: Double, longitude: Double) {
        
        // The lat and long are used to create a CLLocationCoordinates2D instance.
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude )
        
        // Here we create the annotation and set its coordiate, title, and subtitle properties
        var annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        // TODO.. remove: annotation.title = "\(location.firstName) \(location.lastName)"
        // TODO.. remove: annotation.subtitle = location.mediaURL
        
        // Add the annotation to an array of annotations.
        var annotations = [MKPointAnnotation]()
        annotations.append(annotation)
        
        // Add the annotations to the map.
        self.mapView.addAnnotations(annotations)
        
        // Center the map on the coordinates.
        self.mapView.setCenterCoordinate(coordinate, animated: true)
        
        // Tell the OS that the mapView needs to be refreshed.
        self.mapView.setNeedsDisplay()
    }
}

