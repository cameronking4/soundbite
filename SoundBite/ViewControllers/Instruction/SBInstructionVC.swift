//
//  SBInstructionVC.swift
//  SoundBite
//
//  Created by Star on 7/12/21.
//  Copyright © 2021 SoundBite. All rights reserved.
//

import UIKit

class SBInstructionVC: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func onCancel(_ sender: Any) {
        dismiss(animated: true)
    }
    
    @IBAction func onOpenLink(_ sender: UIButton) {
        if let strLink = sender.title(for: .normal), let url = URL(string: strLink) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}
