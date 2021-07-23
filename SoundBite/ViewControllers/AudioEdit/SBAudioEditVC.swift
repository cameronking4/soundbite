//
//  SBAudioEditVC.swift
//  SoundBite
//
//  Created by Star on 7/6/21.
//  Copyright © 2021 SoundBite. All rights reserved.
//

import UIKit

import AVFoundation
import CoreAudio
import EZAudio


let minimumAudioDuration: CGFloat = 1
let maximumAudioDuration: CGFloat = 1

class SBAudioEditVC: UIViewController {

    @IBOutlet weak var btnSave: UIButton!
    
    @IBOutlet weak var txfTitle: UITextField!
    
    // Recording View
    @IBOutlet weak var viewRecording: UIView!
    @IBOutlet weak var lblRecordingTime: UILabel!
    
    @IBOutlet weak var viewStartRecord: UIView!
    
    // Edit View
    @IBOutlet weak var viewAudioEdit: UIView!
    @IBOutlet weak var viewAudioPlotContainer: UIView!
    
    @IBOutlet weak var audioPlot: EZAudioPlot!
    @IBOutlet weak var igvAudioIndicatorLine: UIImageView!
    @IBOutlet weak var igvLeftThumb: UIImageView!
    @IBOutlet weak var igvRightThumb: UIImageView!
    
    @IBOutlet weak var lblAudioStartTime: UILabel!
    @IBOutlet weak var lblAudioEndTime: UILabel!
    @IBOutlet weak var lblAudioDuration: UILabel!
    
    
    // Controls
    @IBOutlet weak var btnPlayPause: UIButton!
    @IBOutlet weak var btnResetAudio: UIButton!
    @IBOutlet weak var btnTrimmer: UIButton!
    @IBOutlet weak var btnRefresh: UIButton!
   
    // Publice Variables
    var originalAudioURL: URL?
    
    // Private Variables
    private var audioURL: URL?
    
    private var audioFile: EZAudioFile?
    private var audioPlayer: AVAudioPlayer?
    private var audioRecorder: AVAudioRecorder?
    
    private var timerRecording: Timer?
    private var timerAudioPlayer: Timer?
    
    private var videoTrimTimeChanged: Bool = false
    private var audioDuration: CGFloat = 0
    private var audioTrimStartTime: CGFloat = 0
    private var audioTrimEndTime: CGFloat = 0
    
    private var isPlaying: Bool = false
    private var isAudioTrimmed: Bool = false
    
    private var trimmedAudioURL: URL?
    private var exportSession: AVAssetExportSession?

    private var viewMode: Int = 0 // 0- Start Record, 1-Recording, 2 - Edit
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initView()
    }
    
    deinit {
        stopRecording()
        stopAudioPlayer()
    }
    
