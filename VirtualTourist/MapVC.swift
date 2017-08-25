//
//  MapVC.swift
//  VirtualTourist
//
//  Created by Yeontae Kim on 7/19/17.
//  Copyright © 2017 YTK. All rights reserved.
//

import UIKit
import Foundation
import MapKit
import CoreData

class MapVC: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    var store: PhotoStore!
    var pin: Pin?
    let activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
    var annotations = [PinAnnotation]()
    var longPressGesture: UILongPressGestureRecognizer? = nil
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up gestures and add
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(addAnnotation))
        addLongPressGesture()
        
        // Set up activity indicator
        activityIndicator.center = CGPoint(x: mapView.frame.size.width / 2, y: mapView.frame.size.height / 2)
        activityIndicator.color = UIColor.lightGray
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
        view.addSubview(activityIndicator)
        
        // Fetching all pins
        fetchAllPins()
        
    }
    
    // Fetch all saved pins with annotation
    
    func fetchAllPins() {
        
        self.mapView.delegate = self
        
        var fetchedPins = [Pin]()
        
        store.fetchAllPins() { (pinsResult) in
            
            switch pinsResult {
            case let .success(pins):
                
                fetchedPins = pins
                
                if fetchedPins.count > 0 {
                    
                    var annotations = [PinAnnotation]()
                    
                    for pin in fetchedPins {
                        
                        let pinAnnotation = pin.getPinAnnotationsFromPin(pin: pin)
                        annotations.append(pinAnnotation)
                        
                    }
                    
                    performUIUpdatesOnMain {
                        self.mapView.addAnnotations(annotations)
                        print(self.mapView.annotations)
                    }
                    print("all pins fetched")
                    
                } else {
                    print("Nothing to fetch")
                }
                
            case .failure(_):
                fetchedPins = []
            }
        }

    }
    
    // MARK: Save Pin when created by gesture
    
    func savePin(latitude: Double, longitude: Double) {
        
        mapView.delegate = self
        
        let moc = store.persistentContainer.viewContext
        
        moc.perform {
            let pin = Pin(context: moc) // create an instance of NSManagedObejct
            pin.latitude = latitude
            pin.longitude = longitude
            pin.pinID = UUID().uuidString
            
            do {
                try moc.save()
            } catch {
                moc.rollback()
            }

            let pinAnnotation = pin.getPinAnnotationsFromPin(pin: pin)
            self.mapView.addAnnotation(pinAnnotation)
            print("saved pin: ", pin)
        }

    }
    
    func addAnnotation(gestureRecognizer:UIGestureRecognizer){
        
        self.mapView.delegate = self
        
        if gestureRecognizer.state == .ended {
            
            let touchPoint = gestureRecognizer.location(in: mapView)
            let newCoordinates = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            
            let lat = newCoordinates.latitude
            let lon = newCoordinates.longitude
            
            savePin(latitude: lat, longitude: lon)
            
        }
    }
    
    func addLongPressGesture() {
        self.longPressGesture?.minimumPressDuration = 0.5
        self.mapView.addGestureRecognizer(self.longPressGesture!)
    }
  
    
    // MARK: Map View
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        if annotation is PinAnnotation {
            
            print("Any annotation for the map view??")
            
            var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
            
            if pinView == nil {
                
                pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                pinView!.canShowCallout = true
                pinView!.isDraggable = true
                pinView!.pinTintColor = .red
                pinView!.frame.size.height = 30
                
                // Button to lead to the photo album
                let arrowButton = UIButton(type: .custom)
                arrowButton.frame.size.width = 25
                arrowButton.frame.size.height = 25
                arrowButton.setImage(UIImage(named: "icons8-Forward Filled-50"), for: .normal)
                pinView!.rightCalloutAccessoryView = arrowButton
                
                // Button to delete the pin annotation
                let deleteButton = UIButton(type: .custom)
                deleteButton.backgroundColor = UIColor.red
                deleteButton.frame.size.width = 50
                deleteButton.frame.size.height = 50
                deleteButton.setImage(UIImage(named: "Trash"), for: .normal)
                pinView!.leftCalloutAccessoryView = deleteButton
            
            } else {
                pinView!.annotation = annotation
            }
        
            return pinView
            
        } else {
            return nil
        }
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        if control == view.leftCalloutAccessoryView  { // Delete Button Tapped
            
            if let annotation = view.annotation as? PinAnnotation {

                let fetchRequest: NSFetchRequest<Pin> = Pin.fetchRequest()
                let predicate = NSPredicate(format: "\(#keyPath(Pin.pinID)) == %@", annotation.id!)
                fetchRequest.predicate = predicate
                
                let moc = self.store.persistentContainer.viewContext
                
                moc.performAndWait {
                    let fetchedPins = try? fetchRequest.execute()
                    
                    if let selectedPin = fetchedPins?.first {
                        self.pin = nil
                        print(selectedPin)
                        // self.mapView.removeAnnotation(annotation)
                        moc.delete(selectedPin)
                        mapView.removeAnnotation(annotation)
                    }
                
                }
                    
                do {
                    try moc.save()
                } catch {
                    print("Error to save")
                }
            }
            
        } else { // Right Button Tapped to Go to PhotoAlbumVC
            
            if let annotation = view.annotation as? PinAnnotation {

               let fetchRequest: NSFetchRequest<Pin> = Pin.fetchRequest()
                let predicate = NSPredicate(format: "\(#keyPath(Pin.pinID)) == %@", annotation.id!)
                fetchRequest.predicate = predicate
            
                let moc = self.store.persistentContainer.viewContext
            
                // Get the selected pin information for PhotoAlbumV
                var fetchedPins: [Pin]?
                moc.performAndWait {
                    fetchedPins = try? fetchRequest.execute()
                }
                
                if let selectedPin = fetchedPins?.first {
                    self.pin = selectedPin
                    print("selectedPin: ", self.pin!)
                }
                
                performSegue(withIdentifier: "photoAlbumVC", sender: self)
            }
        }

    }
    
    
    // MARK: Segue
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        //Notice that this code works for both Scissors and Paper
        if segue.identifier == "photoAlbumVC" {
            if let controller = segue.destination as? PhotoAlbumVC {
                controller.store = self.store
                controller.moc = self.store.persistentContainer.viewContext
                controller.pin = self.pin!
                print("self.pin in MapVC: ", self.pin)
            }
            
        }
    }
    
}


// MARK: Custom Pin Annotation

class PinAnnotation : NSObject, MKAnnotation {
    private var coord: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    private var pinAnnotations = [PinAnnotation]()
    
    var coordinate: CLLocationCoordinate2D {
        get {
            return coord
        }
    }
    
    var id: String?
    var title: String?
    
    func setCoordinate(newCoordinate: CLLocationCoordinate2D) {
        self.coord = newCoordinate
    }
    
}

