//
//  GuidingLite_MQTT.swift
//  Qorvo Nearby Interaction
//
//  Created by Ryan Mah on 2023-07-27.
//  Copyright © 2023 Apple. All rights reserved.
//

import Foundation
import CocoaMQTT

let USER_ID = 69

let HEARTBEAT_TOPIC     = "gl/user/\(USER_ID)/heartbeat"
let PATHING_TOPIC       = "gl/user/\(USER_ID)/pathing"
let DATA_TOPIC_BASE     = "gl/user/\(USER_ID)/data/"
let USER_COORD_TOPIC    = "gl/user/\(USER_ID)/user_coordinates"
let DEST_COORD_TOPIC    = "gl/user/\(USER_ID)/destination_coordinates"
let ARROW_ANGLE_TOPIC   = "gl/user/\(USER_ID)/arrow_angle"

let SERVER_MDNS_HOSTNAME = "GuidingLight._mqtt._tcp.local."

struct TelemetryData {
    let distance_m:    Float
    let azimuth_deg:   Int16
    let elevation_deg: Int16
    let los:           Bool
}

// Function to convert the struct into [UInt8]
func TelemetryData_ToBytes(_ telemetry: TelemetryData) -> [UInt8] {
    var copy = telemetry
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
    var userPosition    = CGPoint(x: 0, y: 0)
    var arrowAngle      = Float(0.0)

    var connect_callback: (() -> Void)? = nil

    ///
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck)
    {
        print("SUCCESSFULLY CONNECTED TO BROKER!")
        mqtt.subscribe("gl/user/\(USER_ID)/pathing")
        mqtt.subscribe(USER_COORD_TOPIC)
        mqtt.subscribe(DEST_COORD_TOPIC)
        mqtt.subscribe(ARROW_ANGLE_TOPIC)

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
        let subtopics = message.topic.components(separatedBy: "/")
        print("msg: \(message.topic)")
        
        if (subtopics[3] == "pathing")
        {
            let jsonString = message.string
            
            if let decodedDictionary = decodeJSONString(jsonString!)
            {
                direction = decodedDictionary["direction"] as! String
                print("Direction: \(decodedDictionary["direction"]!)")
            }
            else
            {
//                print("Failed to decode JSON string.")
            }
        }
        
        if (message.topic == USER_COORD_TOPIC)
        {
            let jsonString = message.string
            
            if let decodedDictionary = decodeJSONString(jsonString!)
            {
                userPosition.x = decodedDictionary["x"] as! CGFloat
                print("user_x: \(decodedDictionary["x"]!)")
                userPosition.y = decodedDictionary["y"] as! CGFloat
                print("user_y: \(decodedDictionary["y"]!)")
            }
            else
            {
//                print("Failed to decode JSON string.")
            }
        }
        
        if (message.topic == ARROW_ANGLE_TOPIC)
        {
            let jsonString = message.string
            
            if let decodedDictionary = decodeJSONString(jsonString!)
            {
                arrowAngle = decodedDictionary["angle"] as! Float
                print("arrow_angle: \(decodedDictionary["angle"]!)")
            }
            else
            {
//                print("Failed to decode JSON string.")
            }
        }
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