//    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
//        return .portrait
//    }
//
//    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
//        return .portrait
//    }
    
    private func initView() {
        igvAudioIndicatorLine.isHidden = true
        
        //originalAudioURL = SBAudioManager.shared.audioRecordingFileURL()
        
        txfTitle.delegate = self
        txfTitle.returnKeyType = .done
        
        
        showAudioEditView()
        
        //prepareToRecordAudio()
        
        let panGestureLeft = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)) )
        panGestureLeft.delegate = self
        igvLeftThumb.addGestureRecognizer(panGestureLeft)
        
        let panGestureRight = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)) )
        panGestureRight.delegate = self
        igvRightThumb.addGestureRecognizer(panGestureRight)
    }
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let senderView = gesture.view else {
            return
        }
        
        stopAudioPlayer()
        if gesture.state == .changed {
            
            senderView.superview?.bringSubviewToFront(senderView)
            
            let translation = gesture.translation(in: senderView)
            var viewPosition = senderView.center
            viewPosition.x += translation.x

            calculateAudioTrimTime()
            
            if audioTrimEndTime - audioTrimStartTime > minimumAudioDuration || ((senderView == igvLeftThumb) && translation.x <= 0) || ((senderView == igvRightThumb) && translation.x >= 0) {
                senderView.center = viewPosition

                var frame = senderView.frame
                
                if(senderView.frame.origin.x <= (-senderView.frame.size.width/2)) {
                                frame.origin.x = -senderView.frame.size.width/2;
                    senderView.frame = frame;
                    
                }else if(senderView.center.x >= viewAudioPlotContainer.frame.size.width){
                    frame.origin.x = viewAudioPlotContainer.frame.size.width - (senderView.frame.size.width/2);
                    senderView.frame = frame;
                }
            }else{
                calculateAudioTrimTime()
            }
            
            gesture.setTranslation(.zero, in: igvLeftThumb)
        }else{
            calculateAudioTrimTime()
        }
    }
    
    private func updateViewMode(_ mode : Int) {
        viewMode = mode
        
        viewStartRecord.isHidden = true
        viewRecording.isHidden = true
        viewAudioEdit.isHidden = true
        
        btnSave.isHidden = true
        
        switch viewMode {
        case 0:
            viewStartRecord.isHidden = false
        case 1:
            viewRecording.isHidden = false
        case 2:
            showAudioEditView()
            
        default:
            print("default")
        }
    }
    
    private func showAudioEditView() {
        
        guard  let orgAudioURL = originalAudioURL else {
            return
        }
        
        let asset = AVAsset(url: orgAudioURL)
        audioDuration = CGFloat(CMTimeGetSeconds(asset.duration))
        calculateAudioTrimTime()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback)
            try audioSession.setActive(false)
        } catch {
        }
        
        audioURL = SBAudioManager.shared.audioTempFileURL()
        if let url = audioURL {
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            
            try? FileManager.default.copyItem(at: orgAudioURL, to: url)
        }
        resetAudioPlayer()
        
        btnTrimmer.isSelected = false
        viewStartRecord.isHidden = true
        viewRecording.isHidden = true
        viewAudioEdit.isHidden = false
        btnSave.isHidden = false
        
        hideUnhideControls(true)
    }
    
    private func setupAudioPlot() {
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
    
    private func prepareToRecordAudio() {
        guard let outputFileURL = originalAudioURL else {
            return
        }
        
        if FileManager.default.fileExists(atPath: outputFileURL.path) {
            try? FileManager.default.removeItem(at: outputFileURL)
        }
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            let recordSetting: [String: Any] = [
                AVFormatIDKey : kAudioFormatLinearPCM,
                AVSampleRateKey: 11025.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16
            ]
            
            audioRecorder = try AVAudioRecorder(url: outputFileURL, settings: recordSetting)
            
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
        }catch {
            return
        }
    }
    
    private func startRecording() {
        
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
        audioRecorder?.record()
        
        startRecorderTimer()
        
        updateViewMode(1)
    }
    
    private func stopRecording() {
        
        audioRecorder?.stop()
        stopRecorderTimer()
    }
    
    private func startRecorderTimer() {
        let startDate = Date()
        
        timerRecording = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer) in
            self.audioDuration = CGFloat(Date().timeIntervalSince(startDate))
            self.lblRecordingTime.text = self.timeFormatted(self.audioDuration, isWithMinutes: true)
        })
    }
    
    private func stopRecorderTimer() {
        timerRecording?.invalidate()
        timerRecording = nil
    }
    
    private func timeFormatted(_ interval: CGFloat, isWithMinutes: Bool) -> String {
        var milliseconds = Int(interval * 1000)
        var seconds = milliseconds / 1000
        let minutes = seconds / 60
        milliseconds %= 1000
        seconds %= 60
        
        var strMillisec = String(milliseconds)
        if strMillisec.count > 2 {
            strMillisec = String(strMillisec.prefix(2))
        }
        
        let newMilliSec = Int(strMillisec) ?? 0
        
        if isWithMinutes {
            return String(format: "%02d:%02d.%02d", minutes, seconds, newMilliSec)
        }else{
            return String(format: "%02d.%02d", seconds, newMilliSec)
        }
    }
    
    
    //MARK: Audio Player
    
    private func resetAudioPlayer() {
        stopAudioPlayer()
        
        audioPlayer = nil
        setupAudioPlot()
        prepareToPlayAudio()
        
        igvLeftThumb.center = CGPoint(x: 0, y: igvLeftThumb.center.y)
        igvRightThumb.center = CGPoint(x: viewAudioPlotContainer.bounds.width, y: igvRightThumb.center.y)
     
        calculateAudioTrimTime()
    }
    
    private func prepareToPlayAudio() {
        guard let url = audioURL else {
            return
        }
        
        if audioPlayer == nil {
            audioPlayer = try? AVAudioPlayer.init(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioDuration = CGFloat(audioPlayer?.duration ?? 0)
            lblAudioDuration.text = timeFormatted(audioDuration, isWithMinutes: true)
        }
    }
    
    private func playAudioPlayer() {
        if audioPlayer == nil {
            prepareToPlayAudio()
        }
        
        if audioPlayer != nil {
            isPlaying = true
            audioPlayer?.play()
            btnPlayPause.isSelected = true
            startAudioTimerToDisplay()
        }
    }
    
    private func pauseAudioPlayer() {
        if isPlaying {
            isPlaying = false
            audioPlayer?.pause()
            btnPlayPause.isSelected = false
            igvAudioIndicatorLine.isHidden = true
            stopAudioTimerToDisplay()
        }
    }
    
    private func stopAudioPlayer(){
        if isPlaying {
            isPlaying = false
            audioPlayer?.stop()
            btnPlayPause.isSelected = false
            igvAudioIndicatorLine.isHidden = true
            stopAudioTimerToDisplay()
        }
    }
    
    private func stopAudioTimerToDisplay(){
        timerAudioPlayer?.invalidate()
        timerAudioPlayer = nil
    }
    
    private func startAudioTimerToDisplay() {
        stopAudioTimerToDisplay()
        
        if audioDuration != 0, audioPlayer != nil {
            timerAudioPlayer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer) in
                let currentTime = CGFloat(self.audioPlayer?.currentTime ?? 0)
                let lineX = self.viewAudioPlotContainer.bounds.width * currentTime / self.audioDuration
                self.igvAudioIndicatorLine.center = CGPoint(x: lineX, y: self.igvAudioIndicatorLine.center.y)
                self.igvAudioIndicatorLine.isHidden = false
                
                if currentTime >= self.audioTrimEndTime {
                    self.stopAudioPlayer()
                }
            })
        }
    }
    
    private func calculateAudioTrimTime() {
        audioTrimStartTime = igvLeftThumb.center.x * audioDuration / viewAudioPlotContainer.frame.size.width
        audioTrimEndTime = igvRightThumb.center.x * audioDuration / viewAudioPlotContainer.frame.size.width
        lblAudioStartTime.text = timeFormatted(audioTrimStartTime, isWithMinutes: true)
        lblAudioEndTime.text = timeFormatted(audioTrimEndTime, isWithMinutes: true)
        
        lblAudioStartTime.center = CGPoint(x: igvLeftThumb.center.x, y: lblAudioStartTime.center.y)
        lblAudioEndTime.center = CGPoint(x: igvRightThumb.center.x, y: lblAudioEndTime.center.y)

        var startFrame = lblAudioStartTime.frame
        if startFrame.origin.x < 0 {
            startFrame.origin.x = 0
            lblAudioStartTime.frame = startFrame
        } else if startFrame.origin.x > viewAudioPlotContainer.bounds.width - startFrame.width {
            startFrame.origin.x = viewAudioPlotContainer.bounds.width - startFrame.width
            lblAudioStartTime.frame = startFrame
        }

        var endFrame = lblAudioEndTime.frame
        if endFrame.origin.x < 0 {
            endFrame.origin.x = 0
            lblAudioEndTime.frame = endFrame
        } else if endFrame.origin.x > viewAudioPlotContainer.bounds.width - endFrame.width {
            endFrame.origin.x = viewAudioPlotContainer.bounds.width - endFrame.width
            lblAudioEndTime.frame = endFrame
        }
    }
    
    func hideUnhideControls(_ isHidden: Bool) {
        btnTrimmer.isSelected = isHidden
        igvLeftThumb.isHidden = isHidden
        igvRightThumb.isHidden = isHidden

        lblAudioStartTime.isHidden = isHidden
        lblAudioEndTime.isHidden = isHidden
    }
    
    func trimAudio(withCompletion completion: @escaping (Bool) -> Void) {

        if trimmedAudioURL == nil {
            trimmedAudioURL = SBAudioManager.shared.audioTrimmedFileURL()
        }
        
        guard let trimmedAudioURL = trimmedAudioURL, let audioURL = audioURL else {
            completion(false)
            return
        }
        
        if FileManager.default.fileExists(atPath: trimmedAudioURL.path) {
            try? FileManager.default.removeItem(at: trimmedAudioURL)
        }
        
        let asset = AVAsset(url: audioURL)
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        if compatiblePresets.contains(AVAssetExportPresetHighestQuality) {
            exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
            exportSession?.outputURL = trimmedAudioURL
            exportSession?.outputFileType = .m4a

            let start = CMTimeMakeWithSeconds(Float64(audioTrimStartTime), preferredTimescale: asset.duration.timescale)
            let duration = CMTimeMakeWithSeconds(Float64(audioTrimEndTime - audioTrimStartTime), preferredTimescale: asset.duration.timescale)

            let range = CMTimeRangeMake(start: start, duration: duration)
            exportSession?.timeRange = range
            
            exportSession?.exportAsynchronously {
                var result = false
                if let status = self.exportSession?.status {
                    switch status {
                    case .failed:
                        print("Failed!")
                    case .cancelled:
                        print("Cancelled!")
                    case .completed:
                        
                        if FileManager.default.fileExists(atPath: audioURL.path) {
                            try? FileManager.default.removeItem(at: audioURL)
                        }
                        
                        try? FileManager.default.copyItem(at: trimmedAudioURL, to: audioURL)
                        result = true
                    default:
                        print("Default")
                    }
                }
                
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }else{
            completion(false)
        }
    }
    
    func trimFinalAudio() {
        stopAudioPlayer()
        trimAudio(withCompletion: { success in
            self.isAudioTrimmed = true
            self.resetAudioPlayer()
            self.hideUnhideControls(true)
        })
    }
    
    private func closeView(){
        dismiss(animated: true)
    }
    
    // MARK: UI Actions
    @IBAction func onCancel(_ sender: Any) {
        trimmedAudioURL = nil
        pauseAudioPlayer()
        closeView()
    }
    
    @IBAction func onSave(_ sender: Any) {
        if let title = txfTitle.text, title.isEmpty == false {
            
            stopAudioPlayer()
            if isAudioTrimmed, let url = trimmedAudioURL {
                if SBAudioManager.shared.saveAudioFile(url, title: title) {
                    closeView()
                }else{
                    showAlert(title: "Sorry!", message: "Cannot save the audio file now")
                }
            }else if let url = originalAudioURL {
                if SBAudioManager.shared.saveAudioFile(url, title: title) {
                    closeView()
                }else{
                    showAlert(title: "Sorry!", message: "Cannot save the audio file now")
                }
            }
        }else {
            showAlert(title: "Please enter title", message: nil)
        }
    }
    
    @IBAction func onStartRecording(_ sender: Any) {
        startRecording()
    }
    @IBAction func onStopRecording(_ sender: Any) {
        stopRecording()
    }
    
    @IBAction func onAudioPlayPause(_ sender: Any) {
        if isPlaying {
            pauseAudioPlayer()
        }else{
            playAudioPlayer()
            audioPlayer?.currentTime = TimeInterval(audioTrimStartTime)
        }
    }
    
    @IBAction func onAudioResetAudio(_ sender: Any) {
        resetAudioPlayer()
        hideUnhideControls(false)
        startRecording()
    }
    
    @IBAction func onAudioTrim(_ sender: Any) {
        if btnTrimmer.isSelected {
            isAudioTrimmed = false
            resetAudioPlayer()
            hideUnhideControls(false)
        }else{
            trimFinalAudio()
        }
    }
    
    @IBAction func onAudioRefresh(_ sender: Any) {
        
        isAudioTrimmed = false
        
        if let url = audioURL, let orgUrl = originalAudioURL {
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(atPath: url.path)
            }
            
            try? FileManager.default.copyItem(at: orgUrl, to: url)
            
            resetAudioPlayer()
        }
    }
}

extension SBAudioEditVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        return true
    }
}

extension SBAudioEditVC: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = panGesture.velocity(in: panGesture.view)
            return abs(velocity.x) > abs(velocity.y)
        }
            
        return false
    }
}

extension SBAudioEditVC : AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        audioRecorder?.stop()
        
        showAudioEditView()
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        
    }
}

extension SBAudioEditVC: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopAudioPlayer()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        stopAudioPlayer()
    }
    
    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        pauseAudioPlayer()
    }
    
    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        playAudioPlayer()
    }
}
