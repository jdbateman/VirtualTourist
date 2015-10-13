# VirtualTourist
This Swift app for iPhone (iOS 8) let's you navigate a map, drop pins on a map, then select a pin to view and save recent Flickr pictures for that location. Uses CoreData, Flickr REST API.

## Implementation highlights
* annotations, images, and map region are persisted with an sqlite core data store
* scratch and persisted core data contexts
* data model utilizes one-to-one and one-to-many relationships
* separate classes manage core data and the interface with the Flickr REST API to keep view controllers lightweight
* image acquisition has been optimized to hit in memory and disk caches before re-downloading images over the network
* MKMapView
* UICollectionViewController with customized layout


## Screens

### Travel Locations View Controller

![Travel Locations View Controller](/../screenshots/VirtualTourist_screenshot_TravelLocationsViewController.png?raw=true "Travel Locations View Controller")

Press and hold to drop a pin anywhere on the map.

Special effect: Pin drops are animated, and the user can drag a pin around the map before releasing it. This was acheived using UIGestureRecognizer.

### Edit mode

![Edit mode](/../screenshots/VirtualTourist_EditMode.png?raw=true "Edit mode")

Tap a pin in edit mode to delete the pin. The pin is removed from the map and from core data. The one-to-many relationship between a pin and the photos is leveraged to remove all associated photos from the core data store.

### PhotoAlbumViewController

![Photo Album View Controller](/../screenshots/VirtualTourist_screenshot_PhotoAlbumViewController.png?raw=true "Photo Album View Controller")

Displays images associated with the 2D coordinate of the selected annotation. Select "New Collection" to asynchronously acquire and display new images from the flickr REST API.

### Asynchronous download

Images are downloaded on demand in a background queue. Images are cached in memory. Image data is stored locally on the filesystem and a reference is persisted in the core data store.

![Activity indicator](/../screenshots/VirtualTourist_screenshot_download_activity.png?raw=true "Activity indicator")

![Async download](/../screenshots/VirtualToursit_screenshot_async_download.png?raw=true "Async download")

