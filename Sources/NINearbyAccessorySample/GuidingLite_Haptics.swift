//
//  GuidingLite_Haptics.swift
//  Qorvo Nearby Interaction
//
//  Created by Ryan Mah on 2024-02-07.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import CoreHaptics

let DEFAULT_BURST_DURATION: Float = 0.25

func ms_to_us(_ ms: UInt32) -> UInt32
{
    return ms * 1000
}

class GuidingLight_HapticsController
{
    // Haptic Engine & Player State:
    private var engine: CHHapticEngine!

    private var player: CHHapticAdvancedPatternPlayer!

    private var burst_duration: TimeInterval = TimeInterval(DEFAULT_BURST_DURATION)

    private var intensity = CHHapticEventParameter( parameterID: .hapticIntensity,
                                                    value: 0.5 )

    private var sharpness = CHHapticEventParameter( parameterID: .hapticSharpness,
                                                    value: 0.5 )

    private var double_beep_pattern = [CHHapticEvent]()

    func init_double_beep_pattern()
    {
        self.set_params(intensity: 100, sharpness: 100)
        let continuousEvent1 = CHHapticEvent( eventType: .hapticContinuous,
                                              parameters: [self.intensity, self.sharpness],
                                              relativeTime: 0,
                                              duration: 0.185 )

        self.set_params(intensity: 100, sharpness: 100)
        let continuousEvent2 = CHHapticEvent( eventType: .hapticContinuous,
                                              parameters: [self.intensity, self.sharpness],
                                              relativeTime: 0.25,
                                              duration: 0.35 )

        self.double_beep_pattern.append(continuousEvent1)
        self.double_beep_pattern.append(continuousEvent2)
    }

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

    func schedule_next_burst()
    {
        _ = Timer.scheduledTimer( timeInterval: self.burst_duration,
                                  target: self,
                                  selector: #selector(play_haptic_burst),
                                  userInfo: nil,
                                  repeats: false )
    }

    func play_pattern(_ pattern: [CHHapticEvent])
    {
        do
        {
            // Create a pattern from the continuous haptic event.
            let pattern = try CHHapticPattern(events: pattern, parameters: [])

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

    @objc func play_haptic_burst()
    {
        // Create a continuous event with a long duration from the parameters.
        let continuousEvent = CHHapticEvent( eventType: .hapticContinuous,
                                             parameters: [self.intensity, self.sharpness],
                                             relativeTime: 0,
                                             duration: self.burst_duration )

        self.play_pattern( [continuousEvent] )

        self.schedule_next_burst()
    }

    init()
    {
        init_double_beep_pattern()

        init_haptic_engine()

        // self.schedule_next_burst()

        self.play_double_beep()
    }

    // Burst duration is in ms
    func set_params(intensity: Int, sharpness: Int, burst_duration: Float = DEFAULT_BURST_DURATION)
    {
        self.intensity.value = Float(intensity) / 100.0
        self.sharpness.value = Float(sharpness) / 100.0
        self.burst_duration = TimeInterval(burst_duration) / 1000.0
    }

    func get_intensity() -> Int
    {
        return Int(self.intensity.value * 100)
    }

    func get_sharpness() -> Int
    {
        return Int(self.sharpness.value * 100)
    }

    func get_burst_duration() -> Float
    {
        return Float(self.burst_duration)
    }

    func play_double_beep()
    {
        self.play_pattern(self.double_beep_pattern)
    }
}
