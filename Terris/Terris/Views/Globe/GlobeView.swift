//
//  GlobeView.swift
//  Terris
//
//  Interactive 3D SceneKit globe.
//  Countries are rendered as coloured overlays on the sphere surface using
//  a flat 2D Canvas texture that maps ISO codes to TravelStatus colours.
//

import SwiftUI
import SceneKit
import CoreData

// MARK: - SceneKit wrapper

struct GlobeView: UIViewRepresentable {
    var viewModel: GlobeViewModel
    let countries: [Country]

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = buildScene(coordinator: context.coordinator)
        scnView.backgroundColor = UIColor(red: 0.05, green: 0.10, blue: 0.16, alpha: 1) // deep ocean
        scnView.allowsCameraControl = true
        scnView.antialiasingMode = .multisampling4X
        scnView.isTemporalAntialiasingEnabled = true
        scnView.autoenablesDefaultLighting = false

        // Tap recognizer
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                        action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)
        context.coordinator.scnView = scnView

        // Slow auto-rotation
        scnView.scene?.rootNode.runAction(
            SCNAction.repeatForever(
                SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 120)
            ),
            forKey: "autoRotate"
        )

        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        // Refresh country colours when data changes
        for country in countries {
            guard let iso = country.isoCode else { continue }
            if let node = viewModel.countryNodes[iso] {
                let color = viewModel.color(for: country)
                node.geometry?.firstMaterial?.diffuse.contents = color
            }
        }
    }

    // MARK: - Scene construction

    private func buildScene(coordinator: Coordinator) -> SCNScene {
        let scene = SCNScene()

        // Ocean sphere
        let sphere = SCNSphere(radius: 1.0)
        sphere.segmentCount = 96
        let oceanMat = SCNMaterial()
        oceanMat.diffuse.contents = UIColor(red: 0.07, green: 0.15, blue: 0.25, alpha: 1)
        oceanMat.specular.contents = UIColor(white: 0.3, alpha: 1)
        oceanMat.shininess = 40
        sphere.materials = [oceanMat]
        let globeNode = SCNNode(geometry: sphere)
        globeNode.name = "globe"
        scene.rootNode.addChildNode(globeNode)
        coordinator.globeNode = globeNode

        // Atmosphere glow
        let atmosphereSphere = SCNSphere(radius: 1.02)
        let atmosphereMat = SCNMaterial()
        atmosphereMat.diffuse.contents = UIColor.clear
        atmosphereMat.emission.contents = UIColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 0.08)
        atmosphereMat.isDoubleSided = true
        atmosphereSphere.materials = [atmosphereMat]
        let atmosphereNode = SCNNode(geometry: atmosphereSphere)
        scene.rootNode.addChildNode(atmosphereNode)

        // Grid lines overlay
        let gridSphere = SCNSphere(radius: 1.001)
        let gridMat = SCNMaterial()
        if let gridImage = makeGridTexture(size: 1024) {
            gridMat.diffuse.contents = gridImage
            gridMat.transparent.contents = gridImage
        }
        gridMat.isDoubleSided = false
        gridMat.blendMode = .alpha
        gridSphere.materials = [gridMat]
        let gridNode = SCNNode(geometry: gridSphere)
        scene.rootNode.addChildNode(gridNode)

        // Country overlay nodes (flat coloured caps on sphere)
        buildCountryNodes(on: globeNode, coordinator: coordinator)

        // Lighting
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(white: 0.25, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.color = UIColor(white: 0.9, alpha: 1)
        directionalLight.castsShadow = false
        let lightNode = SCNNode()
        lightNode.light = directionalLight
        lightNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(lightNode)

        // Camera
        let camera = SCNCamera()
        camera.fieldOfView = 60
        camera.zNear = 0.1
        camera.zFar = 100
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 2.8)
        scene.rootNode.addChildNode(cameraNode)

        return scene
    }

    // Render country circles as small sphere caps
    private func buildCountryNodes(on globeNode: SCNNode, coordinator: Coordinator) {
        // Use a precomputed lat/lon center for a representative set of countries.
        // Full polygon rendering requires GeoJSON parsing; this approach places
        // a coloured disc at the country centroid as a lightweight visual indicator.
        let centroids = CountryCentroids.all
        for country in countries {
            guard let iso = country.isoCode,
                  let centroid = centroids[iso] else { continue }

            let lat = centroid.0
            let lon = centroid.1

            // Convert lat/lon to 3D position on unit sphere
            let latR = Float(lat * Double.pi / 180)
            let lonR = Float(lon * Double.pi / 180)
            let x = cos(latR) * cos(lonR)
            let y = sin(latR)
            let z = -cos(latR) * sin(lonR)

            // Small flat circle (torus-free disc via SCNPlane mapped as sphere node)
            let disc = SCNSphere(radius: 0.048)
            disc.segmentCount = 24
            let mat = SCNMaterial()
            mat.diffuse.contents = viewModel.color(for: country)
            mat.lightingModel = .constant
            mat.isDoubleSided = true
            disc.materials = [mat]

            let node = SCNNode(geometry: disc)
            node.name = iso
            // Place on sphere surface
            node.position = SCNVector3(x * 1.002, y * 1.002, z * 1.002)
            // Orient disc to face outward from sphere centre
            node.look(at: SCNVector3(0, 0, 0), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))

            globeNode.addChildNode(node)
            viewModel.countryNodes[iso] = node
        }
    }

    // Procedural lat/lon grid texture
    private func makeGridTexture(size: Int) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.clear.cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: CGSize(width: size, height: size)))
            ctx.cgContext.setStrokeColor(UIColor(white: 1, alpha: 0.07).cgColor)
            ctx.cgContext.setLineWidth(0.5)
            // Latitude lines every 30°
            for lat in stride(from: -90, through: 90, by: 30) {
                let y = Int(Double(size) * (1 - (Double(lat + 90) / 180.0)))
                ctx.cgContext.move(to: CGPoint(x: 0, y: y))
                ctx.cgContext.addLine(to: CGPoint(x: size, y: y))
            }
            // Longitude lines every 30°
            for lon in stride(from: -180, through: 180, by: 30) {
                let x = Int(Double(size) * ((Double(lon + 180)) / 360.0))
                ctx.cgContext.move(to: CGPoint(x: x, y: 0))
                ctx.cgContext.addLine(to: CGPoint(x: x, y: size))
            }
            ctx.cgContext.strokePath()
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        let viewModel: GlobeViewModel
        weak var scnView: SCNView?
        var globeNode: SCNNode?
        private var lastHighlighted: String?

        init(viewModel: GlobeViewModel) {
            self.viewModel = viewModel
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView else { return }
            let pt = gesture.location(in: scnView)
            let hits = scnView.hitTest(pt, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue,
                .boundingBoxOnly: false
            ])
            // Find first hit that has a 2-letter name (ISO code)
            if let hit = hits.first(where: { ($0.node.name?.count ?? 0) == 2 }),
               let iso = hit.node.name {
                // Stop auto-rotation temporarily
                globeNode?.removeAction(forKey: "autoRotate")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.globeNode?.runAction(
                        SCNAction.repeatForever(
                            SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 120)
                        ),
                        forKey: "autoRotate"
                    )
                }
                // Unhighlight previous
                if let prev = lastHighlighted { viewModel.highlightNode(isoCode: prev, highlighted: false) }
                viewModel.highlightNode(isoCode: iso, highlighted: true)
                lastHighlighted = iso

                // Notify ViewModel on main actor
                Task { @MainActor in
                    // We need a managed object context to fetch — rely on notification center
                    NotificationCenter.default.post(
                        name: .globeCountryTapped,
                        object: nil,
                        userInfo: ["isoCode": iso]
                    )
                }
            } else {
                // Tap on ocean — deselect
                if let prev = lastHighlighted { viewModel.highlightNode(isoCode: prev, highlighted: false) }
                lastHighlighted = nil
                Task { @MainActor in
                    viewModel.selectCountry(nil)
                }
            }
        }
    }
}

extension Notification.Name {
    static let globeCountryTapped = Notification.Name("globeCountryTapped")
}
