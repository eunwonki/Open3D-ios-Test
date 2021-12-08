//
//  API.swift
//  PythonKitTest
//
//  Created by skia on 2021/12/07.
//

import Foundation
import SceneKit
import SceneKit.ModelIO

import LinkPython
import NumPySupport
import Open3DSupport
import PythonKit
import PythonSupport

var tstate: UnsafeMutableRawPointer?
var o3d: PythonObject!
var np: PythonObject!

func node(filename: String, withExtension: String) -> SCNNode {
    let url = Bundle.main.url(forResource: filename,
                              withExtension: withExtension)!
    let asset = MDLAsset(url: url).object(at: 0)
    let mesh = asset as! MDLMesh

    return SCNNode(geometry: SCNGeometry(mdlMesh: mesh))
}

func pythonInit() {
    PythonSupport.initialize()
    Open3DSupport.sitePackagesURL.insertPythonPath()
    NumPySupport.sitePackagesURL.insertPythonPath()

    o3d = Python.import("open3d")
    np = Python.import("numpy")
}

// I don't know why they implement like this in example???
// https://github.com/kewlbear/Open3D-iOS
// It likes Semaphore???
// But It works well, without this process
func example() {
    DispatchQueue.global(qos: .userInitiated).async {
//        let gstate = PyGILState_Ensure()
//        defer {
//            DispatchQueue.main.async {
//                guard let state = tstate else { fatalError() }
//                PyEval_RestoreThread(state)
//                tstate = nil
//            }
//            PyGILState_Release(gstate)
//        }

        // do anything
    }

    tstate = PyEval_SaveThread()
}

func pcd(filename: String, withExtension: String) -> PythonObject {
    let url = Bundle.main.url(forResource: filename,
                              withExtension: withExtension)!
    let pcd = o3d.io.read_point_cloud(url.path)
    return pcd
}

func pcd2Node(pcd: PythonObject) -> SCNNode {
    let points = np.asarray(pcd.points)
    let vertices = points.map { point in
        SCNVector3(Float(point[0])!, Float(point[1])!, Float(point[2])!)
    }
    let geometrySource = SCNGeometrySource(vertices: vertices)
    let indices: [CInt] = Array(0 ..< CInt(vertices.count))
    let geometryElement = SCNGeometryElement(indices: indices, primitiveType: .point)
    let geometry = SCNGeometry(sources: [geometrySource], elements: [geometryElement])
    let node = SCNNode(geometry: geometry)
    node.geometry?.firstMaterial?.diffuse.contents = UIColor.red
    return node
}

func preprocessPointCloud(pcd: PythonObject, voxelSize: Double)
    -> (pcdDown: PythonObject, pcdFpfh: PythonObject)
{
    let pcdDown = pcd.voxel_down_sample(voxelSize)
    let radius_normal = voxelSize * 2

    pcdDown.estimate_normals(o3d.geometry.KDTreeSearchParamHybrid(radius: radius_normal, max_nn: 30))

    let radius_feature = voxelSize * 5
    let kdParam = o3d.geometry.KDTreeSearchParamHybrid(radius: radius_feature, max_nn: 100)
    let pcdFpfh = o3d.pipelines.registration.compute_fpfh_feature(pcdDown, kdParam)

    return (pcdDown, pcdFpfh)
}

func globalRegistration(source: PythonObject,
                        target: PythonObject,
                        sourceFpfh: PythonObject,
                        targetFpfh: PythonObject,
                        voxelSize: Double) -> PythonObject
{
    let distanceThreshold = voxelSize * 1.5

    let result = o3d.pipelines.registration.registration_ransac_based_on_feature_matching(
        source, target, sourceFpfh, targetFpfh,
        true, distanceThreshold,
        o3d.pipelines.registration.TransformationEstimationPointToPoint(false), 3,
        [
            o3d.pipelines.registration.CorrespondenceCheckerBasedOnEdgeLength(0.9),
            o3d.pipelines.registration.CorrespondenceCheckerBasedOnDistance(distanceThreshold)
        ],
        o3d.pipelines.registration.RANSACConvergenceCriteria(100000, 0.999)
    )

    print("global registration result")
    print("fitness: \(result.fitness)")
    print("inlier_rmse: \(result.inlier_rmse)")
    print("num_of_correspondence: \(result.correspondence_set)")
    print("transformation: \(result.transformation)")

    return result
}
