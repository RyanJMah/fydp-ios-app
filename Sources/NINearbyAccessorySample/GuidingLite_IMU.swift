//
//  GuidingLite_IMU.swift
//  Qorvo Nearby Interaction
//
//  Created by Ryan Mah on 2023-10-08.
//  Copyright © 2023 Apple. All rights reserved.
//

import UIKit
import Foundation
import CoreLocation

class GuidingLite_HeadingSensor: NSObject, CLLocationManagerDelegate {
    
    private let locationManager = CLLocationManager()
    
    override init()
    {
        super.init()
        
        locationManager.delegate = self

        locationManager.headingOrientation = CLDeviceOrientation.faceUp

        locationManager.startUpdatingHeading()
        
        if ( CLLocationManager.headingAvailable() )
        {
            locationManager.headingFilter = 3.0
        }
        else
        {
            print("Heading information is not available on this device.")
        }
    }
    
    func get_orientation() -> CLLocationDirection?
    {
        // return locationManager.heading?.magneticHeading
        return locationManager.heading?.trueHeading
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading)
    {
        // We can handle orientation update events here (if we need to in the future)
        if newHeading.headingAccuracy < 0 || newHeading.headingAccuracy > 30 {
            // Heading accuracy is poor, suggest recalibration
//            displayRecalibrationAlert()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("Location manager error: \(error.localizedDescription)")
    }

//    func displayRecalibrationAlert() {
//        let alertController = UIAlertController(title: "Compass Accuracy", message: "Compass accuracy is poor. Consider recalibrating.", preferredStyle: .alert)
//        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
//        // Present the alert on the topmost view controller
//        UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
//    }
}
