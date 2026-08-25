import AVFoundation

class TorchController {
    private let device = AVCaptureDevice.default(for: .video)

    /// Turns the torch on or off.
    /// - Parameter on: Pass `true` to turn on, `false` to turn off.
    func setTorch(on: Bool) -> Bool {
        guard let device = device, device.hasTorch else { return false }
        do {
            try device.lockForConfiguration()
            
            defer { device.unlockForConfiguration() }
            
            if on && device.isTorchModeSupported(.on) {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            
            return true
        } catch {
            print("TorchController: Unable to set torch: \(error)")
            
            return false
        }
    }
}
