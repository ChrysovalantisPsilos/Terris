//
//  GlobeViewModel.swift
//  Terris
//

import Foundation
import SceneKit
import SwiftUI
import CoreData
import Observation

@Observable
final class GlobeViewModel {
    var selectedCountry: Country?
    var statusFilter: TravelStatus? = nil  // nil = show all

    // Map isoCode → SCNNode for fast lookup
    var countryNodes: [String: SCNNode] = [:]

    func selectCountry(_ country: Country?) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedCountry = country
        }
    }

    func color(for country: Country) -> UIColor {
        let status = TravelStatus(rawValue: country.status) ?? .none
        return status.globeColor
    }

    func updateNode(for country: Country) {
        guard let iso = country.isoCode,
              let node = countryNodes[iso] else { return }
        let color = self.color(for: country)
        node.geometry?.firstMaterial?.diffuse.contents = color
        // Pulse animation on status change
        let pulse = SCNAction.sequence([
            SCNAction.scale(to: 1.05, duration: 0.15),
            SCNAction.scale(to: 1.0, duration: 0.15)
        ])
        node.runAction(pulse)
    }

    func highlightNode(isoCode: String, highlighted: Bool) {
        guard let node = countryNodes[isoCode] else { return }
        let scale: CGFloat = highlighted ? 1.04 : 1.0
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.2
        node.scale = SCNVector3(scale, scale, scale)
        SCNTransaction.commit()
    }
}
