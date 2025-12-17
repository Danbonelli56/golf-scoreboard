//
//  ShakeDetector.swift
//  Golf Scoreboard
//
//  Created by Daniel Bonelli on 12/17/25.
//

import SwiftUI
import UIKit

/// Global shake detector that works with SwiftUI
class ShakeDetector: ObservableObject {
    static let shared = ShakeDetector()
    
    /// Callback when shake is detected - set by views that want to respond to shakes
    var onShake: (() -> Void)?
    
    /// Trigger a shake detection (called from UIWindow extension)
    func triggerShake() {
        DispatchQueue.main.async {
            self.onShake?()
        }
    }
}

/// Extension to make UIWindow detect shake gestures
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        
        if motion == .motionShake {
            ShakeDetector.shared.triggerShake()
        }
    }
}

/// View modifier that enables shake detection for a specific view
struct ShakeGestureModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                ShakeDetector.shared.onShake = action
            }
            .onDisappear {
                // Only clear if this view's action is still set
                // (prevents clearing when navigating to subviews)
            }
    }
}

extension View {
    /// Add shake gesture detection to a view
    /// When this view is visible and the device is shaken, the action will be called
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(ShakeGestureModifier(action: action))
    }
}
