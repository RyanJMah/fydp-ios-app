//
//  GuidingLiteViewController.swift
//  Qorvo Nearby Interaction
//
//  Created by Mohammad Dabbah on 2024-01-21.
//  Copyright © 2024 Apple. All rights reserved.
//

import UIKit
import SceneKit

protocol DirArrowProtocol {
    func switchArrowImgView()
}

class GuidingLiteViewController: UIViewController, DirArrowProtocol {
    @IBOutlet weak var userArrowImage: UIImageView!
    @IBOutlet weak var guidingLiteSettingsButton: UIButton!
    
    @IBOutlet weak var locationPinImage: UIImageView!
    
    @IBOutlet weak var directionArrowImage: UIImageView!
    
    @IBOutlet weak var arrowImgView: SCNView!
    
    @IBOutlet weak var cancelDestButton: UIButton!
    @IBOutlet weak var setDestButton: UIButton!
    @IBOutlet weak var goDestButton: UIButton!

    let S_INIT = 0
    let S_SET_DEST = 1
    let S_GO = 2
    var currDestState: Int = 0
    
    @IBAction func goButtonPressed(_ sender: UIButton) {
        print("Go Pressed!")
        // Add your logic here
        currDestState = S_GO
        // Send Dest coords over MQTT to server
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
    // Map borders
    let mapTopLeft      = CGPoint(x: 10,    y: 375)
    let mapTopRight     = CGPoint(x: 359,   y: 375)
    let mapBottomLeft   = CGPoint(x: 10,    y: 736)
    let mapBottomRight  = CGPoint(x: 359,   y: 736)
    
    let pinDefaultLocation = CGPoint(x: 189, y: 464)
    
    let scene = SCNScene(named: "3d_arrow.usdz")
    
    // Auxiliary variables to handle the 3D arrow
    var curAzimuth: Int = 0
    var curElevation: Int = 0
    var curSpin: Int = 0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startArrowImgView()
//        updateDirectionArrow(rotation: CGFloat(0))
        locationPinImage.isHidden = true
        
        // Do any additional setup after loading the view.
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
        // Get the location of the touch in the view's coordinate system
        let touchLocation = touch.location(in: self.view)

        // Print or use the live update of touch coordinates
        // Only update the pin location when SETTING location. IF we are in the middle
        // of a navigation sequence, pin should not move
        if(currDestState != S_GO) {
            print("Live update - Touch coordinates: x = \(touchLocation.x), y = \(touchLocation.y)")
            let touchPoint = CGPoint(x: touchLocation.x, y: touchLocation.y)
            if (isPointInMap(pos: touchPoint)) {
                updateLocationPinImage(pos: touchPoint)
            }
        }
    }
    
    // MARK: - Arrow methods
    func startArrowImgView() {
        // Creating and adding ambien light to scene
        scene?.rootNode.light = SCNLight()
        scene?.rootNode.light?.type = .ambient
        scene?.rootNode.light?.color = UIColor.darkGray
        
        // AR settings
        arrowImgView.autoenablesDefaultLighting = true
        arrowImgView.allowsCameraControl = false
        arrowImgView.backgroundColor = .white
        
        // Set scene settings
        arrowImgView.scene = scene
        initArrowPosition()
        switchArrowImgView()

//        arrowImgView.isHidden = true
    }
    
    func switchArrowImgView() {
        if appSettings.arrowEnabled! {
            arrowImgView.autoenablesDefaultLighting = true
            scene?.rootNode.light?.color = UIColor.darkGray
        }
        else {
            arrowImgView.autoenablesDefaultLighting = false
            scene?.rootNode.light?.color = UIColor.black
        }
    }
    
    func setArrowAngle(newElevation: Int, newAzimuth: Int) {
        let oneDegree = 1.0 * Float.pi / 180.0
        var deltaX, deltaY, deltaZ: Int

        if(appSettings.arrowEnabled!){
            deltaX = newElevation - curElevation
            deltaY = newAzimuth - curAzimuth
            deltaZ = 0 - curSpin
            
            curElevation = newElevation
            curAzimuth = newAzimuth
            curSpin = 0
        } else {
            deltaX = 90 - curElevation
            deltaY = 0 - curAzimuth
            deltaZ = newAzimuth - curSpin
            
            curElevation = 90
            curAzimuth = 0
            curSpin = newAzimuth
        }
        
        arrowImgView.scene?.rootNode.eulerAngles.x += Float(deltaX) * oneDegree
        arrowImgView.scene?.rootNode.eulerAngles.y -= Float(deltaY) * oneDegree
        arrowImgView.scene?.rootNode.eulerAngles.z -= Float(deltaZ) * oneDegree
    }
    
    func initArrowPosition() {
        let degree = 1.0 * Float.pi / 180.0

        arrowImgView.scene?.rootNode.eulerAngles.x = -90 * degree
        arrowImgView.scene?.rootNode.eulerAngles.y = 0
        arrowImgView.scene?.rootNode.eulerAngles.z = 0

        curAzimuth = 0
        curElevation = 0
        curSpin = 0
    }
    
    func updateUserArrowPos(pos: CGPoint) {
        userArrowImage.frame.origin = pos
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
