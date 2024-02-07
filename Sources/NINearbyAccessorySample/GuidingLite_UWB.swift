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

class GuidingLite_UWBManager : NSObject
{
    var arView: ARView

    // The AR Session to be shared with all devices, to enable camera assistance
    let arConfig = ARWorldTrackingConfiguration()
    let anchor = AnchorEntity(world: SIMD3(x: 0, y: 0, z: 0))

    var entityDict = [Int:ModelEntity]()
    let pinShape = MeshResource.generateSphere(radius: 0.05)
    let material = SimpleMaterial(color: .yellow, isMetallic: false)

    var referenceDict = [Int: NISession]()

    var ble: DataCommunicationChannel = DataCommunicationChannel()

    var ni_configuration: NINearbyAccessoryConfiguration?

    var isConverged = false

    var anchor_data = [Int: AnchorData]()

    var anchor_connection_status = [Int:Bool]()

    init(arView: ARView)
    {
        self.arView = arView

        super.init()

        self.arView.session = ARSession()
        self.arView.session.delegate = self
        self.arView.session.run(arConfig)
        self.arView.scene.addAnchor(anchor)

        self.ble.accessoryDiscoveryHandler    = _ble_discovery_handler
        self.ble.accessoryTimeoutHandler      = _ble_timeout_handler
        self.ble.accessoryConnectedHandler    = _ble_connected_handler
        self.ble.accessoryDisconnectedHandler = _ble_disconnected_handler
        self.ble.accessoryDataHandler         = _ble_data_handler

        self.ble.start()
    }


    func _update_anchor_data(_ unique_hash: Int, _ aid: Int)
    {
        if (aid == -1)
        {
            return
        }
        
        let currentDevice = ble.getDeviceFromUniqueID(unique_hash)
        if  currentDevice == nil { return }
        
        // Get updated location values
        let distance  = currentDevice?.uwbLocation?.distance
        let direction = currentDevice?.uwbLocation?.direction
        
        let azimuthCheck = azimuth((currentDevice?.uwbLocation?.direction)!)
        
        // Check if azimuth check calcul is a number (ie: not infinite)
        if azimuthCheck.isNaN {
            return
        }
        
        var azimuth = 0
        if Settings().isDirectionEnable {
            azimuth =  Int( 90 * (Double(azimuthCheck)))
        }else {
            azimuth = Int(rad2deg(Double(azimuthCheck)))
        }
        

        let elevation = Int(90 * elevation(direction!))

        var isLOS = false
        if (currentDevice?.uwbLocation?.noUpdate)! {
            isLOS = false
        }
        else {
            isLOS = true
        }
        
        let telem_data = AnchorData( distance_m: distance!,
                                     azimuth_deg: Int16(azimuth),
                                     elevation_deg: Int16(elevation),
                                     los: isLOS )
        
        self.anchor_data[aid] = telem_data

        // print(aid)
        // print(telem_data)

        // DispatchQueue.global(qos: .userInteractive).async
        // {
        //     let telem_data_copy = telem_data
        //     let telem_bytes = TelemetryData_ToBytes(telem_data_copy)
            
        //     self.mqtt_client.publish_bytes( DATA_TOPIC_BASE + String(aid),
        //                                     telem_bytes )
        // }

    }


    func _setup_accessory( _ configData: Data,
                           _ name: String,
                           _ unique_hash: Int )
    {
        print("Received configuration data from '\(name)'. Running session.")

        do
        {
            self.ni_configuration = try NINearbyAccessoryConfiguration(data: configData)
            self.ni_configuration?.isCameraAssistanceEnabled = true
        }
        catch
        {
            // Stop and display the issue because the incoming data is invalid.
            // In your app, debug the accessory data to ensure an expected
            // format.
            print("Failed to create NINearbyAccessoryConfiguration for '\(name)'. Error: \(error)")
            return
        }
        
        referenceDict[unique_hash]?.run(self.ni_configuration!)

        print("Accessory Session configured.")
    }

    func _prepare_uwb_session(_ unique_hash: Int)
    {
        // Create an NI session for the device
        self.referenceDict[unique_hash] = NISession()
        self.referenceDict[unique_hash]?.delegate = self
        self.referenceDict[unique_hash]?.setARSession(arView.session)

        // Also creates the AR object
        self.entityDict[unique_hash] = ModelEntity(mesh: pinShape, materials: [material])
        self.entityDict[unique_hash]!.position = [0, 0, 100]
        self.anchor.addChild(entityDict[unique_hash]!)

        // Start config info exchange
        self._ble_send_data( Data([ NI_Messages.initialize.rawValue ]), unique_hash )
    }


