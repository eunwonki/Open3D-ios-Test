//
//  ContentView.swift
//  PythonKitTest
//
//  Created by skia on 2021/12/06.
//

import SwiftUI
import SceneKit

struct ContentView: View {
    @StateObject var model = Model()
    
    var body: some View {
        SceneView(scene: model.scene, options: [.allowsCameraControl])
            .onAppear(perform: {
                model.set()
            })
        Button(action: model.original)
        {
            Text("original")
                .background(Color.purple)
                .font(.title)
                .padding()
        }
        Button(action: model.globalRegister)
        {
            Text("global register")
                .background(Color.purple)
                .font(.title)
                .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
