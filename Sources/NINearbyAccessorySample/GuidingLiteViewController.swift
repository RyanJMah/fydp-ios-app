//
//  GuidingLiteViewController.swift
//  Qorvo Nearby Interaction
//
//  Created by Mohammad Dabbah on 2024-01-21.
//  Copyright © 2024 Apple. All rights reserved.
//

import UIKit
import SceneKit
import NearbyInteraction
import ARKit
import RealityKit
import CoreHaptics
import CoreAudio
import os.log
import CocoaMQTT
import Foundation

var g_uwb_manager: GuidingLite_UWBManager?

func decodeJSON(_ jsonString: String) -> [String: Any]? {
    // Step 1: Convert the JSON string to Data
    guard let jsonData = jsonString.data(using: .utf8) else {
        print("Failed to convert JSON string to Data.")
        return nil
    }
    
    // Step 2: Use JSONSerialization to parse Data into a dictionary
    do {
        if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            return jsonObject
        } else {
            print("Failed to convert JSON data to a dictionary.")
            return nil
        }
    } catch {
        print("Error parsing JSON: \(error)")
        return nil
    }
}

func serializeJSON(_ jsonObject: [String: Any]) -> String? {
    // Step 1: Convert the JSON object to Data
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        
        // Step 2: Convert the Data to a string
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        } else {
            print("Failed to convert Data to String.")
            return nil
        }
    } catch {
        print("Error serializing JSON: \(error)")
        return nil
    }
}

class DebugViewController: UIViewController
{
    var timer: Timer?
    var uwb_manager: GuidingLite_UWBManager?
    
    @IBOutlet weak var anchor0StatusLabel: UILabel!
    @IBOutlet weak var anchor1StatusLabel: UILabel!
    @IBOutlet weak var anchor2StatusLabel: UILabel!
    @IBOutlet weak var anchor3StatusLabel: UILabel!
    
    
    @IBOutlet weak var anchor0AngleLabel: UILabel!
    @IBOutlet weak var anchor1AngleLabel: UILabel!
    @IBOutlet weak var anchor2AngleLabel: UILabel!
    @IBOutlet weak var anchor3AngleLabel: UILabel!
    
    
    @IBOutlet weak var anchor0DistLabel: UILabel!
    @IBOutlet weak var anchor1DistLabel: UILabel!
    @IBOutlet weak var anchor2DistLabel: UILabel!
    @IBOutlet weak var anchor3DistLabel: UILabel!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.uwb_manager = g_uwb_manager

        startTimer()
    }

    func startTimer()
    {
        timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(updateLabels), userInfo: nil, repeats: true)
    }

    func round(_ value: Float, _ places: Int) -> Double
    {
        let divisor = pow(10.0, Double(places))
        return (Double(value) * divisor).rounded() / divisor
    }

    @objc func updateLabels()
    {
        let anchor0_data = self.uwb_manager?.anchor_data[0]
        let anchor1_data = self.uwb_manager?.anchor_data[1]
        let anchor2_data = self.uwb_manager?.anchor_data[2]
        let anchor3_data = self.uwb_manager?.anchor_data[3]
        
        let anchor0_status = self.uwb_manager?.anchor_connection_status[0]
        let anchor1_status = self.uwb_manager?.anchor_connection_status[1]
        let anchor2_status = self.uwb_manager?.anchor_connection_status[2]
        let anchor3_status = self.uwb_manager?.anchor_connection_status[3]
        
        anchor0StatusLabel.text = anchor0_status ?? false ? "Connected" : "Not Connected"
        anchor1StatusLabel.text = anchor1_status ?? false ? "Connected" : "Not Connected"
        anchor2StatusLabel.text = anchor2_status ?? false ? "Connected" : "Not Connected"
        anchor3StatusLabel.text = anchor3_status ?? false ? "Connected" : "Not Connected"

        anchor0AngleLabel.text = String(anchor0_data?.azimuth_deg ?? 0)
        anchor1AngleLabel.text = String(anchor1_data?.azimuth_deg ?? 0)
        anchor2AngleLabel.text = String(anchor2_data?.azimuth_deg ?? 0)
        anchor3AngleLabel.text = String(anchor3_data?.azimuth_deg ?? 0)
         
        anchor0DistLabel.text = String( self.round(anchor0_data?.distance_m ?? 0.0, 4) )
        anchor1DistLabel.text = String( self.round(anchor1_data?.distance_m ?? 0.0, 4) )
        anchor2DistLabel.text = String( self.round(anchor2_data?.distance_m ?? 0.0, 4) )
        anchor3DistLabel.text = String( self.round(anchor3_data?.distance_m ?? 0.0, 4) )
    }
}

class GuidingLiteViewController: UIViewController
{
    @IBOutlet weak var userArrowImage: UIImageView!
    @IBOutlet weak var guidingLiteSettingsButton: UIButton!
    
    @IBOutlet weak var locationPinImage: UIImageView!
    
    @IBOutlet weak var directionArrowImage: UIImageView!
    
    @IBOutlet weak var cancelDestButton: UIButton!
    @IBOutlet weak var setDestButton: UIButton!
    @IBOutlet weak var goDestButton: UIButton!

