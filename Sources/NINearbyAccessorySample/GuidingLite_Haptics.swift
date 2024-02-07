//
//  GuidingLite_Haptics.swift
//  Qorvo Nearby Interaction
//
//  Created by Ryan Mah on 2024-02-07.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import CoreHaptics

func ms_to_us(_ ms: UInt32) -> UInt32
{
    return ms * 1000
}

class GuidingLight_HapticsController
{
    // Haptic Engine & Player State:
    private var engine: CHHapticEngine!

    private var player: CHHapticAdvancedPatternPlayer!

    private var duty_cycle: Float = 1.0

    private var burst_duration: Float = 0.25

    private var intensity = CHHapticEventParameter( parameterID: .hapticIntensity,
                                                    value: 0.75 )

    private var sharpness = CHHapticEventParameter( parameterID: .hapticSharpness,
                                                    value: 0.5 )

    private var pattern = [CHHapticEvent]()

    private var burst_timer: Timer?

    func init_double_beep_pattern(delay: Double)
    {
        self.pattern.removeAll()

        let intensity_param = CHHapticEventParameter( parameterID: .hapticIntensity, value: 0.0 )
        let sharpness_param = CHHapticEventParameter( parameterID: .hapticSharpness, value: 0.0 )

        intensity_param.value = 0.9
        sharpness_param.value = 1.0
        let continuousEvent1 = CHHapticEvent( eventType: .hapticContinuous,
                                              parameters: [intensity_param, sharpness_param],
                                              relativeTime: 0 + delay,
                                              duration: 0.185 )

        intensity_param.value = 1.0
        sharpness_param.value = 1.0
        let continuousEvent2 = CHHapticEvent( eventType: .hapticContinuous,
                                              parameters: [intensity_param, sharpness_param],
                                              relativeTime: 0.25 + delay,
                                              duration: 0.35 )

        self.pattern.append(continuousEvent1)
        self.pattern.append(continuousEvent2)
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

    func stop_haptics()
    {
        if self.player == nil
        {
            return
        }

        do
        {
            try self.player.stop(atTime: CHHapticTimeImmediate)

            self.burst_timer?.invalidate()

            self.set_params(intensity: 0.0, sharpness: 0.0)
        }
        catch let error
        {
            print("Error stopping the engine: \(error)")
        }
    }

    func schedule_next_burst()
    {
        // 5% delay
        let delay = Double(self.burst_duration) / Double(self.duty_cycle)
        // print("burst duration: \(self.burst_duration), delay: \(delay), duty_cycle: \(self.duty_cycle)")

        self.burst_timer = Timer.scheduledTimer( timeInterval: delay,
                                                 target: self,
                                                 selector: #selector(play_haptic_burst),
                                                 userInfo: nil,
                                                 repeats: false)
    }

    @objc func play_haptic_burst()
    {
        self.schedule_next_burst()

        // Create a continuous event with a long duration from the parameters.
        let continuousEvent = CHHapticEvent( eventType: .hapticContinuous,
                                             parameters: [self.intensity, self.sharpness],
                                             relativeTime: 0,
                                             duration: TimeInterval(self.burst_duration) )

        self.play_pattern( [continuousEvent] )
    }

    init()
    {
        self.init_haptic_engine()

        self.play_continuous(intensity: 0.75, sharpness: 0.5)

        // TESTS: DELETE LATER
        _ = Timer.scheduledTimer( timeInterval: 5,
                                  target: self,
                                  selector: #selector(play_continuous_heartbeat),
                                  userInfo: nil,
                                  repeats: false )

        _ = Timer.scheduledTimer( timeInterval: 15,
                                  target: self,
                                  selector: #selector(play_double_beep),
                                  userInfo: nil,
                                  repeats: false )
    }

    // Burst duration is in ms
    func set_params( intensity: Float,
                     sharpness: Float,
                     burst_duration: Float? = nil,
                     duty_cycle: Float? = nil )
    {
        self.intensity.value = intensity
        self.sharpness.value = sharpness

        if burst_duration != nil
        {
            self.burst_duration = burst_duration!
        }

        if duty_cycle != nil
        {
            self.duty_cycle = duty_cycle!
        }

        print("intensity: \(intensity) sharpness: \(sharpness) burst_duration: \(burst_duration) duty_cycle: \(duty_cycle)")
    }

    func play_continuous(intensity: Float? = nil, sharpness: Float? = nil)
    {
        if intensity != nil && sharpness != nil
        {
            self.set_params(intensity: intensity!, sharpness: sharpness!)
        }

        self.schedule_next_burst()
    }

    @objc func play_continuous_heartbeat()
    {
        self.set_params(intensity: 0.75, sharpness: 1.0, burst_duration: 0.075, duty_cycle: 0.075)
        self.play_continuous()
    }

    @objc func play_double_beep()
    {
        self.stop_haptics()

        self.init_double_beep_pattern(delay: 1.5)
        self.play_pattern(self.pattern)
    }
}
