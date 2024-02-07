//
//  GuidingLite_UWB.swift
//  Qorvo Nearby Interaction
//
//  Created by Ryan Mah on 2024-02-06.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import NearbyInteraction
import ARKit
import RealityKit

enum NI_Messages: UInt8
{
    // Messages from the accessory.
    case accessoryConfigurationData = 0x1
    case accessoryUwbDidStart = 0x2
    case accessoryUwbDidStop = 0x3
    
    // Messages to the accessory.
    case initialize = 0xA
    case configureAndStart = 0xB
    case stop = 0xC
    
    // User defined/notification messages
    case getReserved = 0x20
    case setReserved = 0x21

    case iOSNotify = 0x2F
}

class GuidingLite_UWBManager : NSObject, NISessionDelegate, ARSessionDelegate
{
    // The AR Session to be shared with all devices, to enable camera assistance
    @IBOutlet weak var arView: ARView!
    let arConfig = ARWorldTrackingConfiguration()
    let anchor = AnchorEntity(world: SIMD3(x: 0, y: 0, z: 0))

    var entityDict = [Int:ModelEntity]()
    let pinShape = MeshResource.generateSphere(radius: 0.05)
    let material = SimpleMaterial(color: .yellow, isMetallic: false)

    var sessions_dict = [Int: NISession]()

    var ble: DataCommunicationChannel = DataCommunicationChannel()

    func initialize()
    {
        // ble.accessoryDiscoveryHandler = 
    }

    // func _ble_

    func _ble_send_data(_ data: Data, _ aid: Int)
    {
        do
        {
            try self.ble.sendData(data, aid)
        }
        catch
        {
            print("Error sending data to accessory \(aid)")
        }
    }

    func start_uwb_session(aid: Int)
    {
        // Create an NI session for the device
        self.sessions_dict[aid] = NISession()
        self.sessions_dict[aid]?.delegate = self
        self.sessions_dict[aid]?.setARSession(arView.session)

        // Also creates the AR object
        self.entityDict[aid] = ModelEntity(mesh: pinShape, materials: [material])
        self.entityDict[aid]!.position = [0, 0, 100]
        self.anchor.addChild(entityDict[aid]!)

        // Start config info exchange
//        self._send_data( Data([ NI_Messages.initialize.rawValue ]), aid )
    }

}
