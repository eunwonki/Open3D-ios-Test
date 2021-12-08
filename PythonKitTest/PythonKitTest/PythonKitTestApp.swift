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
    
    let voxelSize: Double = 0.005
    
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
            print(matrix.m)
        }
    }
    
    func set() {
        targetPc = pcd(filename: "scene", withExtension: "ply")
        target = pcd2Node(pcd: targetPc)
        target.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        
        sourcePc = pcd(filename: "model", withExtension: "ply")
        let original = pcd2Node(pcd: sourcePc)
        original.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        
        // 이유는 모르겠지만 이 회전 변환을 해줘야만 더 많은 Correspondence를 얻을 수 있음...
        let transInit = np.asarray([[0.0, 0.0, 1.0, 0.0],
                                    [1.0, 0.0, 0.0, 0.0],
                                    [0.0, 1.0, 0.0, 0.0],
                                    [0.0, 0.0, 0.0, 1.0]])
        sourcePc.transform(transInit)
        source = pcd2Node(pcd: sourcePc)
        source.geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
        
        scene.rootNode.addChildNode(original)
        scene.rootNode.addChildNode(target)
        scene.rootNode.addChildNode(source)
        
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
        scene.rootNode.addChildNode(cameraNode)
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
