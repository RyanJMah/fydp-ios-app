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

func decodeJSONString(_ jsonString: String) -> [String: Any]? {
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

class GuidingLiteViewController: UIViewController {
    @IBOutlet weak var userArrowImage: UIImageView!
    @IBOutlet weak var guidingLiteSettingsButton: UIButton!
    
    @IBOutlet weak var locationPinImage: UIImageView!
    
    @IBOutlet weak var directionArrowImage: UIImageView!
    
    @IBOutlet weak var cancelDestButton: UIButton!
    @IBOutlet weak var setDestButton: UIButton!
    @IBOutlet weak var goDestButton: UIButton!

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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        updateDirectionArrow(angle: Float(90))
        locationPinImage.isHidden = true
        
        // GuidingLite: heartbeat timer
        _ = Timer.scheduledTimer( timeInterval: 10,
                                  target: self,
                                  selector: #selector(self.send_mqtt_heartbeat),
                                  userInfo: nil,
                                  repeats: true )
        
        // Initialises the Timer used for Haptic and Sound feedbacks
        _ = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(timerHandler), userInfo: nil, repeats: true)
        
        showIPAddressInputDialog()
        
        // Do any additional setup after loading the view.
    }
    
    
    func showIPAddressInputDialog() {
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

                strongSelf.mqtt_client.initialize(ipAddress)
                strongSelf.mqtt_client.set_handler(strongSelf.mqtt_handler)
                strongSelf.mqtt_client.connect()
            }
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    @objc func timerHandler() {
        // TODO: Implement the settings page similar to Qorvo demo and add settings view so I can uncomment all this.
        // ---------------------------------------------------------
        // MQTT SHIT
//        if ( self.first_time_mqtt_init )
//        {
//            showIPAddressInputDialog()
//        }
        // ---------------------------------------------------------
        updateUserArrowPos(pos: mqtt_handler.userPosition)
        updateDirectionArrow(angle: mqtt_handler.arrowAngle)
        
        // Feedback only enabled if the Qorvo device started ranging
//        if (!appSettings.audioHapticEnabled! || feedbackDisabled ) {
//            return
//        }
        
//        if selectedAccessory == -1 {
//            return
//        }
        
//        let qorvoDevice = dataChannel.getDeviceFromUniqueID(selectedAccessory)
        
//        if qorvoDevice?.blePeripheralStatus != statusRanging {
//            return
//        }
        
        // As the timer is fast timerIndex and timerIndexRef provides a
        // pre-scaler to achieve different patterns
//        if  timerIndex != feedbackPar[feedbackLevel].timerIndexRef {
//            timerIndex += 1
//            return
//        }
       
//        timerIndex = 0

        // Handles Sound, if enabled
//        let systemSoundID: SystemSoundID = 1052
//        AudioServicesPlaySystemSound(systemSoundID)

        // Handles Haptic, if enabled
//        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
//        var events = [CHHapticEvent]()

//        let humm = CHHapticEvent(eventType: .hapticContinuous,
//                                 parameters: [],
//                                 relativeTime: 0,
//                                 duration: feedbackPar[feedbackLevel].hummDuration)
//        events.append(humm)

//        do {
//            let pattern = try CHHapticPattern(events: events, parameters: [])
//            let player = try engine?.makePlayer(with: pattern)
//            try player?.start(atTime: 0)
//        } catch {
//            logger.info("Failed to play pattern: \(error.localizedDescription).")
//        }
    }
    
    @IBAction func goButtonPressed(_ sender: UIButton) {
        print("Go Pressed!")
        // Add your logic here
        if(currDestState == S_SET_DEST) {
            self.send_mqtt_pin_location()
            currDestState = S_GO
        }
    }
    
    @IBAction func setButtonPressed(_ sender: UIButton) {
        print("set  Pressed!")
        
        updateLocationPinImage(pos: pinDefaultLocation)
        locationPinImage.isHidden = false
        currDestState = S_SET_DEST
    }
    
    @IBAction func cancelButtonPressed(_ sender: UIButton) {
        print("cancel Pressed!")
        // Add your logic here
        currDestState = S_INIT
        locationPinImage.isHidden = true
    }
    
    @objc func send_mqtt_heartbeat()
    {
        DispatchQueue.global(qos: .default).async
        {
            self.mqtt_client.publish( HEARTBEAT_TOPIC, "{status: \"online\"}" )
        }
    }
    
    @objc func send_mqtt_pin_location()
    {
        let x = pinLocation.x
        let y = pinLocation.y
        DispatchQueue.global(qos: .default).async
        {
            self.mqtt_client.publish( DEST_COORD_TOPIC, "{x: \(x), y: \(y)}" )
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Get the first touch (assuming single touch)
        if let touch = touches.first {
            // Update position when the touch begins
            updatePinPosition(for: touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Get the first touch (assuming single touch)
        if let touch = touches.first {
            // Update position while the touch is moving
            updatePinPosition(for: touch)
        }
    }

    func updatePinPosition(for touch: UITouch) {
        if(currDestState == S_SET_DEST) {
            // Only update pinLocation when setting a new destination
            pinLocation = touch.location(in: self.view)
            print("Live update - Touch coordinates: x = \(pinLocation.x), y = \(pinLocation.y)")
            if (isPointInMap(pos: pinLocation)) {
                updateLocationPinImage(pos: pinLocation)
            }
        }
    }
    
    func updateDirectionArrow(angle: Float) {
        UIView.animate(withDuration: 0.5) {
            // Convert the angle to radians
            let radians = angle * .pi / 180.0

            // Apply the rotation transform
            self.directionArrowImage.transform = CGAffineTransform(rotationAngle: CGFloat(radians))
        }
    }
    func updateUserArrowPos(pos: CGPoint) {
        var scaled_coord = CGPoint(x: (mapBottomLeft.x + pos.x), y: (mapBottomLeft.y - pos.y))
        
        // Before updating the position coordinate, make sure that this point does not exceed
        // the map bounds.
        if(scaled_coord.x >= mapTopRight.x) {
            scaled_coord.x = mapTopRight.x
        } else if(scaled_coord.x <= mapTopLeft.x) {
            scaled_coord.x = mapTopLeft.x
        }
        
        if(scaled_coord.y >= mapBottomRight.y) {
            scaled_coord.y = mapBottomRight.y
        } else if(scaled_coord.y <= mapTopRight.y) {
            scaled_coord.y = mapTopRight.y
        }
        
        
        userArrowImage.frame.origin = scaled_coord
    }
    func updateLocationPinImage(pos: CGPoint) {
        locationPinImage.frame.origin = pos
    }
    func isPointInMap(pos: CGPoint) -> Bool {
        let x = pos.x
        let y = pos.y
        
        if((x >= mapTopLeft.x) && (x <= mapTopRight.x) && (y >= mapTopLeft.y) && (y <= mapBottomLeft.y)) {
            return true
        }
        return false
    }
    
    // Returns the current position of the user arrow relative to the map area.
    func getUserArrowPos() -> CGPoint {
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
