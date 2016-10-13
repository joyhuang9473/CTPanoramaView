//
//  CTPanoramaController
//  CTPanoramaController
//
//  Created by Cihan Tek on 11/10/16.
//  Copyright © 2016 Home. All rights reserved.
//

import UIKit
import SceneKit
import CoreMotion
import ImageIO

@objc public enum CTPanaromaControlMethod: Int {
    case Motion
    case Touch
}

@objc public enum CTPanaromaType: Int {
    case Cylindrical
    case Spherical
}

@objc public class CTPanoramaController: UIViewController {
    
    public var panaromaType: CTPanaromaType?
    public var panSpeed = CGPoint(x: 0.005, y: 0.005)
    
    public var image: UIImage? {
        didSet {
            geometryNode?.geometry?.firstMaterial?.diffuse.contents = image
            resetCameraAngles()
        }
    }
    
    public var overlayView: UIView? {
        didSet {
            replace(overlayView: oldValue, with: overlayView)
        }
    }
    
    public var controlMethod: CTPanaromaControlMethod? {
        didSet {
            switchControlMethod(to: controlMethod!)
            resetCameraAngles()
        }
    }
    
    private let cameraNode = SCNNode()
    private let sceneView = SCNView()
    private var geometryNode: SCNNode?
    private var prevLocation = CGPoint.zero
    private var motionManger = CMMotionManager()
    private var prevBounds = CGRect.zero
    
    private var panoramaTypeForCurrentImage: CTPanaromaType {
        if let image = image {
            if (image.size.width / image.size.height == 2) {
                return .Spherical
            }
        }
        return .Cylindrical
    }
    
    // MARK: Class lifecycle methods
    
    public init(image: UIImage) {
        super.init(nibName: nil, bundle: nil)
        self.image = image
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("Cannot be initialized from a storyboard or nib")
    }
    
    deinit {
        if (motionManger.isDeviceMotionActive) {
            motionManger.stopDeviceMotionUpdates()
        }
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()

        if panaromaType == nil {
            panaromaType = panoramaTypeForCurrentImage
        }
        
        prepareUI()
        createScene()
        
        if controlMethod == nil {
            controlMethod = .Touch
        }
     }
    
    // MARK: Configuration helper methods
    
    private func createScene() {
        guard let image = image else {return}
        
        let camera = SCNCamera()
        camera.zFar = 100
        camera.xFov = 70
        camera.yFov = 70
        cameraNode.camera = camera
        
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.diffuse.mipFilter = .nearest
        material.diffuse.magnificationFilter = .nearest
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(-1, 1, 1)
        material.diffuse.wrapS = .repeat
        material.cullMode = .front

        if (panaromaType == .Spherical) {
            let sphere = SCNSphere(radius: 50)
            sphere.segmentCount = 300
            sphere.firstMaterial = material

            let sphereNode = SCNNode()
            sphereNode.geometry = sphere
            sphereNode.position = SCNVector3Make(0, 0, 0)
            geometryNode = sphereNode
        }
        else {
            let tube = SCNTube(innerRadius: 40, outerRadius: 40, height: 100)
            tube.heightSegmentCount = 50
            tube.radialSegmentCount = 300
            tube.firstMaterial = material
            
            let tubeNode = SCNNode()
            tubeNode.geometry = tube
            tubeNode.position = SCNVector3Make(0, 0, 0)
            geometryNode = tubeNode
            
            panSpeed.y = 0 // Prevent vertical movement in a cylindrical panorama
        }
        
        guard let geometryNode = geometryNode else {return}
        cameraNode.position = geometryNode.position
        
        let scene = SCNScene()
        
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(geometryNode)
        
        sceneView.scene = scene
        sceneView.backgroundColor = UIColor.black
    }
    
    private func prepareUI() {
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sceneView)
        
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Touch/Motion", for: .normal)
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        
        view.addSubview(button)
        