    @IBOutlet weak var arView: ARView!

    let S_INIT = 0
    let S_SET_DEST = 1
    let S_GO = 2
    var currDestState: Int = 0
    
    // Pin location
    var pinLocation: CGPoint = CGPoint(x: 0, y: 0)
    
    // MQTT
    var first_time_mqtt_init = true
    var mqtt_client: MQTTClient = MQTTClient()
    var mqtt_handler: GuidingLite_MqttHandler = GuidingLite_MqttHandler()
    
    // Map borders
    let mapTopLeft          = CGPoint(x: 10,    y: 375)
    let mapTopRight         = CGPoint(x: 359,   y: 375)
    let mapBottomLeft       = CGPoint(x: 10,    y: 736)
    let mapBottomRight      = CGPoint(x: 359,   y: 736)
    
    let pinDefaultLocation  = CGPoint(x: 184.5, y: 555.5)

    var uwb_manager: GuidingLite_UWBManager?
    var heading_sensor: GuidingLite_HeadingSensor?
    var haptics_controller: GuidingLight_HapticsController?

    var real_life_to_png_scale: Float?
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

        locationPinImage.isHidden = true

        self.mqtt_handler.connect_callback  = self.mqtt_connect_callback
        self.mqtt_handler.position_callback = self.mqtt_position_msg_callback
        self.mqtt_handler.metadata_callback = self.mqtt_metadata_msg_callback

        // Main UI timer, 200ms
        _ = Timer.scheduledTimer( timeInterval: 0.2,
                                  target: self,
                                  selector: #selector(ui_timer),
                                  userInfo: nil,
                                  repeats: true )

        /*
         * Schedule the expensive initialization to run after the view has loaded,
         * so that the UI remains responsive.
         *
         * Haptics will be initialized even after these, since it is technically the
         * most "real-time" task, and the UWB initialization interferes with it
         */
        _ = Timer.scheduledTimer( timeInterval: 1,
                                  target: self,
                                  selector: #selector(self.expensive_initialization),
                                  userInfo: nil,
                                  repeats: false )  // Only run once

