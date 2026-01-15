import Foundation
import Combine

/// US-516: Manages first launch detection for onboarding wizard
/// Provides isFirstLaunch detection and hasCompletedOnboarding flag management
@MainActor
final class OnboardingManager: ObservableObject {
    
    // MARK: - Constants
    
    private enum Constants {
        /// UserDefaults key for tracking onboarding completion
        static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    }
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide onboarding state management
    static let shared = OnboardingManager()
    
    // MARK: - Published Properties
    
    /// Whether the user has completed or skipped the onboarding wizard
    /// First launch: flag is nil or false (isFirstLaunch returns true)
    /// Subsequent launches: flag is true (isFirstLaunch returns false)
    @Published private(set) var hasCompletedOnboarding: Bool
    
    // MARK: - Computed Properties
    
    /// Check if this is the first launch of the application
    /// Returns true if hasCompletedOnboarding flag is nil or false
    /// Returns false if hasCompletedOnboarding flag is true
    var isFirstLaunch: Bool {
        return !hasCompletedOnboarding
    }
    
    // MARK: - Initialization
    
    private init() {
        // Check UserDefaults for hasCompletedOnboarding flag
        // First launch: flag is nil (object(forKey:) returns nil), default to false
        // Subsequent launches: flag is true
        let storedValue = UserDefaults.standard.object(forKey: Constants.hasCompletedOnboardingKey) as? Bool
        self.hasCompletedOnboarding = storedValue ?? false
        
        print("OnboardingManager: [US-516] Initialized - hasCompletedOnboarding: \(hasCompletedOnboarding), isFirstLaunch: \(isFirstLaunch)")
    }
    
    // MARK: - Public API
    
    /// Mark onboarding as completed
    /// Called when user completes or skips the onboarding wizard
    /// Sets hasCompletedOnboarding flag to true in UserDefaults
    func markOnboardingCompleted() {
        guard !hasCompletedOnboarding else {
            print("OnboardingManager: [US-516] Onboarding already marked as completed")
            return
        }
        
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: Constants.hasCompletedOnboardingKey)
        UserDefaults.standard.synchronize()
        
        print("OnboardingManager: [US-516] Onboarding marked as completed")
    }
    
    /// Mark onboarding as skipped
    /// Equivalent to markOnboardingCompleted but with different logging
    /// Called when user chooses to skip the onboarding wizard
    func markOnboardingSkipped() {
        guard !hasCompletedOnboarding else {
            print("OnboardingManager: [US-516] Onboarding already marked as completed")
            return
        }
        
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: Constants.hasCompletedOnboardingKey)
        UserDefaults.standard.synchronize()
        
        print("OnboardingManager: [US-516] Onboarding skipped - marked as completed")
    }
    
    /// Reset onboarding state (for testing/debug purposes)
    /// Clears the hasCompletedOnboarding flag, making the next launch appear as first launch
    func resetOnboardingState() {
        hasCompletedOnboarding = false
        UserDefaults.standard.removeObject(forKey: Constants.hasCompletedOnboardingKey)
        UserDefaults.standard.synchronize()
        
        print("OnboardingManager: [US-516] Onboarding state reset - isFirstLaunch: \(isFirstLaunch)")
    }
}
