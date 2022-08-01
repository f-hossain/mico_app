//
//  ViewController.swift
//  MICO
//
//  Created by Fariha Hossain on 2022-03-15.
//

import AVFoundation
import UIKit
import CoreBluetooth
import Photos

let MICOServiceCBUUID = CBUUID(string: "180A") // service used to scan for MICO device
let MICOReadCharacteristicCBUUID = CBUUID(string: "2A58") // characteristic to read & notify
let MICOWriteCharacteristicCBUUID = CBUUID(string: "2A57") // characteristic to write value to peripheral -> triggers circuit
var globalUUID: CBCharacteristic!

class ViewController: UIViewController {
    
    var centralManager: CBCentralManager! // instance variable -> creates the CBCentralManager for use
    var heartRatePeripheral: CBPeripheral! // initialize the peripheral instance so we know when to stop scanning

    // capture session
    var session: AVCaptureSession? // ? makes it optional, will need to create this below
    
    // photo output
    let output = AVCapturePhotoOutput()
    
    // video preview
    let previewLayer = AVCaptureVideoPreviewLayer() // preview for camera feed, layer we'll add camera feed session to, to render it on the UI
    
    // shutter button
    let shutterButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let largeConfig = UIImage.SymbolConfiguration(textStyle: .largeTitle)
        let camIcon = UIImage(systemName: "camera", withConfiguration: largeConfig)
        
        button.layer.cornerRadius = 50
        button.layer.borderWidth = 3
        button.setImage(camIcon, for: .normal)
        button.layer.borderColor = UIColor.white.cgColor
        button.tintColor = UIColor.white
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        centralManager = CBCentralManager(delegate: self, queue: nil) // initializes new CBCentralManager
        view.backgroundColor = .black
        previewLayer.backgroundColor = UIColor.systemRed.cgColor
        view.layer.addSublayer(previewLayer)
        view.addSubview(shutterButton)
        checkCameraPermissions()
        
        shutterButton.addTarget(self, action: #selector(didTapTakePhoto), for: .touchUpInside)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        
        shutterButton.center = CGPoint(x: view.frame.size.width/2, y: view.frame.size.height - 100)
    }
    
    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            // request the permissions
            // inputs you can give to a capture session, i.e. photo, video, etc.
            AVCaptureDevice.requestAccess(for: .video) { granted in
                guard granted else {
                    return
                }
                DispatchQueue.main.async {
                    self.setUpCamera()
                }
            }
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            setUpCamera()
        @unknown default:
            break
        }
    }
    
    private func setUpCamera() {
        let session = AVCaptureSession()
        if let device = AVCaptureDevice.default(for: .video) {
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }
                
                // now need output when we try to take a photo
                
                if session.canAddOutput(output) {
                    session.addOutput(output)
                }
                
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.session = session
                
                session.startRunning()
                self.session = session
            }
            catch {
                print(error)
            }
        }
        
    }
    
    @objc private func didTapTakePhoto() {
         let yawp = self.triggerFlash(from: globalUUID)
//        self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            /// add delays
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
        
    }
}


// handles central device
extension ViewController: CBCentralManagerDelegate {
  
  // handles different states of the central manager
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
      case .unknown:
        print("central.state is .unknown")
      case .resetting:
        print("central.state is .resetting")
      case .unsupported:
        print("central.state is .unsupported")
      case .unauthorized:
        print("central.state is .unauthorized")
      case .poweredOff:
        print("central.state is .poweredOff")
      case .poweredOn:
        print("central.state is .poweredOn")
//        centralManager.scanForPeripherals(withServices: [heartRateServiceCBUUID]) // use with services to be able to find a single peripheral
          centralManager.scanForPeripherals(withServices: [MICOServiceCBUUID])
    }
  }
  
  // after scan of devices - shows list of discovered peripherals
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                      advertisementData: [String: Any], rssi RSSI: NSNumber) {
    // output form:
    // <CBPeripheral: 0x1c4105fa0, identifier = D69A9892-...21E4, name = Your Computer Name, state = disconnected>
    print(peripheral)
    heartRatePeripheral = peripheral // should only discover a single peripheral to be set, can then stop scan
    heartRatePeripheral.delegate = self // point heart rate peripheral as the delegate
    centralManager.stopScan()
    centralManager.connect(heartRatePeripheral)
  }
  
  // delegate to ensure device has been successfully connected
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print("Connected!")
    heartRatePeripheral.discoverServices(nil) // passing in nil discovers all service
