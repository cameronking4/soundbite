//
//  SBVideoPlayerView.swift
//  MessagesExtension
//
//  Created by Star on 7/14/21.
//  Copyright © 2021 SoundBite. All rights reserved.
//

import UIKit
import AVFoundation

class SBVideoPlayerView: UIView {

    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    var player: AVPlayer? {
        get {
            return playerLayer.player
        }

        set {
            playerLayer.player = newValue
        }
    }

    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        playerLayer.videoGravity = .resizeAspect
    }
}
