//
//  GuidingLite_MQTT.swift
//  Qorvo Nearby Interaction
//
//  Created by Ryan Mah on 2023-07-27.
//  Copyright © 2023 Apple. All rights reserved.
//

import Foundation
import UIKit
import CocoaMQTT

let USER_ID = 69

let HEARTBEAT_TOPIC    = "gl/user/\(USER_ID)/heartbeat"
let DATA_TOPIC_BASE    = "gl/user/\(USER_ID)/data/anchor/"
let HEADING_DATA_TOPIC = "gl/user/\(USER_ID)/data/heading"

// let USER_COORD_TOPIC    = "gl/user/\(USER_ID)/user_coordinates"
// let DEST_COORD_TOPIC    = "gl/user/\(USER_ID)/destination_coordinates"
// let ARROW_ANGLE_TOPIC   = "gl/user/\(USER_ID)/arrow_angle"

let METADATA_TOPIC           = "gl/server/metadata"
let PATHFINDING_CONFIG_TOPIC = "gl/server/pathfinding/config"

let PATHING_TOPIC  = "gl/user/\(USER_ID)/path"
let HEADING_TOPIC  = "gl/user/\(USER_ID)/target_heading"
let POSITION_TOPIC = "gl/user/\(USER_ID)/position"
let HAPTICS_TOPIC  = "gl/user/\(USER_ID)/haptics_options"

let SERVER_MDNS_HOSTNAME = "GuidingLight._mqtt._tcp.local."

struct AnchorData {
    let distance_m:    Float
    let azimuth_deg:   Int16
    let elevation_deg: Int16
    let los:           Bool
}

// Function to convert the struct into [UInt8]
func AnchorData_ToBytes(_ telemetry: AnchorData) -> [UInt8] {
    var copy = telemetry
    return withUnsafeBytes(of: &copy) { Array($0) }
}

struct HeadingData {
    let angle: Float
}

func HeadingData_ToBytes(_ heading: HeadingData) -> [UInt8] {
    var copy = heading
    return withUnsafeBytes(of: &copy) { Array($0) }
}


class MQTTClient {
    var mqtt: CocoaMQTT? = nil
    var user_id = USER_ID

    func initialize(_ ip: String)
    {
        let clientID = "GuidingLite_iOS_\(USER_ID)"
        
        self.mqtt = CocoaMQTT.init(clientID: clientID, host: ip, port: 1883)
        self.mqtt?.logLevel = .warning
        self.mqtt?.keepAlive = 60
        self.mqtt?.autoReconnect = true
    }
    
    func set_handler(_ delegate: CocoaMQTTDelegate)
    {
        self.mqtt?.delegate = delegate
    }

    func is_connected() -> Bool
    {
        return (self.mqtt?.connState == .connected)
    }
    
    func connect()
    {
        let success = mqtt?.connect(timeout: 60)
        print("CONNECTION STATUS: \(String(describing: success))")
    }
    
    func publish(_ topic: String, _ msg: String)
    {
        if !is_connected()
        {
            print("WARNING: tried to publish to MQTT while not connected.")
            return
        }

        let msg = CocoaMQTTMessage(topic: topic, string: msg)
        self.mqtt?.publish(msg)
    }

    func publish_bytes(_ topic: String, _ msg: [UInt8])
    {
        let msg = CocoaMQTTMessage(topic: topic, payload: msg)
        self.mqtt?.publish(msg)
    }
}

class GuidingLite_MqttHandler: CocoaMQTTDelegate {
    var direction       = ""
    // var userPosition    = CGPoint(x: 0, y: 0)
    // var arrowAngle      = Float(0.0)

    ////////////////////////////////////////////////////////////////////////
    // Callbacks

    var connect_callback: (() -> Void)? = nil

    var pathing_callback: (( [CGPoint] ) -> Void)? = nil

    // Takes in x, y, heading
    var position_callback: ((Float, Float, Float) -> Void)? = nil

    var target_heading_callback: ((Float) -> Void)? = nil

    /*
    {
        "intensity": 0.5,
        "heartbeat": false,
        "done": false
    }
    */
    var haptics_callback: (( [String: Any] ) -> Void)? = nil

    // Takes in dictionary of metadata
    var metadata_callback: ( ([String: Any]) -> Void )? = nil
    ////////////////////////////////////////////////////////////////////////

