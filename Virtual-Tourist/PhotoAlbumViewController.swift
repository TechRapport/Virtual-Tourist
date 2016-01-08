//
//  PhotoAlbumViewController.swift
//  Virtual-Tourist
//
//  Created by Ryan Collins on 11/20/15.
//  Copyright © 2015 Tech Rapport. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController, PinLocationPickerViewControllerDelegate, UIGestureRecognizerDelegate  {
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var noPhotosLabel: UILabel!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var collectionButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    let regionRadius: CLLocationDistance = 1000
    var selectedPin: Pin!
    
    /* Pin picker delegate method, loads photos and centers map on pin */
    func pinLocation(pinPicker: PinLocationViewController, didPickPin pin: Pin) {
        
        selectedPin = pin
    }
    
    var selectedIndexPaths = [NSIndexPath]()
    var instertedIndexPaths = [NSIndexPath]()
    var deletedIndexPaths = [NSIndexPath]()
    var updatedIndexPaths = [NSIndexPath]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /* Set collection view delegate and data source */
        collectionView.delegate = self
        collectionView.dataSource = self
        
        /* Add annotations to map for selected pin and center */
        mapView.addAnnotation(selectedPin)
        centerMapOnLocation(forPin: selectedPin)
        
        subscribeToImageLoadingNotifications()
        performFetch()
        
        let gestureRecognizer = UIGestureRecognizer(target: view, action: "handleLongPress:")
        gestureRecognizer.delegate = self
        
        collectionView.addGestureRecognizer(gestureRecognizer)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        unsubscribeToImageLoadingNotifications()
    }
    
    func subscribeToImageLoadingNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "didFinishLoadingThumbnails", name: Notifications.didFinishLoadingThumbails, object: selectedPin)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "isLoadingThumbnails", name: Notifications.willFinishLoadingThumbnails, object: selectedPin)
    }
    
    func unsubscribeToImageLoadingNotifications () {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func isLoadingThumbnails() {
        print("Notification for isLoadingThumbnails Received")
        view.alpha = 0.6
        activityIndicator.startAnimating()
    }
    
    func didFinishLoadingThumbnails() {
        print("Notification for didFinishLoadingThumbnails Received")
        performFetch()
        self.activityIndicator.stopAnimating()
        view.fadeIn(0.3, delay: 0.0, alpha: 1.0, completion: {_ in})
        
        if selectedPin.loadingError != nil {
            alertController(withTitles: ["Ok", "Retry"], message: (selectedPin.loadingError?.localizedDescription)!, callbackHandler: [nil, {Void in
                
                }])
        }
        
    }
    
    /* Setup flowlayout upon layout of subviews */
    override func viewDidLayoutSubviews() {
        
        flowLayout.sectionInset = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        flowLayout.minimumLineSpacing = 4
        flowLayout.minimumInteritemSpacing = 4
        let contentSize: CGFloat = ((collectionView.bounds.width / 3) - 8)
        flowLayout.itemSize = CGSize(width: contentSize, height: contentSize)
        
    }
    
    func performFetch() {
        
        do {
            
            try fetchedResultsController.performFetch()

        } catch let error as NSError {
            handleErrors(forPin: selectedPin, error: error)
        }
    }
    
    @IBAction func didTapCollectionButtonUpInside(sender: AnyObject) {
        /* If there are no selected index paths, download new photos for the selected pin */
        if selectedIndexPaths.count == 0 {
            
            self.getImagesForPin()
            
        } else {
            
            for index in selectedIndexPaths {
                
                let photoToDelete = fetchedResultsController.objectAtIndexPath(index) as! NSManagedObject
                sharedContext.deleteObject(photoToDelete)
            }

            selectedIndexPaths.removeAll()
            configureCollectionButton()
            
            CoreDataStackManager.sharedInstance().saveContext()
            //Get new photos?
            performFetch()
        }
    }
    
    /* Handle logic for getting new photos for a pin and manage errors */
    func getImagesForPin(){
        selectedPin.fetchAndStoreImages({success, error in
            
            if error != nil {
                self.handleErrors(forPin: self.selectedPin, error: error!)
            }
            
        })
    }

    
    func handleErrors(forPin pin: Pin, error: NSError) {
        activityIndicator.stopAnimating()
        view.fadeIn()
        alertController(withTitles: ["OK", "Retry"], message: error.localizedDescription, callbackHandler: [nil, {Void in
            self.getImagesForPin()
        }])
    }
    
    /* Core data */
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        fetchRequest.sortDescriptors = []
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.selectedPin)
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        
        fetchedResultsController.delegate = self
        
        return fetchedResultsController
    }()

    
}

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        if controller.fetchedObjects?.count < 0 {
            print("No images fetched")
            return
        }
        
        collectionView.performBatchUpdates({
            
            self.collectionView.insertItemsAtIndexPaths(self.instertedIndexPaths)
            
            self.collectionView.deleteItemsAtIndexPaths(self.deletedIndexPaths)
            
            self.collectionView.reloadItemsAtIndexPaths(self.updatedIndexPaths)
            
            }, completion: {Void in
                self.instertedIndexPaths.removeAll()
                self.deletedIndexPaths.removeAll()
                self.updatedIndexPaths.removeAll()
        })
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            instertedIndexPaths.append(newIndexPath!)
        case .Delete:
            deletedIndexPaths.append(indexPath!)
        case .Update :
            updatedIndexPaths.append(indexPath!)
        default :
            break
        }
    }
    
    func configureCollectionButton() {
        if selectedIndexPaths.count > 0 {
            collectionButton.setTitle("Delete Selected Images", forState: .Normal)
        } else {
            collectionButton.setTitle("New Collection", forState: .Normal)
        }
    }
    
}

