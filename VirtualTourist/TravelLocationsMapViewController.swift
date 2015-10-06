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

Acknowledgements: Thanks to matt for this SO post on draggable mapview annotations:  http://stackoverflow.com/questions/29776853/ios-swift-mapkit-making-an-annotation-draggable-by-the-user
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
    
    /* Flickr api wrapper object */
    let flickr = Flickr()
    
    /* The main core data managed object context. This context will be persisted. */
    lazy var sharedContext: NSManagedObjectContext = {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }()
    
    /* A core data managed object context that will not be persisted. */
    lazy var scratchContext: NSManagedObjectContext = {
        var context = NSManagedObjectContext()
        context.persistentStoreCoordinator = CoreDataStackManager.sharedInstance().persistentStoreCoordinator
        return context
    }()
    
    /* The pin instance that is saved to Core Data. */
    var persistentPin: Pin?
    
    /* A temporary pin used to track and display a pin while it is dragged. */
    var ephemeralPin: Pin?
//    var previousEphemeralPin: Pin?
    var ephemeralAnnotations = [MKAnnotation]()
    
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
        
        // disable display of the navigation controller's toolbar
        self.navigationController?.setToolbarHidden(true, animated: false)
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
        // TODO - debug: remove
        // Tell the OS that the mapView needs to be refreshed.
        self.mapView.setNeedsDisplay()
        
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
            pinView!.animatesDrop = false
            //pinView!.draggable = false //TODO
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    /* Handler for touch on a pin. */
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        println("pin selected")
        
        //view.draggable = false //TODO
        
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
            
            println(".Began initial ephemeral annotation count = \(self.ephemeralAnnotations.count)")
            println(".Began initial mapView annotation count = \(self.mapView.annotations.count)")
            
            switch state {
            case .AddPin:
                
                // Create a new Pin instance, display on the map, and save to the context.
//                previousEphemeralPin = ephemeralPin
//                if let ePin = ephemeralPin {
//                    ephemeralAnnotations.append(ePin.annotation)
//                    println("ephemeralAnnotations += 1 \(ePin.annotation)")
//                }
//                ephemeralPin = createPinAtPoint(viewPoint, bPersistPin: false)
                
                // get coordinates of touch in view
                let viewPoint: CGPoint = recognizer.locationInView(self.mapView)
                println(".AddPin: viewPoint = \(viewPoint)")
                
// Note:  OK, this pin is the one that ends up being the extra pin at the end. Figure out how to show the annotation on the map while dragging, without having this pin arround on the touch up.
                
                // Create a new Pin instance, display on the map, and save to the context.
                self.ephemeralPin = createPinAtPoint(viewPoint, bPersistPin: false)
                // TODO: testing. moved to .Ended
                if let pin = self.ephemeralPin {
                    self.ephemeralAnnotations.append(pin.annotation)
                    println("added ephemeral annotation.")
//                }
                
//                if let pin = self.ephemeralPin {
                    // Add the annotation to a local array of annotations.
                    var annotations = [MKPointAnnotation]()
                    annotations.append(pin.annotation)
                    
                    // Add the annotation to the map.
                    self.mapView.addAnnotations(annotations)

                    // Tell the OS that the mapView needs to be refreshed.
                    self.mapView.setNeedsDisplay()
                }
                
                println(".Began ephemeral annotation count = \(self.ephemeralAnnotations.count)")
                println(".Began mapView annotation count = \(self.mapView.annotations.count)")
                
            case .Edit:
                return
            default:
                return
            }
        }
        
        if(recognizer.state == UIGestureRecognizerState.Changed) {
            // Called while the finger is still down, if position moves by amount > tolerance
            
//            println("UIGestureRecognizerStateChanged")
            
            // remove previous ephemeral pin
//            dispatch_async(dispatch_get_main_queue()) {
//                if let pin = self.ephemeralPin {
//                    self.mapView.removeAnnotation(pin.annotation)
//                    self.mapView.setNeedsDisplay()
//                    println("removed ephemeral pin \(pin)")
//                }
//            }
            
            // TODO test only - nuke all annotations
            // TODO: idea - set property on annotation and filter on it in the line below to only nuke all ephemeral pins.
//            let annotationsToRemove = self.mapView.annotations.filter { $0 !== self.mapView.userLocation }
//            mapView.removeAnnotations( annotationsToRemove )
            
            // remove all ephemeral Annotations from the mapView
            // let annotationsToRemove = ephemeralAnnotations
            //self.mapView.removeAnnotations( ephemeralAnnotations )//  - darn. this doesn't appear to work. maybe the annotations i'm adding from the pin's coordinates don't match the coordinates in the mapview annotations? try filtering on mapview annotations removing anything not in our ephemeralAnnotations array, then pass the remaining collection to removeAnnotations(). That way I could see if matches occurr
            //self.ephemeralAnnotations.removeAll(keepCapacity: true)
            
            let viewPoint: CGPoint = recognizer.locationInView(self.mapView)
            println(".Changed: viewPoint = \(viewPoint)")
            
            // TODO - Udacious
            //Check to make sure the pin has dropped
//            if droppedPin != nil {
//                
//                //Get the coordinates from the map where we dragged over
                //let tapPoint: CGPoint = recognizer.locationInView(mapView)
                let mapCoordinate2D: CLLocationCoordinate2D = mapView.convertPoint(viewPoint, toCoordinateFromView: mapView)

                // remove the ephemeral annotations
                self.removeEphemeralAnnotationsFromMapView()
            
                //Update the pin view
//                dispatch_async(dispatch_get_main_queue(), {
                    if let pin = self.ephemeralPin {
                        println("update ephemeral pin coordinates and show \(pin)")
                        // show new ephemeral pin
                        pin.coordinate = mapCoordinate2D
//                        self.showPinOnMap(pin) // not needed to render pin while moved
                        
                        
//                        if let pin = self.ephemeralPin {
//                            self.ephemeralAnnotations.append(pin.annotation)
//                            println("added ephemeral annotation.")
//                        }

                        
                        
                        // Add the annotation to a local array of annotations.
                        var annotations = [MKPointAnnotation]()
                        annotations.append(pin.annotation)
                        
                        // record the annotation as an ephemeral annotation
                        self.ephemeralAnnotations.append(pin.annotation)
                        
                        // Add the annotation(s) to the map.
                        self.mapView.addAnnotations(annotations)
                        
                        println("mapView.addAnnotations in handleLongPress() .Changed. annotations: \(annotations)")
                        
                        
                        // Tell the OS that the mapView needs to be refreshed.
                        self.mapView.setNeedsDisplay()
                        
                        println(".Changed added ephemeral annotation. new count = \(self.ephemeralAnnotations.count)")
                        println(".Changed added  mapView  annotation. new count = \(self.mapView.annotations.count)")
                        
                        println(".Changed debug. ephemeralAnnotations count = \(self.ephemeralAnnotations.count), mapView annotations = \(self.mapView.annotations.count)")
                        println("ephemeralAnnotations: \(self.ephemeralAnnotations), mapView annotations: \(self.mapView.annotations)")
                        
                    }
//                })
//            }
        }
        
        // START HERE
        // TODO: Somewhere a second pin is being added. Comment out everywhere a pin is being created until I find the spot where the 2nd pin is no longer created.
        
        // TODO - Udacious
        if(recognizer.state == UIGestureRecognizerState.Ended) {
            
            // remove the ephemeral annotations
            self.removeEphemeralAnnotationsFromMapView()
            println(".Ended debug. ephemeralAnnotations count = \(self.ephemeralAnnotations.count), mapView annotations = \(self.mapView.annotations.count)")
            println("ephemeralAnnotations: \(self.ephemeralAnnotations), mapView annotations: \(self.mapView.annotations)")
            
            // Create a new Pin instance, display on the map, and save to the context.
            let viewPoint1: CGPoint = recognizer.locationInView(self.mapView)
            createPinAtPoint(viewPoint1, bPersistPin: true)
            
            return
                
// =======================================================================================================
            
//            // gesture has finished (finger was lifted)
            println("UIGestureRecognizerStateEnded")
            
            // get coordinates of touch in view
            let viewPoint: CGPoint = recognizer.locationInView(self.mapView)
            println(".Ended: viewPoint = \(viewPoint)")
            let mapCoordinate2D: CLLocationCoordinate2D = mapView.convertPoint(viewPoint, toCoordinateFromView: mapView)
            var annotation = MKPointAnnotation()
            annotation.coordinate = mapCoordinate2D
            
            println(".Ended before append. ephemeralAnnotations count = \(self.ephemeralAnnotations.count), mapView annotations = \(self.mapView.annotations.count)")
            
            // record the annotation as an ephemeral annotation
            self.ephemeralAnnotations.append(annotation)
            
            println(".Ended after append but before removal. ephemeralAnnotations count = \(self.ephemeralAnnotations.count), mapView annotations = \(self.mapView.annotations.count)")
            
            // remove any remaining ephemeral annotations
            self.removeEphemeralAnnotationsFromMapView()
            
//            let annotationsToRemove = self.mapView.annotations.filter { $0 !== self.mapView.userLocation }
//            self.mapView.removeAnnotations( annotationsToRemove )
            
            println(".Ended after removal. ephemeralAnnotations count = \(self.ephemeralAnnotations.count), mapView annotations = \(self.mapView.annotations.count)")
            
            // Create a new Pin instance, display on the map, and save to the context.
            createPinAtPoint(viewPoint, bPersistPin: true)
            
            // Update the location of the pin with the final coordinates from the gesture tracker
//TODO            persistentPin?.latitude = mapCoordinate2D.latitude
//TODO            persistentPin?.longitude = mapCoordinate2D.longitude
//            persistentPin?.coordinate = mapCoordinate2D
            
//            println("removing \(ephemeralAnnotations.count) ephemeral annotations")
//            self.mapView.removeAnnotations( ephemeralAnnotations )
//            ephemeralAnnotations.removeAll(keepCapacity: false)
//            println("removed ephemeral annotations. number of annotations = \(ephemeralAnnotations.count) ")
            
            
            // This works - it does remove all annotations
//            let annotationsToRemove = self.mapView.annotations.filter { $0 !== self.mapView.userLocation }
//            self.mapView.removeAnnotations( annotationsToRemove )
            
            // filter self.mapView.annotations by ephemeralAnnotations
            

            
//            let annotationsToRemove = [MKAnnotation]()
//            for annotation in self.ephemeralAnnotations {
//                let filtered = self.mapView.annotations.filter { $0 == annotation }
//                annotationsToRemove.append(filtered)
//            }
            //filter(self.mapView.annotations) { contains(self.ephemeralAnnotations, $0) }
            //self.mapView.annotations.filter( { m in contains(self.ephemeralAnnotations, m) })
            
// This code works:
//            var annotationsToRemove = [MKAnnotation]()
//            for annotation in self.ephemeralAnnotations {
//                let filtered = self.mapView.annotations.filter( {
//                    $0.coordinate.latitude == annotation.coordinate.latitude &&
//                        $0.coordinate.longitude == annotation.coordinate.longitude
//                })
//                for annotation: MKAnnotation in filtered as! [MKAnnotation] {
//                    annotationsToRemove.append(annotation)
//                }
//            }
//            
//            println("annotationsToRemove = \(annotationsToRemove) after filtering self.mapView.annotations by ephemeralAnnotations")
//            println("number of annotationToRemove = \(annotationsToRemove.count)")
//            self.mapView.removeAnnotations( annotationsToRemove )
//            
//            // Tell the OS that the mapView needs to be refreshed.
            self.mapView.setNeedsDisplay()
        }
    }
    
    func removeEphemeralAnnotationsFromMapView() {
        var annotationsToRemove = [MKAnnotation]()
        for annotation in self.ephemeralAnnotations {
            let filtered = self.mapView.annotations.filter( {
                $0.coordinate.latitude == annotation.coordinate.latitude &&
                    $0.coordinate.longitude == annotation.coordinate.longitude
            })
            for annotation: MKAnnotation in filtered as! [MKAnnotation] {
                annotationsToRemove.append(annotation)
            }
        }
        
        //            let annotationsToRemove = [MKAnnotation]()
        //            for annotation in self.ephemeralAnnotations {
        //                let filtered = self.mapView.annotations.filter { $0 == annotation }
        //                annotationsToRemove.append(filtered)
        //            }
        //filter(self.mapView.annotations) { contains(self.ephemeralAnnotations, $0) }
        //self.mapView.annotations.filter( { m in contains(self.ephemeralAnnotations, m) })
        
        
        println("count of emphemeralAnnotations = \(ephemeralAnnotations.count)")
        println("annotationsToRemove = \(annotationsToRemove) after filtering self.mapView.annotations by ephemeralAnnotations")
        println("number of annotationToRemove = \(annotationsToRemove.count)")
        self.mapView.removeAnnotations( annotationsToRemove )
        
        // reset the Ephemeral Annotations
        self.ephemeralAnnotations.removeAll(keepCapacity: false)
        
        // reset the annotationsToRemove
        annotationsToRemove.removeAll(keepCapacity: false)
        
        println("after removal, number of annotationsToRemove = \(annotationsToRemove.count)")
        println("after removal, count of emphemeralAnnotations = \(ephemeralAnnotations.count)")

        
        // Tell the OS that the mapView needs to be refreshed.
        self.mapView.setNeedsDisplay()
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
    func createPinAtPoint(viewPoint: CGPoint, bPersistPin: Bool) -> Pin {
        
        // get coordinates of touch in the map's gps coordinate space.
        let mapPoint: CLLocationCoordinate2D = self.mapView.convertPoint(viewPoint, toCoordinateFromView: self.mapView)
        println("CreatePinAtCoordinate mapPoint = \(mapPoint.latitude), \(mapPoint.longitude)") // TODO: remove
        
        var context: NSManagedObjectContext
        if bPersistPin {
            context = sharedContext
        } else {
            context = scratchContext
        }
        
        // Create a pin (annotation) based on the calculated gps coordinates.
        let pin: Pin = createPinAtCoordinate(latitude: mapPoint.latitude, longitude: mapPoint.longitude, context: context)
        
        if bPersistPin {
            
            // Display the pin on the map.
            showPinOnMap(pin)

            // TODO: persist the pin
//TODO - debug             savePin()

            // TODO: Udacious - As soon as a pin is dropped on the map, the photos for that location are pre-fetched from Flickr
            self.flickr.searchPhotosBy2DCoordinates(pin) {
                success, error, imageMetadata in
                if success == true {
                    // Create a Photo instance for each image metadata dictionary in imageMetadata. Associate each Photo with the pin.
                    Photo.initPhotosFrom(imageMetadata, forPin: pin)
                }
            }

        }
        
        return pin
    }
    
    /* 
    @brief Create a new Pin in the specified Core Data context at the specified 2D map coordinate and return it.
    @param latitude (in) map coordinate
    @param longitude (in) map coordinate
    @param context (in) Core Data context to use when instantiating the Pin object.
    */
    func createPinAtCoordinate(#latitude: Double, longitude: Double, context: NSManagedObjectContext) -> Pin {
        var dict = [String: AnyObject]()
        dict[Pin.Keys.latitude] = latitude
        dict[Pin.Keys.longitude] = longitude
        let pin = Pin(dictionary: dict, context: context)
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
        println("showPinOnMap: \(pin)")
        // Add the annotation to a local array of annotations.
        var annotations = [MKPointAnnotation]()
        annotations.append(pin.annotation)
        
        // Add the annotation(s) to the map.
        self.mapView.addAnnotations(annotations)
        
        println("mapView.addAnnotations in showPinOnMap(). annotations: \(annotations)")
        
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
        
        println("mapView.addAnnotations in refreshPins(). annotations: \(annotationsToAdd)")
        
        // draw the pins
        dispatch_async(dispatch_get_main_queue()) {
            self.mapView.setNeedsDisplay()
        }
    }
    
//    /* handle changes to drag state of an annotation */
//    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
////        switch (newState) {
////        case .Starting:
////            view.dragState = .Dragging
////        case .Ending, .Canceling:
////            view.dragState = .None
////        default: break
////        }
//        
//        if newState == MKAnnotationViewDragState.Ending {
//            let annotation = view.annotation
//            println("The annotation is located at: \(annotation.coordinate.latitude),\(annotation.coordinate.longitude)")
//        }
//    }
}
