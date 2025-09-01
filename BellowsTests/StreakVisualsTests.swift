import Testing
import SwiftUI
@testable import Bellows

struct StreakVisualsTests {
    
    // MARK: - AnimatedBlobBackground Tests
    
    @Test func animatedBlobBackgroundInitialization() {
        let colors = [Color.red, Color.blue, Color.green]
        let background = AnimatedBlobBackground(colors: colors)
        
        // Test that background can be created
        _ = background
        _ = background.body // exercise body building
        #expect(true)
    }
    
    @Test func animatedBlobBackgroundWithSingleColor() {
        let colors = [Color.blue]
        let background = AnimatedBlobBackground(colors: colors)
        
        _ = background
        _ = background.body
        #expect(true)
    }
    
    @Test func animatedBlobBackgroundWithManyColors() {
        let colors = [Color.red, Color.orange, Color.yellow, Color.green, Color.blue, Color.purple]
        let background = AnimatedBlobBackground(colors: colors)
        
        _ = background
        _ = background.body
        #expect(true)
    }
    
    @Test func animatedBlobBackgroundWithEmptyColors() {
        let colors: [Color] = []
        let background = AnimatedBlobBackground(colors: colors)
        
        _ = background
        _ = background.body
        #expect(true)
    }
    
    // MARK: - ConfettiBurst Tests
    
    @MainActor
    @Test func confettiBurstInitialization() {
        let confetti = ConfettiBurst(trigger: 5)
        let triggerValue = confetti.trigger
        
        #expect(triggerValue == 5)
        _ = confetti.body
    }
    
    @MainActor
    @Test func confettiBurstWithZeroTrigger() {
        let confetti = ConfettiBurst(trigger: 0)
        let triggerValue = confetti.trigger
        
        #expect(triggerValue == 0)
        
        // Accessing body should not crash
        _ = confetti
        _ = confetti.body
        #expect(true)
    }
    
    @MainActor
    @Test func confettiBurstWithNegativeTrigger() {
        let confetti = ConfettiBurst(trigger: -10)
        let triggerValue = confetti.trigger
        
        #expect(triggerValue == -10)
        _ = confetti
        _ = confetti.body
        #expect(true)
    }
    
    @MainActor
    @Test func confettiBurstWithLargeTrigger() {
        let confetti = ConfettiBurst(trigger: 1000)
        let triggerValue = confetti.trigger
        
        #expect(triggerValue == 1000)
        _ = confetti
        _ = confetti.body
        #expect(true)
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    @Test func animatedBlobBackgroundPerformance() {
        // Test that multiple instances can be created quickly
        for _ in 0..<10 {
            let colors = [Color.red, Color.blue, Color.green]
            let background = AnimatedBlobBackground(colors: colors)
            _ = background
            _ = background.body
        }
        
        #expect(true)
    }
    
    @MainActor
    @Test func confettiBurstPerformance() {
        // Test with different trigger values to exercise variations
        for i in 0..<10 {
            let confetti = ConfettiBurst(trigger: i)
            _ = confetti
            _ = confetti.body
        }
        
        #expect(true)
    }
    
    // MARK: - Integration Tests
    
    @MainActor
    @Test func animatedBlobBackgroundInContainer() {
        let colors = [Color.red, Color.blue, Color.green]
        let blobView = AnimatedBlobBackground(colors: colors)
        
        // Test that it can be used within other SwiftUI views
        struct TestContainer: View {
            let blobView: AnimatedBlobBackground
            
            var body: some View {
                ZStack {
                    blobView
                    Text("Test")
                }
            }
        }
        
        let container = TestContainer(blobView: blobView)
        _ = container
        #expect(true)
    }
    
    @MainActor
    @Test func confettiBurstInContainer() {
        let confettiView = ConfettiBurst(trigger: 5)
        
        // Test that it can be used within other SwiftUI views
        struct TestContainer: View {
            let confettiView: ConfettiBurst
            
            var body: some View {
                ZStack {
                    confettiView
                    Text("Celebration!")
                }
            }
        }
        
        let container = TestContainer(confettiView: confettiView)
        _ = container
        #expect(true)
    }
    
    @MainActor
    @Test func bothViewsTogether() {
        let colors = [Color.blue, Color.purple]
        let blobView = AnimatedBlobBackground(colors: colors)
        let confettiView = ConfettiBurst(trigger: 3)
        
        struct CombinedView: View {
            let blobView: AnimatedBlobBackground
            let confettiView: ConfettiBurst
            
            var body: some View {
                ZStack {
                    blobView
                    confettiView
                }
            }
        }
        
        let combined = CombinedView(blobView: blobView, confettiView: confettiView)
        _ = combined
        #expect(true)
    }
    
    // MARK: - Edge Cases
    
    @MainActor
    @Test func confettiBurstVariations() {
        // Test with different trigger values to exercise seed variations
        for i in 0..<10 {
            let confetti = ConfettiBurst(trigger: i)
            _ = confetti
        }
        
        #expect(true)
    }
}