        _ = Timer.scheduledTimer( timeInterval: 5,
                                  target: self,
                                  selector: #selector(self.haptics_init),
                                  userInfo: nil,
                                  repeats: false )  // Only run once
    }

    @objc func expensive_initialization()
    {
        // self.showIPAddressInputDialog()

        self.mqtt_client.initialize("192.168.1.121")
        // self.mqtt_client.initialize("GuidingLight._mqtt._tcp.local.")
        self.mqtt_client.set_handler(self.mqtt_handler)
        self.mqtt_client.connect()

        g_uwb_manager = GuidingLite_UWBManager(arView: self.arView)

        self.uwb_manager    = g_uwb_manager
        self.heading_sensor = GuidingLite_HeadingSensor()
    }

    @objc func haptics_init()
    {
        self.haptics_controller = GuidingLight_HapticsController()
    }

    @objc func ui_timer()
    {
        self.updateUserArrowPos(pos: mqtt_handler.userPosition)
        self.updateDirectionArrow(angle: mqtt_handler.arrowAngle)
    }

    func mqtt_connect_callback()
    {
        // Start mqtt timers after connection

        // GuidingLite: heartbeat timer
        _ = Timer.scheduledTimer( timeInterval: 10,
                                  target: self,
                                  selector: #selector(self.mqtt_heartbeat_timer),
                                  userInfo: nil,
                                  repeats: true )

        // Telemetry timer
        _ = Timer.scheduledTimer( timeInterval: 1/10,   // 10Hz
                                  target: self,
                                  selector: #selector(self.telemetry_timer),
                                  userInfo: nil,
                                  repeats: true )
    }

    func mqtt_metadata_msg_callback(metadata: [String: Any])
    {
        // print("Received metadata: \(metadata)")
        // print("scale = \(metadata["real_life_to_floorplan_png_scale"])")
        self.real_life_to_png_scale = metadata["real_life_to_floorplan_png_scale"] as? Float
    }

    func mqtt_position_msg_callback(x: Float, y: Float, heading: Float)
    {
        if self.real_life_to_png_scale == nil
        {
            return
        }

        // print("Received position: x = \(x), y = \(y), heading = \(heading)")

        let png_x = x / self.real_life_to_png_scale!
        let png_y = y / self.real_life_to_png_scale!

        let point = CGPoint(x: CGFloat(png_x), y: CGFloat(png_y))

        self.updateUserArrowPos(pos: point)
    }

    @objc func mqtt_heartbeat_timer()
    {
        DispatchQueue.global(qos: .default).async
        {
            self.mqtt_client.publish( HEARTBEAT_TOPIC, "{status: \"online\"}" )
        }
    }

    @objc func telemetry_timer()
    {
        /*
         * FIXME: Reading the heading data in the same timer that
         *        sends the telemetry may cause latency issues.
         *
         *        If it does, move the heading data reading to a separate
         *        timer.
         */

        let angle = self.heading_sensor?.get_orientation()

        let heading_data = HeadingData( angle: Float(angle!) )
        let heading_bytes = HeadingData_ToBytes(heading_data)

        self.mqtt_client.publish_bytes( HEADING_DATA_TOPIC, heading_bytes )
        // print("Heading: \(angle!)")

        for (aid, anchor_data) in uwb_manager!.anchor_data
        {
            let telem_bytes = AnchorData_ToBytes(anchor_data)
            
            self.mqtt_client.publish_bytes( DATA_TOPIC_BASE + String(aid), telem_bytes )

            // print("Telemetry for anchor \(aid): \(anchor_data)")
        }
    }
    
    func showIPAddressInputDialog()
    {
        self.first_time_mqtt_init = false

        let alertController = UIAlertController(title: "Enter IP Address", message: nil, preferredStyle: .alert)

        alertController.addTextField { (textField) in
            textField.placeholder = "IP Address"
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let okAction = UIAlertAction(title: "OK", style: .default) { [weak self] (_) in
            if let ipAddress = alertController.textFields?.first?.text {
                // Unwrap self
                guard let strongSelf = self else {
                    return
                }

                strongSelf.mqtt_handler.connect_callback = strongSelf.mqtt_connect_callback

                strongSelf.mqtt_client.initialize(ipAddress)
                strongSelf.mqtt_client.set_handler(strongSelf.mqtt_handler)
                strongSelf.mqtt_client.connect()
            }
        }

        alertController.addAction(cancelAction)
        alertController.addAction(okAction)

        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func goButtonPressed(_ sender: UIButton)
    {
        print("Go Pressed!")

        // Add your logic here
        if(currDestState == S_SET_DEST) {
            self.send_mqtt_pin_location()
            currDestState = S_GO
        }
    }
    
    @IBAction func setButtonPressed(_ sender: UIButton) {
        print("set  Pressed!")
        
        self.updateLocationPinImage(pos: pinDefaultLocation)
        locationPinImage.isHidden = false
        currDestState = S_SET_DEST
    }
    
    @IBAction func cancelButtonPressed(_ sender: UIButton) {
        print("cancel Pressed!")
        // Add your logic here
        currDestState = S_INIT
        locationPinImage.isHidden = true
    }
    
    func send_mqtt_pin_location()
    {
        let x = pinLocation.x
        let y = pinLocation.y

        let dict = ["endpoint": [x, y, 0]]
        let json = serializeJSON(dict)

        DispatchQueue.global(qos: .default).async
        {
            self.mqtt_client.publish( PATHFINDING_CONFIG_TOPIC, json! )
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        // Get the first touch (assuming single touch)
        if let touch = touches.first {
            // Update position when the touch begins
            self.updatePinPosition(for: touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        // Get the first touch (assuming single touch)
        if let touch = touches.first {
            // Update position while the touch is moving
            self.updatePinPosition(for: touch)
        }
    }

    func updatePinPosition(for touch: UITouch)
    {
        if (currDestState == S_SET_DEST)
        {
            // Only update pinLocation when setting a new destination
            pinLocation = touch.location(in: self.view)
            print("Live update - Touch coordinates: x = \(pinLocation.x), y = \(pinLocation.y)")

            if ( self.isPointInMap(pos: pinLocation) )
            {
                self.updateLocationPinImage(pos: pinLocation)
            }
        }
    }
    
    func updateDirectionArrow(angle: Float)
    {
        UIView.animate(withDuration: 0.5) {
            // Convert the angle to radians
            let radians = angle * .pi / 180.0

            // Apply the rotation transform
            self.directionArrowImage.transform = CGAffineTransform(rotationAngle: CGFloat(radians))
        }
    }

    func updateUserArrowPos(pos: CGPoint)
    {
        var scaled_coord = CGPoint(x: (mapBottomLeft.x + pos.x), y: (mapBottomLeft.y - pos.y))
        
        // Before updating the position coordinate, make sure that this point does not exceed
        // the map bounds.
        if (scaled_coord.x >= mapTopRight.x)
        {
            scaled_coord.x = mapTopRight.x
        }
        else if (scaled_coord.x <= mapTopLeft.x)
        {
            scaled_coord.x = mapTopLeft.x
        }
        
        if (scaled_coord.y >= mapBottomRight.y)
        {
            scaled_coord.y = mapBottomRight.y
        }
        else if(scaled_coord.y <= mapTopRight.y)
        {
            scaled_coord.y = mapTopRight.y
        }
        
        
        userArrowImage.frame.origin = scaled_coord
    }

    func updateLocationPinImage(pos: CGPoint)
    {
        locationPinImage.frame.origin = pos
    }

    func isPointInMap(pos: CGPoint) -> Bool
    {
        let x = pos.x
        let y = pos.y
        
        if((x >= mapTopLeft.x) && (x <= mapTopRight.x) && (y >= mapTopLeft.y) && (y <= mapBottomLeft.y)) {
            return true
        }
        return false
    }
    
    // Returns the current position of the user arrow relative to the map area.
    func getUserArrowPos() -> CGPoint
    {
        return CGPoint(x: 0, y: 0)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
}
