//
//  ViewController.swift
//  realWorld
//
//  Created by 周测 on 9/20/19.
//  Copyright © 2019 aiQG_. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
	var temp: Int = 0 //记一下丢弃的缓冲
	@IBOutlet weak var mainImageView: UIImageView!
	@IBOutlet weak var showFace: UIImageView!
	var mainSession = AVCaptureSession()
	var requests = [VNRequest]()
	
	var boxX: CGFloat!
	var boxY: CGFloat!
	var boxW: CGFloat!
	var boxH: CGFloat!
	var imageTemp: UIImage!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view.
		startVideo()
		startDetection()
	}
	
	func startVideo() {
		//一个获取photo的session
		mainSession.sessionPreset = AVCaptureSession.Preset.photo
		//从硬件获取video
		let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)//(for: AVMediaType.video)//设置前置
		
		//给session加入输入输出
		let deviceInput = try! AVCaptureDeviceInput(device: captureDevice!)
		let deviceOutput = AVCaptureVideoDataOutput()
		deviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
		deviceOutput.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.default))//这里处理
		mainSession.addInput(deviceInput)
		mainSession.addOutput(deviceOutput)
		
		//显示控件
		let imageLayer = AVCaptureVideoPreviewLayer(session: mainSession)
		imageLayer.frame = mainImageView.bounds
		mainImageView.layer.addSublayer(imageLayer)
		mainSession.startRunning()
	}

	func startDetection() {
		
		let faceRequest = VNDetectFaceRectanglesRequest(completionHandler: self.detectFaceHandler)
		
		self.requests = [faceRequest]
	}
	
	func detectFaceHandler(request: VNRequest, error: Error?) {
		guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
			  let results = faceDetectionRequest.results as? [VNFaceObservation] else {
						   return
				   }
		DispatchQueue.main.sync() {
			if results.count > 0 {
				
				self.mainImageView.layer.sublayers?.removeSubrange(1...)
				self.getFaceBoundingBox(aResult: results[0])//只选定第一个结果
				
			}
			else if(boxH != nil || boxX != nil || boxY != nil || boxW != nil) {//无结果时初始化框框
				boxH = nil
				boxX = nil
				boxY = nil
				boxW = nil
				self.mainImageView.layer.sublayers?.removeSubrange(1...)
			}
		}
	}
	
	func getFaceBoundingBox(aResult: VNFaceObservation) {
		let box = aResult.boundingBox
        let outline = CALayer()
		boxX = box.origin.x
		boxY = box.origin.y
		boxW = box.width
		boxH = box.height
		let newR = CGRect(x: boxX * mainImageView.frame.size.width,
						  y: boxY * mainImageView.frame.size.height,
						  width: boxW * mainImageView.frame.size.width,
						  height: boxH * mainImageView.frame.size.height)
		outline.frame = newR
        outline.borderWidth = 2.0
		outline.borderColor = UIColor.red.cgColor

		
		//mainImageView.contentMode = UIView.ContentMode.topLeft
        mainImageView.layer.addSublayer(outline)
		
    }
}



extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate{
	
	func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		//print("give up \(temp)") //丢弃缓冲数据
		//temp = 1 + temp
	}
	//sampleBuffer是得到的图片
	func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
		//print("get it")
		guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
			return
		}
		
		var requestOptions:[VNImageOption: Any] = [:]
		
		if let camData = CMGetAttachment(sampleBuffer,key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil){
			requestOptions = [VNImageOption.cameraIntrinsics: camData]
		}
		
		let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: CGImagePropertyOrientation(rawValue: 8)!, options: requestOptions)
		
		do{
			try imageRequestHandler.perform(self.requests)
		} catch {
			print(error)
		}
		
		
	
		
		
		DispatchQueue.main.sync {
			//showFace
			let imageBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
			let ciImage: CIImage = CIImage(cvPixelBuffer: imageBuffer)
			let image: UIImage = self.convert(cmage: ciImage)
			if(boxH == nil || boxX==nil || boxY==nil || boxW==nil){
				showFace.image = nil
				return
			}
			let cgImage = image.cgImage!
			let aCGRect = CGRect(x: boxY * image.size.height,
								 y: boxX * image.size.width,
								 width: boxW * image.size.width,
								 height: boxH * image.size.height)
			guard let cgImageCro: CGImage = cgImage.cropping(to: aCGRect) else{
				return
			}
			let faceUIImageOri = UIImage(cgImage: cgImageCro, scale: 0.5, orientation: .leftMirrored)
			//get face
			
			showFace.image = faceUIImageOri
			 
		}
		
		
	}
	
	// Convert CIImage to CGImage
	func convert(cmage:CIImage) -> UIImage
	{
		 let context:CIContext = CIContext.init(options: nil)
		 let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
		 let image:UIImage = UIImage.init(cgImage: cgImage)
		 return image
	}
	
}