    ///
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck)
    {
        print("SUCCESSFULLY CONNECTED TO BROKER!")

        mqtt.subscribe(PATHING_TOPIC)
        mqtt.subscribe(HEADING_TOPIC)
        mqtt.subscribe(POSITION_TOPIC)
        mqtt.subscribe(HAPTICS_TOPIC)

        mqtt.subscribe(METADATA_TOPIC)

        // mqtt.subscribe("gl/user/\(USER_ID)/pathing")
        // mqtt.subscribe(USER_COORD_TOPIC)
        // mqtt.subscribe(DEST_COORD_TOPIC)
        // mqtt.subscribe(ARROW_ANGLE_TOPIC)

        if let callback = connect_callback
        {
            callback()
        }
    }
    
    ///
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16)
    {
        
    }
    
    ///
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16)
    {
        
    }
    
    ///
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 )
    {
        // print("msg: \(message.topic), \(message.string)")

        switch message.topic
        {
            case PATHING_TOPIC:
                if  let callback = pathing_callback,
                    let decodedDict = decodeJSON(message.string!),
                    let path = decodedDict["val"]
                {
                    var points = [CGPoint]()

                    for point in path as! [[NSNumber]]
                    {
                        let x = point[0] as! CGFloat
                        let y = point[1] as! CGFloat

                        points.append( CGPoint(x: x, y: y) )
                    }

                    // print("Received path: \(points)")
                    callback(points)
                }

            case HEADING_TOPIC:
                if  let callback = target_heading_callback,
                    let decodedDict = decodeJSON(message.string!),
                    let heading = decodedDict["val"] as? NSNumber
                {
                    callback(heading.floatValue)
                }

            case HAPTICS_TOPIC:
                if  let callback = haptics_callback,
                    let decodedDict = decodeJSON(message.string!)
                {
                    callback(decodedDict)
                }

                    
            case POSITION_TOPIC:
                if  let callback = position_callback,
                    let decodedDict = decodeJSON(message.string!),
                    let x = decodedDict["x"] as? NSNumber,
                    let y = decodedDict["y"] as? NSNumber,
                    let heading = decodedDict["heading"] as? NSNumber
                {
                    callback(x.floatValue, y.floatValue, heading.floatValue)
                }

            case METADATA_TOPIC:
                if let callback = metadata_callback
                {
                    if let decodedDict = decodeJSON(message.string!)
                    {
                        callback(decodedDict)
                    }
                }

            default:
                break
        }


        // if (subtopics[3] == "path")
        // {
        //     // let jsonString = message.string
            
        //     // if let decodedDictionary = decodeJSON(jsonString!)
        //     // {
        //     //     direction = decodedDictionary["direction"] as! String
        //     //     print("Direction: \(decodedDictionary["direction"]!)")
        //     // }
        //     // else
        //     // {
        //     //     print("Failed to decode JSON string.")
        //     // }
        // }
        
        // if (message.topic == USER_COORD_TOPIC)
        // {
        //     let jsonString = message.string
            
        //     if let decodedDictionary = decodeJSON(jsonString!)
        //     {
        //         userPosition.x = decodedDictionary["x"] as! CGFloat
        //         print("user_x: \(decodedDictionary["x"]!)")
        //         userPosition.y = decodedDictionary["y"] as! CGFloat
        //         print("user_y: \(decodedDictionary["y"]!)")
        //     }
        //     else
        //     {
        //         print("Failed to decode JSON string.")
        //     }
        // }
        
        // if (message.topic == ARROW_ANGLE_TOPIC)
        // {
        //     let jsonString = message.string
            
        //     if let decodedDictionary = decodeJSON(jsonString!)
        //     {
        //         arrowAngle = decodedDictionary["angle"] as! Float
        //         print("arrow_angle: \(decodedDictionary["angle"]!)")
        //     }
        //     else
        //     {
        //         print("Failed to decode JSON string.")
        //     }
        // }
    }
    
    ///
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String])
    {
        
    }
    
    ///
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String])
    {
        
    }
    
    ///
    func mqttDidPing(_ mqtt: CocoaMQTT)
    {
        
    }
    
    ///
    func mqttDidReceivePong(_ mqtt: CocoaMQTT)
    {
        
    }
    
    ///
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?)
    {
        
    }
}
