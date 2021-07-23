//
//  SBAudioInfo.swift
//  SoundBite
//
//  Created by Star on 7/6/21.
//  Copyright © 2021 SoundBite. All rights reserved.
//

import UIKit

class SBAudioInfo {

    let title: String
    let file: String
    
    init(title: String, file: String) {
        self.title = title
        self.file = file
    }
    
    init(dic: [String: Any]) {
        self.title = dic["title"] as? String ?? ""
        self.file = dic["file"] as? String ?? ""
    }
}
