import Testing
import CoreGraphics
@testable import ClosetUI

@Suite("DepthParallax")
struct DepthParallaxTests {
    @Test func clampKeepsUnitRange() {
        #expect(DepthParallaxSample.clamp(2) == 1)
        #expect(DepthParallaxSample.clamp(-3) == -1)
        #expect(DepthParallaxSample.clamp(0.25) == 0.25)
    }

    @Test func sampleClampsOnInit() {
        let s = DepthParallaxSample(x: 5, y: -9)
        #expect(s.x == 1)
        #expect(s.y == -1)
    }

    @Test func attitudeMapsToSample() {
        let s = DepthParallaxSample.fromAttitude(roll: 0.2, pitch: -0.1, gain: 2.0)
        #expect(s.x > 0)
        #expect(s.y > 0)
    }

    @Test func ambientIsBounded() {
        let s = DepthParallaxSample.ambient(time: 1.25, amplitude: 0.3)
        #expect(abs(s.x) <= 0.3 + 0.001)
        #expect(abs(s.y) <= 0.3 + 0.001)
        let z = DepthParallaxSample.ambient(time: 0, amplitude: 0)
        #expect(z.x == 0 && z.y == 0)
    }

    @Test func layoutTravelScalesWithIntensity() {
        let s = DepthParallaxSample(x: 1, y: -1)
        let cine = DepthParallaxLayout.backgroundOffset(s, intensity: .cinematic)
        let sub = DepthParallaxLayout.backgroundOffset(s, intensity: .subtle)
        let off = DepthParallaxLayout.backgroundOffset(s, intensity: .off)
        #expect(abs(cine.width) > abs(sub.width))
        #expect(off == .zero)
        #expect(DepthParallaxIntensity.cinematic.backgroundBlur > DepthParallaxIntensity.subtle.backgroundBlur)
    }

    @Test func offsetDirection() {
        let s = DepthParallaxSample(x: 1, y: 0.5)
        let o = s.offset(travel: 10)
        #expect(o.width == 10)
        #expect(o.height == 5)
    }
}