    func _ble_discovery_handler(aid: Int, index: Int)
    {
        print("Discovered anchor \(aid), ")

        self.anchor_connection_status[aid] = false

        do
        {
            try self.ble.connectAnchor(aid)
        }
        catch
        {
            print("Error connecting to anchor \(aid)")
        }
    }

    func _ble_timeout_handler(aid: Int, unique_hash: Int)
    {
        print("Timeout for anchor \(aid)")

        self.anchor_connection_status[aid] = false
    }

    func _ble_connected_handler(aid: Int, unique_hash: Int)
    {
        print("Connected to anchor \(aid)")

        self.anchor_connection_status[aid] = true

        self._prepare_uwb_session(unique_hash)

        do
        {
            try self.ble.sendData( Data([ NI_Messages.iOSNotify.rawValue ]),
                                   unique_hash )
        }
        catch
        {
            print("Error sending data to accessory \(unique_hash)")
        }
    }

    func _ble_disconnected_handler(aid: Int, unique_hash: Int)
    {
        print("Disconnected from anchor \(aid)")

        self.anchor_connection_status[aid] = false

        referenceDict[unique_hash]?.invalidate()
        // Remove the NI Session and Location values related to the device ID
        referenceDict.removeValue(forKey: unique_hash)
        
        // Remove entity and delete etityDict entry
        anchor.removeChild(entityDict[unique_hash]!)
        entityDict.removeValue(forKey: unique_hash)
    }

    func _ble_data_handler( data: Data,
                            accessoryName: String,
                            aid: Int,
                            unique_hash: Int )
    {
        // The accessory begins each message with an identifier byte.
        // Ensure the message length is within a valid range.
        if (data.count < 1)
        {
            print("ERROR: Accessory shared data length was less than 1.")
            return
        }
        
        // Assign the first byte which is the message identifier.
        guard let messageId = MessageId(rawValue: data.first!) else {
            fatalError("\(data.first!) is not a valid MessageId.")
        }
        
        // Handle the data portion of the message based on the message identifier.
        switch (messageId)
        {
            case .accessoryConfigurationData:
                // Access the message data by skipping the message identifier.
                assert(data.count > 1)
                let message = data.advanced(by: 1)
                self._setup_accessory(message, accessoryName, unique_hash)

            case .accessoryUwbDidStart:
                print("Accessory UWB did start")

            case .accessoryUwbDidStop:
                print("Accessory UWB did stop")

            case .configureAndStart:
                fatalError("Accessory should not send 'configureAndStart'.")

            case .initialize:
                fatalError("Accessory should not send 'initialize'.")

            case .stop:
                fatalError("Accessory should not send 'stop'.")

            // User defined/notification messages
            case .getReserved:
                print("Get not implemented in this version")

            case .setReserved:
                print("Set not implemented in this version")

            case .iOSNotify:
                print("Notification not implemented in this version")
        }

    }

    func _ble_send_data(_ data: Data, _ unique_hash: Int)
    {
        do
        {
            try self.ble.sendData(data, unique_hash)
        }
        catch
        {
            print("Error sending data to accessory \(unique_hash)")
        }
    }
}

extension GuidingLite_UWBManager: ARSessionDelegate {
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool
    {
        // TODO: Maybe we can make this better?????
        return false
    }
}

extension GuidingLite_UWBManager: NISessionDelegate
{
    func unique_hash_from_session(_ session: NISession) -> Int
    {
        var unique_hash = -1
        
        for (key, value) in referenceDict {
            if value == session {
                unique_hash = key
            }
        }
        
        return unique_hash
    }

    func should_retry(_ deviceID: Int) -> Bool {
        // Need to use the dictionary here, to know which device failed and check its connection state
        let qorvoDevice = self.ble.getDeviceFromUniqueID(deviceID)
        
        if qorvoDevice?.blePeripheralStatus != statusDiscovered {
            return true
        }
        
        return false
    }

    func handle_session_invalidation(_ deviceID: Int) {
        print("Session invalidated. Restarting.")
        // Ask the accessory to stop.
        self._ble_send_data(Data([MessageId.stop.rawValue]), deviceID)

        // Replace the invalidated session with a new one.
        referenceDict[deviceID] = NISession()
        referenceDict[deviceID]?.delegate = self

        // Ask the accessory to stop.
        self._ble_send_data(Data([MessageId.initialize.rawValue]), deviceID)
    }