//      heartRatePeripheral.discoverServices([heartRateServiceCBUUID])

  }
}

extension ViewController: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let services = peripheral.services else { return }
    for service in services {
      print(service)
//      print(service.characteristics ?? "characteristics are nil")
      peripheral.discoverCharacteristics(nil, for: service)
      print("discovering..")
    }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                  error: Error?) {
    guard let characteristics = service.characteristics else { return }
    for characteristic in characteristics {
      print(characteristic)
      if characteristic.properties.contains(.read) {
        print("\(characteristic.uuid): properties contains .read")
        peripheral.readValue(for: characteristic)
      }
      if characteristic.properties.contains(.notify) {
        print("\(characteristic.uuid): properties contains .notify")
        peripheral.setNotifyValue(true, for: characteristic)
      }
      if characteristic.properties.contains(.write) {
        print("\(characteristic.uuid): properties contains .write")
      }
    }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                  error: Error?) {
    switch characteristic.uuid {
      case MICOWriteCharacteristicCBUUID:
        globalUUID = characteristic
//        let yawp = triggerFlash(from: characteristic)
//        print("DID IT WORK?? : " + String(yawp))
      case MICOReadCharacteristicCBUUID:
        print("aight..")
      default:
        print("Unhandled Characteristic UUID: \(characteristic.uuid)")
    }
  }
  
func triggerFlash(from characteristic: CBCharacteristic) -> Int {
    print("writing..")
    let writeChar: UInt8 = 1
    let data = Data(bytes: [writeChar])
//        let byteChar = [UInt8](writeChar)
    heartRatePeripheral.writeValue(data, for: characteristic, type: .withResponse)
    return 1
  }
}

private var photoData: Data?

extension ViewController: AVCapturePhotoCaptureDelegate {
    
//    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
//      // Flash the screen to signal that the camera took a photo.
//      self.previewView.videoPreviewLayer.opacity = 0
//      UIView.animate(withDuration: 0.25) {
//        self.previewView.videoPreviewLayer.opacity = 1
//      }
//    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else {
            return
        }
        let image = UIImage(data: data)
        photoData = photo.fileDataRepresentation()
        
        let imageView = UIImageView(image: image)
        
        session?.stopRunning()
        
        imageView.contentMode = .scaleAspectFill
        imageView.frame = view.bounds
        view.addSubview(imageView)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
          print("Error capturing photo: \(error)")
          return
        }
        
        guard let photoData = photoData else {
          print("No photo data resource")
          return
        }
        
        PHPhotoLibrary.requestAuthorization { status in
          if status == .authorized {
            PHPhotoLibrary.shared().performChanges({
              let options = PHAssetResourceCreationOptions()
              let creationRequest = PHAssetCreationRequest.forAsset()
              creationRequest.addResource(with: .photo, data: photoData, options: options)
              
            }, completionHandler: { _, error in
              if let error = error {
                print("Error occurred while saving photo to photo library: \(error)")
              }
            })
          }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("reloading..")
            self.session?.startRunning()
            /// add delays
            self.view.layer.addSublayer(self.previewLayer)
            self.view.addSubview(self.shutterButton)
            self.checkCameraPermissions()
            self.shutterButton.addTarget(self, action: #selector(self.didTapTakePhoto), for: .touchUpInside)
            super.viewDidLayoutSubviews()
        }
      }
}


