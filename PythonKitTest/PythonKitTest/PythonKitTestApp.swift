//
//  PythonKitTestApp.swift
//  PythonKitTest
//
//  Created by skia on 2021/12/06.
//

import SceneKit
import SwiftUI

import NumPySupport
import Open3DSupport
import PythonKit
import PythonSupport

import LinkPython

@main
struct PythonKitTestApp: App {
    @StateObject var model = Model()
    
    var body: some Scene {
        WindowGroup {
            SceneView(scene: model.scene, options: [.allowsCameraControl])
                .onAppear(perform: {
                    model.set()
                })
        }
    }
    
    init() {
        PythonSupport.initialize()
        Open3DSupport.sitePackagesURL.insertPythonPath()
        NumPySupport.sitePackagesURL.insertPythonPath()
    }
}

class Model: ObservableObject {
    var scene = makeScene()
    var tstate: UnsafeMutableRawPointer?
    
    func set() {
        let o3d = Python.import("open3d")
        let np = Python.import("numpy")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let gstate = PyGILState_Ensure()
            defer {
                DispatchQueue.main.async {
                    guard let tstate = self.tstate else { fatalError() }
                    PyEval_RestoreThread(tstate)
                    self.tstate = nil
                }
                PyGILState_Release(gstate)
            }

            let url = Bundle.main.url(forResource: "scene",
                                      withExtension: "ply")!
            let pcd = o3d.io.read_point_cloud(url.path)
        
            let points = np.asarray(pcd.points)
            let vertices = points.map { point in
                SCNVector3(Float(point[0])!, Float(point[1])!, Float(point[2])!)
            }
            let geometrySource = SCNGeometrySource(vertices: vertices)
            let indices: [CInt] = Array(0 ..< CInt(vertices.count))
            let geometryElement = SCNGeometryElement(indices: indices, primitiveType: .point)
            let geometry = SCNGeometry(sources: [geometrySource], elements: [geometryElement])
            let node = SCNNode(geometry: geometry)
            node.geometry?.firstMaterial!.diffuse.contents = UIColor.red
            self.scene.rootNode.addChildNode(node)
                    
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            self.scene.rootNode.addChildNode(cameraNode)
            cameraNode.position = SCNVector3Make(0, 0, 1)
            cameraNode.look(at: node.geometry!.boundingSphere.center)
        }
        
        tstate = PyEval_SaveThread()
    }
    
    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        
        // create and add a light to the scene
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)
        
        return scene
    }
}
