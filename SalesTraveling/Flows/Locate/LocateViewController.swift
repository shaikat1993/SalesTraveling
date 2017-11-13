//
//  LocateViewController.swift
//  SalesTraveling
//
//  Created by Hanyu on 2017/10/22.
//  Copyright © 2017年 Hanyu. All rights reserved.
//

import UIKit
import MapKit

protocol LocateViewControllerProtocol {
	func locateViewController(_ locateViewController: LocateViewController, didSelect placemark: MKPlacemark)
}

class LocateViewController: UIViewController {
	let locationManager = CLLocationManager()
	lazy var addressResultTableViewController = makeAddressResultTableViewController()
	var searchController: UISearchController!
	var delegate: LocateViewControllerProtocol?
	var selectedPlacemark: MKPlacemark?
	var tappedPoint: CGPoint?
	
	@IBOutlet weak var mapView: MKMapView!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		setupLocationManager()
		setupUISearchController()
		setupSingleTapRecognizer()
	}
	
	@IBAction func barButtonItemCloseDidPressed(_ sender: Any) {
		if let navigationController = navigationController {
			navigationController.dismiss(animated: true, completion: nil)
		}
	}
}

//MARK: - Private API
extension LocateViewController {
	fileprivate func makeAddressResultTableViewController() -> AddressResultTableViewController {
		guard let vc = UIStoryboard.init(name: "Locate", bundle: nil).instantiateViewController(withIdentifier: "AddressResultTableViewController") as? AddressResultTableViewController else {
				fatalError("AddressResultTableViewController doesn't exist")
		}
		vc.delegate = self
		vc.mapView = mapView
		return vc
	}

	fileprivate func setupLocationManager() {
		locationManager.delegate = self
		locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
		locationManager.requestWhenInUseAuthorization()
		locationManager.requestLocation()
	}
	
	fileprivate func setupUISearchController() {
		searchController = UISearchController(searchResultsController: addressResultTableViewController)
		searchController.searchResultsUpdater = addressResultTableViewController
		
		let searchBar = searchController.searchBar
		searchBar.sizeToFit()
		searchBar.placeholder = "Search"
		navigationItem.titleView = searchController.searchBar
		
		searchController.hidesNavigationBarDuringPresentation = false
		searchController.dimsBackgroundDuringPresentation = true
		definesPresentationContext = true
	}
	
	fileprivate func setupSingleTapRecognizer() {
		let singleTapRecognizer = UITapGestureRecognizer.init(target: self, action: #selector(tapMap))
		singleTapRecognizer.numberOfTapsRequired = 1
		singleTapRecognizer.numberOfTouchesRequired = 1
		singleTapRecognizer.delaysTouchesBegan = true
		singleTapRecognizer.delegate = self
		mapView.addGestureRecognizer(singleTapRecognizer)
	}
	
	@objc func tapMap(sender: Any) {
		if let recognizer = sender as? UITapGestureRecognizer {
			tappedPoint = recognizer.location(in: view)
			//Call deselect annotation
		}
	}
	
	fileprivate func addAnnotation(_ coordinate: CLLocationCoordinate2D) {
		MapMananger.reverseCoordinate(coordinate, completion: { (status) in
			switch status {
			case .success(let placemarks):
				if let placemark = placemarks.first {
					self.selectedPlacemark = placemark
					self.mapView.removeAnnotations(self.mapView.annotations)
					let newAnnotation = MapMananger.pointAnnotation(placemark: placemark)
					self.mapView.addAnnotation(newAnnotation)
					self.mapView.selectAnnotation(newAnnotation, animated: true)
				}
				break
			case .failure(let error):
				print("reverseCoordinate: \(error)")
				break
			}
		})
	}
}

//MARK: - CLLocationManagerDelegate
extension LocateViewController: CLLocationManagerDelegate {
	private func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
		if status != .authorizedWhenInUse {
			manager.requestLocation()
		}
	}
	
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		//required
	}
	
	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		print("manager didFailWithError: \(error)")
	}
}

//MARK: - MKMapViewDelegate
extension LocateViewController: MKMapViewDelegate {
	func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
		if let _ = selectedPlacemark {
			return
		}

		MapMananger.showRegion(mapView, spanDegrees: 0.01, coordinate: userLocation.coordinate)
		addAnnotation(userLocation.coordinate)
	}
	
	func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
		if annotation is MKUserLocation {
			return nil
		}
		let reuseId = "pin"
		var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
		pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
		pinView?.pinTintColor = .orange
		pinView?.canShowCallout = true
		pinView?.animatesDrop = false
		pinView?.isDraggable = true
		pinView?.rightCalloutAccessoryView = UIButton.init(type: .contactAdd)
		return pinView
	}
	
	func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
		switch newState {
		case .ending:
			view.dragState = .none
			if let annotation = view.annotation {
				addAnnotation(annotation.coordinate)
			}
			break
		default:
			break
		}
	}
	
	func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
		if let selectedPlacemark = selectedPlacemark,
			let delegate = delegate {
			delegate.locateViewController(self, didSelect: selectedPlacemark)
			dismiss(animated: true, completion: nil)
		}
	}
	
	func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
		if let point = tappedPoint {
			let coordinateTapped = mapView.convert(point, toCoordinateFrom: self.view)
			addAnnotation(coordinateTapped)
			tappedPoint = nil
		}
	}
}

//MARK: - AddressResultTableViewControllerProtocol
extension LocateViewController: AddressResultTableViewControllerProtocol {
	func addressResultTableViewController(_ addressResultTableViewController: AddressResultTableViewController, placemark: MKPlacemark) {
		selectedPlacemark = placemark
		
		let annotation = MapMananger.pointAnnotation(placemark: placemark)
		mapView.removeAnnotations(mapView.annotations)
		mapView.addAnnotation(annotation)
		mapView.selectAnnotation(annotation, animated: true)
		
		MapMananger.showRegion(mapView, spanDegrees: 0.01, coordinate: placemark.coordinate)
	}
}

//MAKR: - UIGestureRecognizerDelegate
extension LocateViewController: UIGestureRecognizerDelegate {
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		if touch.view is MKPinAnnotationView {
			print("false")
			return false
		}
		print("true")
		return true
	}
}