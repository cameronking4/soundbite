//
//  SBAudioCell.swift
//  SoundBite
//
//  Created by Star on 7/2/21.
//  Copyright © 2021 SoundBite. All rights reserved.
//

import UIKit

import CoreAudio
import EZAudio

protocol SBAudioCellDelegate {
    func audioCellPlayAudio(_ audioInfo: SBAudioInfo?)
    func audioCellPauseAudio(_ audioInfo: SBAudioInfo?)
}

class SBAudioCell: UITableViewCell {

    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var btnPlayPause: UIButton?
    @IBOutlet weak var audioPlot: EZAudioPlot!
    
    private var audioFile: EZAudioFile?
    private var mAudioInfo: SBAudioInfo?
    
    var delegate: SBAudioCellDelegate?
    
    override class func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func initCell(audioInfo: SBAudioInfo, isSelected: Bool) {
        mAudioInfo = audioInfo
        
        lblTitle.text = audioInfo.title
        btnPlayPause?.isSelected = isSelected
        
        let audioURL = SBAudioManager.shared.getAudioURL(fileName: audioInfo.file)
        setupAudioPlot(audioURL)
    }
    
    @IBAction func onPlayPause(_ sender: Any) {
        guard let btnPlayPause = btnPlayPause else {
            return
        }
        
        if btnPlayPause.isSelected {
            delegate?.audioCellPauseAudio(mAudioInfo)
            btnPlayPause.isSelected = false
        }else{
            delegate?.audioCellPlayAudio(mAudioInfo)
            btnPlayPause.isSelected = true
        }
    }
    
    private func setupAudioPlot(_ audioURL: URL?) {
        audioPlot.backgroundColor = .sbPlotBackground
        audioPlot.color = .sbPlot
        audioPlot.plotType = .buffer
        audioPlot.shouldFill = true
        audioPlot.shouldMirror = true
        audioPlot.shouldOptimizeForRealtimePlot = false
        audioPlot.waveformLayer.shadowOffset = CGSize(width: 0.0, height: 1.0)
        audioPlot.waveformLayer.shadowRadius = 0.0
        audioPlot.waveformLayer.shadowColor = UIColor.clear.cgColor
        audioPlot.waveformLayer.shadowOpacity = 1.0
        
        if let url = audioURL {
            audioFile = EZAudioFile(url: url)
            audioFile?.getWaveformData(completionBlock: { (waveformData, length) in
                if let firstFormData = waveformData?[0] {
                    self.audioPlot.updateBuffer(firstFormData, withBufferSize: UInt32(length))
                }
            })
        }
    }
}