extension PhotoAlbumViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let sections = self.fetchedResultsController.sections![section] as NSFetchedResultsSectionInfo? {
            return sections.numberOfObjects
        }
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath) as! PhotoAlbumCollectionViewCell
        
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        if photo.image != nil {
            cell.imageView.image = photo.image
        } else if photo.filePath != nil {
            
            photo.imageForPhoto(nil)
        } 
        
        cell.activityIndicator.stopAnimating()
        cell.activityIndicator.fadeOut()
        cell.imageView.fadeIn()
        
        return cell
    }


    
    func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoAlbumCollectionViewCell
        
        if cell.isUpdating {
            return false
        }
        return true
    }
    
    func handLongPress(gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer.state != .Ended {
            return
        }
        
        let point = gestureRecognizer.locationInView(collectionView)
        
        let index = collectionView.indexPathForItemAtPoint(point)
        
        guard index != nil else {
            return
        }
        
        let cell = UICollectionViewCell() as! PhotoAlbumCollectionViewCell
        let galleryViewController = storyboard?.instantiateViewControllerWithIdentifier("GalleryViewController") as! GalleryViewController
        
        
        
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoAlbumCollectionViewCell
//        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
//        
//        if photo.filePath == nil || photo.filePath == "" {
//            
//            /* Try refetching here */
//            performFetch(nil)
//            return
//        }
//        
        if selectedIndexPaths.contains(indexPath) {
            cell.isSelected(false)
        } else {
            cell.isSelected(true)
        }
        
        /* COnfigure cell and update UI */
        
        configureCollectionButton()
    }

}

/* Handles showing the map view for pins selected */
extension PhotoAlbumViewController: MKMapViewDelegate {
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? Pin {
            
            let pinId = "pin"
            
            var annotationViewToReturn: MKPinAnnotationView
            
            /* If we are reusing the annotation view, set a new annotation */
            if let pinAnnotationView = mapView.dequeueReusableAnnotationViewWithIdentifier(pinId) as? MKPinAnnotationView {
                
                pinAnnotationView.annotation = annotation
                annotationViewToReturn = pinAnnotationView
                
            } else {
                /* If new annotation view, configure and return */
                annotationViewToReturn = MKPinAnnotationView(annotation: annotation, reuseIdentifier: pinId)
                annotationViewToReturn.animatesDrop = true
                annotationViewToReturn.enabled = false
                annotationViewToReturn.canShowCallout = false
            }
            return annotationViewToReturn
        }
        return nil
    }
    
    func centerMapOnLocation(forPin pin: Pin) {
        
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(pin.coordinate, regionRadius * 20.0, regionRadius * 20.0)
        mapView.setRegion(coordinateRegion, animated: false)
        
    }
}

