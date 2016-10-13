//
//  ViewController.swift
//  CTPanoramaController
//
//  Created by Cihan Tek on 12/10/2016.
//  Copyright © 2016 Home. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let image = UIImage(named: "normal.jpg")
        
        let p = CTPanoramaController(image: image!)
        
        self.addChildViewController(p)
        view.addSubview(p.view)
        p.view.frame = view.bounds
    }
}