    func session(_ session: NISession, didGenerateShareableConfigurationData shareableConfigurationData: Data, for object: NINearbyObject)
    {
        guard object.discoveryToken == self.ni_configuration?.accessoryDiscoveryToken else { return }
        
        // Prepare to send a message to the accessory.
        var msg = Data([MessageId.configureAndStart.rawValue])
        msg.append(shareableConfigurationData)
        
        let str = msg.map { String(format: "0x%02x, ", $0) }.joined()
        print("Sending shareable configuration bytes: \(str)")
        
        // Send the message to the correspondent accessory.
        self._ble_send_data(msg, self.unique_hash_from_session(session))
        print("Sent shareable configuration data.")
    }
    
    func session(_ session: NISession, didUpdateAlgorithmConvergence convergence: NIAlgorithmConvergence, for object: NINearbyObject?) {
        print("Convergence Status:\(convergence.status)")
        //TODO: To Refactor delete to only know converged or not
        
        guard let accessory = object else { return}
    
        switch convergence.status {
            case .converged:
                print("Horizontal Angle: \(String(describing: accessory.horizontalAngle))")
                print("verticalDirectionEstimate: \(accessory.verticalDirectionEstimate)")
                isConverged = true

            case .notConverged(let reasons):
                for reason in reasons
                {
                    print("Convergence Failure: \(reason)")
                }
                isConverged = false

            default:
                print("Did not converge: \(convergence.status)")
        }
    }

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let accessory = nearbyObjects.first else { return }
        guard let distance  = accessory.distance else { return }
        
        let unique_hash = self.unique_hash_from_session(session)
        
    
        if let updatedDevice = self.ble.getDeviceFromUniqueID(unique_hash) {
            // set updated values
            updatedDevice.uwbLocation?.distance = distance
    
            if let direction = accessory.direction {
                updatedDevice.uwbLocation?.direction = direction
                updatedDevice.uwbLocation?.noUpdate  = false
                
                // Update AR anchor
                if !arView.isHidden {
                    guard let transform = session.worldTransform(for: accessory) else {return}
                    entityDict[unique_hash]!.transform.matrix = transform
                }
            }
            //TODO: For IPhone 14 only
            else if isConverged {
                guard let horizontalAngle = accessory.horizontalAngle else {return}
                updatedDevice.uwbLocation?.direction = getDirectionFromHorizontalAngle(rad: horizontalAngle)
                updatedDevice.uwbLocation?.elevation = accessory.verticalDirectionEstimate.rawValue
                updatedDevice.uwbLocation?.noUpdate  = false
            }
            else {
                updatedDevice.uwbLocation?.noUpdate  = true
            }
    
            updatedDevice.blePeripheralStatus = statusRanging
    
            self._update_anchor_data(unique_hash, updatedDevice.GuidingLite_aid)
        }
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        
        // Retry the session only if the peer timed out.
        guard reason == .timeout else { return }
        print("Session timed out")
        
        // The session runs with one accessory.
        guard let accessory = nearbyObjects.first else { return }
        
        // Get the unique_hash associated to the NISession
        let unique_hash = self.unique_hash_from_session(session)
        
        // Consult helper function to decide whether or not to retry.
        if should_retry(unique_hash) {
            self._ble_send_data(Data([MessageId.stop.rawValue]), unique_hash)
            self._ble_send_data(Data([MessageId.initialize.rawValue]), unique_hash)
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        print("Session was suspended.")
        let msg = Data([MessageId.stop.rawValue])
        
        self._ble_send_data(msg, self.unique_hash_from_session(session))
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        print("Session suspension ended.")
        // When suspension ends, restart the configuration procedure with the accessory.
        let msg = Data([MessageId.initialize.rawValue])
        
        self._ble_send_data(msg, self.unique_hash_from_session(session))
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        let unique_hash = self.unique_hash_from_session(session)
        
        switch error {
        case NIError.invalidConfiguration:
            // Debug the accessory data to ensure an expected format.
            print("The accessory configuration data is invalid. Please debug it and try again.")
        case NIError.userDidNotAllow:
            print("You need to allow the app to use the UWB hardware.")
        case NIError.invalidConfiguration:
            print("Check the ARConfiguration used to run the ARSession")
        default:
            print("invalidated: \(error)")
            handle_session_invalidation(unique_hash)
        }
    }

}
