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

let HEARTBEAT_TOPIC = "gl/user/\(USER_ID)/heartbeat"
let PATHING_TOPIC   = "gl/user/\(USER_ID)/pathing"
let DATA_TOPIC_BASE = "gl/user/\(USER_ID)/data/"

class MQTTClient {
    var mqtt: CocoaMQTT? = nil
    var user_id = USER_ID

    func initialize()
    {
        let clientID = "GuidingLite_iOS_\(USER_ID)"
        
        self.mqtt = CocoaMQTT.init(clientID: clientID, host: "192.168.8.2", port: 1883)
        self.mqtt?.logLevel = .info
        self.mqtt?.keepAlive = 60
    }
    
    func set_handler(_ delegate: CocoaMQTTDelegate)
    {
        self.mqtt?.delegate = delegate
    }

    func connect()
    {
        let success = mqtt?.connect(timeout: 60)
        print("CONNECTION STATUS: \(String(describing: success))")
    }
    
    func publish(_ topic: String, _ msg: String)
    {
        let msg = CocoaMQTTMessage(topic: topic, string: msg)
        self.mqtt?.publish(msg)
    }
    
}

class GuidingLite_MqttHandler: CocoaMQTTDelegate {
    var direction = ""
    ///
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck)
    {
        print("SUCCESSFULLY CONNECTED TO BROKER!")
        mqtt.subscribe("gl/user/\(USER_ID)/pathing")
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
