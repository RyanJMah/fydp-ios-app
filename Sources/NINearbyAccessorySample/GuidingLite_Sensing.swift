//
//  GuidingLite_Sensing.swift
//  Qorvo Nearby Interaction
//
//  Created by Ryan Mah on 2023-10-08.
//  Copyright © 2023 Apple. All rights reserved.
//

import Foundation
import CoreLocation

class GuidingLite_OrientationSensor: NSObject, CLLocationManagerDelegate {
    
    private let locationManager = CLLocationManager()
    
    override init()
    {
        super.init()
        
        locationManager.delegate = self
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
        return locationManager.heading?.trueHeading
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading)
    {
        // We can handle orientation update events here (if we need to in the future)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("Location manager error: \(error.localizedDescription)")
    }
}
