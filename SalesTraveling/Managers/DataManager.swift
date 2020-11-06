//
//  DataManager.swift
//  SalesTraveling
//
//  Created by Ryan on 2017/11/26.
//  Copyright © 2017年 Hanyu. All rights reserved.
//

import Foundation
import MapKit

class DataManager {
	
	static let shared = DataManager()
	
	//calculateDirections(from source: HYCPlacemark, to destination: HYCPlacemark, completion: @escaping (_ result: Result<[MKRoute], Error>) -> Void)
	typealias Fetcher = (HYCPlacemark, HYCPlacemark, (@escaping (Result<[MKRoute], Error>) -> Void)) -> Void
	let fetcher: Fetcher
	
	init(fetcher: @escaping Fetcher = MapMananger.calculateDirections) {
		self.fetcher = fetcher
	}
}

// MARK: - Direction
extension DataManager {
	
	func save(direction: DirectionModel) {
		do {
			let data = try JSONEncoder().encode(direction)
			let key = createKeyBy(source: direction.source, destination: direction.destination)
			UserDefaults.standard.set(data, forKey: key)
		} catch {
			print("Cant save direction with \(error)")
		}
	}

	func save(directions: [DirectionModel]) {
		for directionModel in directions {
			save(direction: directionModel)
		}
	}
	
	func findDirection(source: HYCPlacemark, destination: HYCPlacemark) -> DirectionModel? {
		let key = createKeyBy(source: source, destination: destination)
		guard let data = UserDefaults.standard.object(forKey: key) as? Data,
			let direction = try? JSONDecoder().decode(DirectionModel.self, from: data) else { return nil }
		return direction
	}
}

// MARK: - HYCPlacemark
extension DataManager {

	private func createKeyBy(source: HYCPlacemark, destination: HYCPlacemark) -> String {
		return "\(source.coordinate.latitude),\(source.coordinate.longitude) - \(destination.coordinate.latitude),\(destination.coordinate.longitude)"
	}
	
	func fetchDirections(
		ofNew placemark: HYCPlacemark,
		toOld placemarks: [HYCPlacemark],
		current userPlacemark: HYCPlacemark?,
		completeBlock: @escaping (Result<[DirectionModel], Error>) -> Void) {
		let resultsQueue = DispatchQueue(label: "directionsModelsQueue")
		var results = [Result<DirectionModel, Error>]()
		
		//User -> New
		//New -> Old1
		//Old1 -> New
		//New -> Old2
		//Old2 -> New
		
		var tours = [(source: HYCPlacemark, destination: HYCPlacemark)]()
		
		if let userPlacemark = userPlacemark {
			tours.append((userPlacemark, placemark))
		}
		
		for oldPlacemark in placemarks {
			tours.append((oldPlacemark, placemark))
			tours.append((placemark, oldPlacemark))
		}
		
		fetch(tours: tours, completeBlock: completeBlock)
	}
	
	private func fetch(tours: [(source: HYCPlacemark, destination: HYCPlacemark)], acc: [DirectionModel] = [], completeBlock: @escaping (Result<[DirectionModel], Error>) -> Void) {
		guard let (source, destination) = tours.first else {
			return completeBlock(.success(acc))
		}
		
		fetcher(source, destination, { [weak self] (state) in
			guard let self = self else { return }
			switch state {
			case .failure(let error):
				completeBlock(.failure(error))
			case .success(let response):
				let directions = DirectionModel(source: source, destination: destination, routes: response)
				self.fetch(tours: Array(tours.dropFirst()), acc: acc + [directions], completeBlock: completeBlock)
			}
		})
	}
}

// MARK: - Favorite placemark
extension DataManager {
	
	func addToFavorites(placemark: HYCPlacemark) throws {
		do {
			try addToFavorites(placemarks: [placemark])
		} catch {
			throw error
		}
	}
	
	func addToFavorites(placemarks: [HYCPlacemark]) throws {
		var favorites = favoritePlacemarks()
		placemarks.forEach { (placemark) in
			favorites.insert(placemark)
		}
		do {
			let data = try JSONEncoder().encode(favorites)
			let key = UserDefaults.Keys.FavoritePlacemarks
			UserDefaults.standard.set(data, forKey: key)
		} catch {
			throw error
		}
	}
	
	func favoritePlacemarks() -> Set<HYCPlacemark> {
		let key = UserDefaults.Keys.FavoritePlacemarks
		guard
			let data = UserDefaults.standard.object(forKey: key) as? Data,
			let placemarks = try? JSONDecoder().decode(Set<HYCPlacemark>.self, from: data)
			else {
				return Set<HYCPlacemark>()
		}
		return placemarks
	}
}
