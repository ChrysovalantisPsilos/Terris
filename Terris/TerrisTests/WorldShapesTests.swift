//
//  WorldShapesTests.swift
//  TerrisTests
//

import Foundation
import Testing
@testable import Terris

@MainActor
struct WorldShapesTests {
    @Test func bundledShapesLoadWithIsoCodes() {
        let world = WorldShapes.shared
        #expect(world.shapes.count > 150)
        #expect(world.byISO["JP"] != nil)
        #expect(world.byISO["GR"] != nil)
    }

    @Test func minus99CountriesAreMatchedByName() {
        #expect(WorldShapes.shared.byISO["FR"] != nil)
        #expect(WorldShapes.shared.byISO["NO"] != nil)
    }

    @Test func smallCountriesStillHaveACentroid() {
        // Singapore has no outline in the dataset; it's drawn as a dot.
        #expect(WorldShapes.shared.byISO["SG"] == nil)
        #expect(WorldShapes.shared.centroid(of: "SG") != nil)
    }

    @Test func parsesPolygonsAndMultiPolygons() {
        let json = """
        {"type":"FeatureCollection","features":[
          {"type":"Feature","properties":{"ISO_A2":"AA","name":"A"},
           "geometry":{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,0]]]}},
          {"type":"Feature","properties":{"ISO_A2":"-99","name":"France"},
           "geometry":{"type":"MultiPolygon","coordinates":[[[[2,2],[3,2],[3,3],[2,2]]],[[[5,5],[6,5],[6,6],[5,5]]]]}}
        ]}
        """
        let world = WorldShapes(data: Data(json.utf8))
        #expect(world.byISO["AA"]?.rings.count == 1)
        #expect(world.byISO["FR"]?.rings.count == 2)
    }
}
