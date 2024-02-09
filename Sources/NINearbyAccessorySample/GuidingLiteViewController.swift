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

func round(_ value: Float, _ places: Int) -> Double
{
    let divisor = pow(10.0, Double(places))
    return (Double(value) * divisor).rounded() / divisor
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
         
        anchor0DistLabel.text = String( round(anchor0_data?.distance_m ?? 0.0, 4) )
        anchor1DistLabel.text = String( round(anchor1_data?.distance_m ?? 0.0, 4) )
        anchor2DistLabel.text = String( round(anchor2_data?.distance_m ?? 0.0, 4) )
        anchor3DistLabel.text = String( round(anchor3_data?.distance_m ?? 0.0, 4) )
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

    @IBOutlet weak var mapImage: UIImageView!

    let S_INIT = 0
    let S_SET_DEST = 1
    let S_GO = 2
    var currDestState: Int = 0
    
    // Pin location
    var pinLocation: CGPoint = CGPoint(x: 0, y: 0)
    
    // MQTT
    var mqtt_client: MQTTClient = MQTTClient()
    var mqtt_handler: GuidingLite_MqttHandler = GuidingLite_MqttHandler()
    
    // Map borders
    var mapTopLeft:     CGPoint = CGPoint(x: 0.0, y: 0.0)
    var mapTopRight:    CGPoint = CGPoint(x: 0.0, y: 0.0)
    var mapBottomLeft:  CGPoint = CGPoint(x: 0.0, y: 0.0)
    var mapBottomRight: CGPoint = CGPoint(x: 0.0, y: 0.0)

    let pinDefaultLocation  = CGPoint(x: 184.5, y: 555.5)

    var uwb_manager: GuidingLite_UWBManager?
    var heading_sensor: GuidingLite_HeadingSensor?
    var haptics_controller: GuidingLight_HapticsController?

    // var real_life_to_png_scale: CGFloat = 0.9163987138263665
    var real_life_to_png_scale: CGFloat = 1.0
    var png_to_phone_scale_y:   CGFloat = 1.0
    var png_to_phone_scale_x:   CGFloat = 1.0

    var prev_user_position:  CGPoint = CGPoint(x: 0, y: 0)
    var user_position:       CGPoint = CGPoint(x: 0, y: 0)
    var user_heading:        Float = 0.0
    var user_target_heading: Float = 90.0

    var server_tick_period: TimeInterval = 0.1
    var ui_update_period:   TimeInterval = 1/60

    /////////////////////////////////////////////////////////////////////////////////////
    // Initialization

    override func viewDidLoad()
    {
        super.viewDidLoad()

        self.init_geometry()

        self.locationPinImage.isHidden = true

        self.mqtt_handler.connect_callback        = self.mqtt_connect_callback
        self.mqtt_handler.position_callback       = self.mqtt_position_msg_callback
        self.mqtt_handler.target_heading_callback = self.mqtt_target_heading_msg_callback
        self.mqtt_handler.metadata_callback       = self.mqtt_metadata_msg_callback

        // Main UI timer, 200ms
        _ = Timer.scheduledTimer( timeInterval: self.ui_update_period,
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

    func init_geometry()
    {
        /////////////////////////////////////////////////////////////////////////////////
        // Map borders
        guard let imageView = self.mapImage, let image = imageView.image else {
            print("No image found")
            return
        }

        let imageViewSize = imageView.bounds.size
        let imageSize = image.size

        self.userArrowImage.frame.origin = self.user_position

        self.png_to_phone_scale_x = imageSize.width / imageViewSize.width
        self.png_to_phone_scale_y = imageSize.height / imageViewSize.height

        print("imageViewSize: \(imageViewSize), imageSize: \(imageSize)")

        let w = imageView.frame.size.width
        let h = imageView.frame.size.height
        
        self.mapTopLeft     = imageView.frame.origin
        self.mapBottomLeft  = CGPoint(x: imageView.frame.origin.x, y: imageView.frame.origin.y + h)
        self.mapTopRight    = CGPoint(x: imageView.frame.origin.x + w, y: imageView.frame.origin.y)
        self.mapBottomRight = CGPoint(x: imageView.frame.origin.x + w, y: imageView.frame.origin.y + h)

        print("Map borders: top left = \(mapTopLeft), top right = \(mapTopRight), bottom left = \(mapBottomLeft), bottom right = \(mapBottomRight)")
        /////////////////////////////////////////////////////////////////////////////////
    }

    func showIPAddressInputDialog()
    {
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
    /////////////////////////////////////////////////////////////////////////////////////


    /////////////////////////////////////////////////////////////////////////////////////
    // Repeated Timers
    @objc func ui_timer()
    {
        // TODO: change to user_heading when the heading data is available
        self.updateUserArrow( pos: self.user_position,
                              angle: self.user_target_heading )

        self.updateDirectionArrow(angle: self.user_target_heading)
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

    @objc func mqtt_heartbeat_timer()
    {
        DispatchQueue.global(qos: .default).async
        {
            self.mqtt_client.publish( HEARTBEAT_TOPIC, "{status: \"online\"}" )
        }
    }
    /////////////////////////////////////////////////////////////////////////////////////


    /////////////////////////////////////////////////////////////////////////////////////
    // MQTT Callbacks
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
        self.real_life_to_png_scale = metadata["real_life_to_floorplan_png_scale"] as! CGFloat

        let server_tick_hz = metadata["global_update_frequency_Hz"] as! Float

        self.server_tick_period = Double(1.0) / Double(server_tick_hz)
    }

    func mqtt_position_msg_callback(x: Float, y: Float, heading: Float)
    {
        self.user_position = self.real_life_to_phone( CGPoint(x: CGFloat(x), y: CGFloat(y)) )
        // print("Received position: x = \(x), y = \(y), heading = \(heading) -> \(self.user_position)")

        // self.updateUserArrowPos(pos: phone_point)
    }

    func mqtt_target_heading_msg_callback(heading: Float)
    {
        // print("Received heading: \(heading)")
        self.user_target_heading = heading
        // self.updateDirectionArrow(angle: heading)
        // self.updateUserArrowDirection(angle: heading)
    }
    /////////////////////////////////////////////////////////////////////////////////////

    
    /////////////////////////////////////////////////////////////////////////////////////
    // UI Logic
    @IBAction func goButtonPressed(_ sender: UIButton)
    {
        print("Go Pressed!")

        // Add your logic here
        if (currDestState == S_SET_DEST)
        {

            let real_life_point = self.phone_to_real_life( self.pinLocation )

            let dict = ["endpoint": [real_life_point.x, real_life_point.y, 0]]
            let json = serializeJSON(dict)

            DispatchQueue.global(qos: .default).async
            {
                self.mqtt_client.publish( PATHFINDING_CONFIG_TOPIC, json! )
            }

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
            // print("Live update - Touch coordinates: x = \(pinLocation.x), y = \(pinLocation.y)")

            if ( self.isPointInMap(pos: pinLocation) )
            {
                self.updateLocationPinImage(pos: pinLocation)
            }
        }
    }

    func updateUserArrow(pos: CGPoint, angle: Float)
    {
        let radians = self.fix_angle(angle)

        let dx = pos.x - userArrowImage.center.x
        let dy = pos.y - userArrowImage.center.y
        
        // Concatenate translation and rotation transformations
        let transform = CGAffineTransform(translationX: dx, y: dy)
                        .rotated(by: CGFloat(radians))

        self.userArrowImage.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        UIView.animate(withDuration: self.ui_update_period)
        {
            // Apply the concatenated transformation
            self.userArrowImage.transform = transform
        }

        self.prev_user_position = pos
    }


    // func updateUserArrow(pos: CGPoint, angle: Float)
    // {
    //     var point = pos
        
    //     // print("User arrow position: \(point)")
        
    //     let halfWidth = userArrowImage.frame.size.width / 2.0
    //     let halfHeight = userArrowImage.frame.size.height / 2.0
        
    //     point.x -= halfWidth
    //     point.y -= halfHeight

    //     let radians  = self.fix_angle(angle)
    //     let rotation = CGAffineTransform(rotationAngle: CGFloat(radians))

    //     UIView.animate( withDuration: self.server_tick_period )
    //     {
    //         // self.userArrowImage.frame.origin = point
    //         self.userArrowImage.transform    = rotation
    //     }    
    // }

    func updateDirectionArrow(angle: Float)
    {
        let radians = self.fix_angle(angle)

        UIView.animate( withDuration: self.server_tick_period )
        {
            self.directionArrowImage.transform = CGAffineTransform(rotationAngle: CGFloat(radians))
        }
    }

    func updateLocationPinImage(pos: CGPoint)
    {
        locationPinImage.frame.origin = self.calc_pin_location(pos)
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
    
    func phone_to_real_life(_ phone_point: CGPoint) -> CGPoint
    {
        let real_phone_point = CGPoint( x: phone_point.x - self.mapBottomLeft.x,
                                        y: self.mapBottomLeft.y - phone_point.y )

        //  print("Phone to png: \(phone_point) -> \(CGPoint(x: real_phone_point.x / self.png_to_phone_scale_x, y: real_phone_point.y / self.png_to_phone_scale_y))")

        let ret = CGPoint( x: real_phone_point.x * self.png_to_phone_scale_x * self.real_life_to_png_scale,
                           y: real_phone_point.y * self.png_to_phone_scale_y * self.real_life_to_png_scale )

        print("Phone to real life: \(phone_point) -> \(ret)")

        return ret
    }

    func real_life_to_phone(_ real_life_point: CGPoint) -> CGPoint
    {
        let phone_point = CGPoint( x: real_life_point.x / (self.png_to_phone_scale_x * self.real_life_to_png_scale),
                                   y: real_life_point.y / (self.png_to_phone_scale_y * self.real_life_to_png_scale) )

        let ret = CGPoint( x: phone_point.x + self.mapBottomLeft.x,
                           y: self.mapBottomLeft.y - phone_point.y )

        return ret
    }

    func calc_pin_location(_ point: CGPoint) -> CGPoint
    {
        return CGPoint( x: point.x - locationPinImage.frame.size.width / 2,
                        y: point.y - locationPinImage.frame.size.height )
    }

    func fix_angle(_ angle: Float) -> Float
    {
        return ( (angle - 90) * .pi / 180.0 ) * -1
    }

    // Returns the current position of the user arrow relative to the map area.
    func getUserArrowPos() -> CGPoint
    {
        return CGPoint(x: 0, y: 0)
    }
    /////////////////////////////////////////////////////////////////////////////////////
}
