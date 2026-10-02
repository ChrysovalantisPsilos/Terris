//
//  MapModel.swift
//  Terris
//

import Foundation
import Observation

@MainActor
@Observable
final class MapModel {
    private(set) var figures: MapFigures
    private let store: FootprintStore

    init(store: FootprintStore) {
        self.store = store
        self.figures = MapFigures.compute(records: [], catalog: store.catalog)
    }

    func load() {
        figures = MapFigures.compute(records: store.countryRecords(), catalog: store.catalog)
    }
}