        let views = ["sceneView" : sceneView, "button": button]
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "|[sceneView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[sceneView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views))
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "[button]-10-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-10-[button]", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: views))
    }
    
    private func replace(overlayView: UIView?, with newOverlayView: UIView?) {
        overlayView?.removeFromSuperview()
        guard let newOverlayView = newOverlayView else {return}
        view.addSubview(newOverlayView)
    }
    
    private func switchControlMethod(to method: CTPanaromaControlMethod) {
        sceneView.gestureRecognizers?.removeAll()
        
        if (method == .Touch) {
                let panGestureRec = UIPanGestureRecognizer(target: self, action: #selector(handlePan(panRec:)))
                sceneView.addGestureRecognizer(panGestureRec)
 
            if (motionManger.isDeviceMotionActive) {
                motionManger.stopDeviceMotionUpdates()
            }
        }
        else {
            guard motionManger.isDeviceMotionAvailable else {return}
            motionManger.deviceMotionUpdateInterval = 0.015
            motionManger.startDeviceMotionUpdates(to: OperationQueue.main, withHandler: {[unowned self] (motionData, error) in
                if let motionData = motionData {
                    self.cameraNode.orientation = motionData.look(at: UIApplication.shared.statusBarOrientation)
                   /*
                    if (self.panaromaType == .Cylindrical) {
                        self.cameraNode.eulerAngles.x = 0
                        self.cameraNode.eulerAngles.z = 0
                    }*/
                }
                else {
                    print("\(error?.localizedDescription)")
                    self.motionManger.stopDeviceMotionUpdates()
                }
            })
            
        }
    }
    
    private func resetCameraAngles() {
        cameraNode.eulerAngles = SCNVector3Make(0, 0, 0)
    }
    
    private func updateGeometrySize() {
        guard let geometryNode = geometryNode else {return}
        guard panaromaType == .Cylindrical else {return}
            
            let hitResult = sceneView.hitTest(CGPoint(x: view.bounds.size.width/2, y: view.bounds.size.height/2), options: nil)
            guard hitResult.count > 0  else {return}
            
            let hitCoordsInScreenSpace = sceneView.projectPoint(hitResult[0].worldCoordinates)

            let tube = geometryNode.geometry as! SCNTube
   
            let top = SCNVector3Make(0, 0, hitCoordsInScreenSpace.z)
            let bottom = SCNVector3Make(0, Float(view.bounds.size.height), hitCoordsInScreenSpace.z)
            
            let unprojectedTop = sceneView.unprojectPoint(top)
            let unprojectedBottom = sceneView.unprojectPoint(bottom)
            
            tube.height = CGFloat(unprojectedTop.y - unprojectedBottom.y)
    }
    
    // MARK: Event handling methods
    
    @objc private func buttonTapped() {
        if controlMethod == .Touch {
            controlMethod = .Motion
        }
        else {
            controlMethod = .Touch
        }
    }
    
    @objc private func handlePan(panRec: UIPanGestureRecognizer) {
        if (panRec.state == .began) {
            prevLocation = CGPoint.zero
        }
        else if (panRec.state == .changed) {
            let location = panRec.translation(in: sceneView)
            let orientation = cameraNode.eulerAngles
            var newOrientation = SCNVector3Make(orientation.x + Float(location.y - prevLocation.y) * Float(panSpeed.y),
                                                orientation.y + Float(location.x - prevLocation.x) * Float(panSpeed.x),
                                                orientation.z)
            
            if (controlMethod == .Touch) {
                newOrientation.x = max(min(newOrientation.x, 1.01),-1.01)
            }

            cameraNode.eulerAngles = newOrientation
            prevLocation = location
        }
    }
    
    public override func viewDidLayoutSubviews() {
        if (view.bounds.size.width != prevBounds.size.width || view.bounds.size.height != prevBounds.size.height) {
            updateGeometrySize()
            prevBounds = view.bounds
        }
        
    }
}

fileprivate extension CMDeviceMotion {
    
        func look(at orientation: UIInterfaceOrientation) -> SCNVector4 {
        
        let attitude = self.attitude.quaternion
        let aq = GLKQuaternionMake(Float(attitude.x), Float(attitude.y), Float(attitude.z), Float(attitude.w))
        
        var result: SCNVector4
        
        switch UIApplication.shared.statusBarOrientation {
            
        case .landscapeRight:
            let cq = GLKQuaternionMakeWithAngleAndAxis(Float(M_PI_2), 0, 1, 0)
            let q = GLKQuaternionMultiply(cq, aq)
            
            result = SCNVector4(x: -q.y, y: q.x, z: q.z, w: q.w)
            
        case .landscapeLeft:
            let cq = GLKQuaternionMakeWithAngleAndAxis(Float(-M_PI_2), 0, 1, 0)
            let q = GLKQuaternionMultiply(cq, aq)
            
            result = SCNVector4(x: q.y, y: -q.x, z: q.z, w: q.w)
            
        case .portraitUpsideDown:
            let cq = GLKQuaternionMakeWithAngleAndAxis(Float(M_PI_2), 1, 0, 0)
            let q = GLKQuaternionMultiply(cq, aq)
            
            result = SCNVector4(x: -q.x, y: -q.y, z: q.z, w: q.w)
            
        case .unknown:
            fallthrough
        case .portrait:
            let cq = GLKQuaternionMakeWithAngleAndAxis(Float(-M_PI_2), 1, 0, 0)
            let q = GLKQuaternionMultiply(cq, aq)
            
            result = SCNVector4(x: q.x, y: q.y, z: q.z, w: q.w)
        }
        return result
    }
}
