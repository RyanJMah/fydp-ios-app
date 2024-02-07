//
//  GuidingLite_Haptics.swift
//  Qorvo Nearby Interaction
//
//  Created by Ryan Mah on 2024-02-07.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import CoreHaptics

class GuidingLight_HapticsController
{
    // Haptic Engine & Player State:
    private var engine: CHHapticEngine!

    private var player: CHHapticAdvancedPatternPlayer!

    private var burst_duration: TimeInterval = 0.25

    private var intensity: Float = 1.0
    private var sharpness: Float = 0.5

    func init_haptic_engine()
    {
        // Create and configure a haptic engine.
        do
        {
            engine = try CHHapticEngine()
        }
        catch let error
        {
            fatalError("Engine Creation Error: \(error)")
        }

        // Mute audio to reduce latency for collision haptics.
        engine.playsHapticsOnly = true

        // The stopped handler alerts you of engine stoppage.
        engine.stoppedHandler = { reason in
            print("Stop Handler: The engine stopped for reason: \(reason.rawValue)")

            switch reason
            {
                case .audioSessionInterrupt:
                    print("Audio session interrupt")

                case .applicationSuspended:
                    print("Application suspended")

                case .idleTimeout:
                    print("Idle timeout")

                case .systemError:
                    print("System error")

                case .notifyWhenFinished:
                    print("Playback finished")

                case .gameControllerDisconnect:
                    print("Controller disconnected.")

                case .engineDestroyed:
                    print("Engine destroyed.")

                @unknown default:
                    print("Unknown error")
            }
        }

        // The reset handler provides an opportunity to restart the engine.
        engine.resetHandler = {

            print("Reset Handler: Restarting the engine.")

            do
            {
                // Try restarting the engine.
                try self.engine.start()

                // // Indicate that the next time the app requires a haptic, the app doesn't need to call engine.start().

                // // Recreate the continuous player.
                // self.create_continuous_haptic_player()
            }
            catch {
                print("Failed to start the engine")
            }
        }

        // Start the haptic engine for the first time.
        do
        {
            try self.engine.start()
        }
        catch
        {
            print("Failed to start the engine: \(error)")
        }
    }


    init()
    {
        init_haptic_engine()

        _ = Timer.scheduledTimer( timeInterval: self.burst_duration,
                                  target: self,
                                  selector: #selector(play_haptic_burst),
                                  userInfo: nil,
                                  repeats: true )
    }

    @objc func play_haptic_burst()
    {
        // Create an intensity parameter:
        let intensity = CHHapticEventParameter( parameterID: .hapticIntensity,
                                                value: self.intensity )

        // Create a sharpness parameter:
        let sharpness = CHHapticEventParameter( parameterID: .hapticSharpness,
                                                value: self.sharpness )

        // Create a continuous event with a long duration from the parameters.
        let continuousEvent = CHHapticEvent( eventType: .hapticContinuous,
                                             parameters: [intensity, sharpness],
                                             relativeTime: 0,
                                             duration: self.burst_duration )

        do
        {
            // Create a pattern from the continuous haptic event.
            let pattern = try CHHapticPattern(events: [continuousEvent], parameters: [])

            // Create a player from the continuous haptic pattern.
            self.player = try engine.makeAdvancedPlayer(with: pattern)
        }
        catch let error
        {
            print("Pattern Player Creation Error: \(error)")
        }

        self.player.completionHandler = { _ in }

        do
        {
            // Begin playing continuous pattern.
            try self.player.start(atTime: CHHapticTimeImmediate)
        }
        catch let error
        {
            print("Error starting the continuous haptic player: \(error)")
        }
    }

    // Contains example code for adjusting the intensity and sharpness of a continuous haptic pattern,
    // not used right now though
    private func adjust_haptics()
    {
        // The intensity should be highest at the top, opposite of the iOS y-axis direction, so subtract.
        let dynamicIntensity: Float = 0.2

        // Dynamic parameters range from -0.5 to 0.5 to map the final sharpness to the [0,1] range.
        let dynamicSharpness: Float = 0

        // Create dynamic parameters for the updated intensity & sharpness.
        let intensityParameter = CHHapticDynamicParameter( parameterID: .hapticIntensityControl,
                                                           value: dynamicIntensity,
                                                           relativeTime: 0)

        let sharpnessParameter = CHHapticDynamicParameter( parameterID: .hapticSharpnessControl,
                                                           value: dynamicSharpness,
                                                           relativeTime: 0)

        // Send dynamic parameters to the haptic player.
        do
        {
            try self.player.sendParameters([intensityParameter, sharpnessParameter], atTime: 0)
        }
        catch let error
        {
            print("Dynamic Parameter Error: \(error)")
        }

        // Warm engine.
        do
        {
            // Begin playing continuous pattern.
            try self.player.start(atTime: CHHapticTimeImmediate)
        }
        catch let error
        {
            print("Error starting the continuous haptic player: \(error)")
        }

        // Stop playing the haptic pattern.
        // do
        // {
        //     try self.player.stop(atTime: CHHapticTimeImmediate)
        // }
        // catch let error
        // {
        //     print("Error stopping the continuous haptic player: \(error)")
        // }
    }
}
