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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    init() {
        pythonInit()
    }
}

class Model: ObservableObject {
    var scene = makeScene()
    
    var target: SCNNode!
    var source: SCNNode!
    
    var targetPc: PythonObject!
    var sourcePc: PythonObject!
    
    var targetPcDownSampled: PythonObject!
    var sourcePcDownSampled: PythonObject!
    
    var targetPcFpfh: PythonObject!
    var sourcePcFpfh: PythonObject!
    
    let voxelSize: Float = 0.005
    
    func original() {
        source.transform = SCNMatrix4Identity
    }
    
    func globalRegister() {
        let result = globalRegistration(source: sourcePcDownSampled,
                                        target: targetPcDownSampled,
                                        sourceFpfh: sourcePcFpfh,
                                        targetFpfh: targetPcFpfh,
                                        voxelSize: voxelSize)
        
        var m: [Float] = []
        _ = np.asarray(result.transformation).map { ma in
            _ = np.asarray(ma).map { mb in
                m.append(Float(mb)!)
            }
        }
        
        m.withUnsafeMutableBytes { ptr in
            var matrix = GLKMatrix4MakeWithArray(ptr.baseAddress?.assumingMemoryBound(to: Float.self))
            matrix = GLKMatrix4Transpose(matrix)
            source.transform = SCNMatrix4FromGLKMatrix4(matrix)
        }
    }
    
    func set() {
        targetPc = pcd(filename: "scene", withExtension: "ply")
        target = node(filename: "scene", withExtension: "ply")
        target.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        sourcePc = pcd(filename: "model", withExtension: "ply")
        source = node(filename: "model", withExtension: "ply")
        source.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
        
        self.scene.rootNode.addChildNode(target)
        self.scene.rootNode.addChildNode(source)
        
        setCamera(target: target)
        
        (targetPcDownSampled,
             targetPcFpfh) = preprocessPointCloud(pcd: targetPc,
                                                  voxelSize: voxelSize)
        (sourcePcDownSampled,
             sourcePcFpfh) = preprocessPointCloud(pcd: sourcePc,
                                                  voxelSize: voxelSize)
    }
    
    func setCamera(target: SCNNode) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        self.scene.rootNode.addChildNode(cameraNode)
        cameraNode.position = SCNVector3Make(0, 0, 1)
        cameraNode.look(at: target.geometry!.boundingSphere.center)
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 5.0
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
