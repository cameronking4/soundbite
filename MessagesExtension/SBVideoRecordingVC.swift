//
//  SBVideoRecordingVC.swift
//  MessagesExtension
//
//  Created by Star on 7/8/21.
//  Copyright © 2021 SoundBite. All rights reserved.
//

import UIKit

import AVFoundation
import AACameraView
import KYShutterButton

class SBVideoRecordingVC: UIViewController {

    var audioInfo: SBAudioInfo?
    weak var messagesMainVC: SBMessagesMainVC?
    
    // CameraView
    @IBOutlet weak var cameraView: AACameraView!
    
    @IBOutlet weak var btnCameraSwitch: UIButton!
    @IBOutlet weak var btnFlash: UIButton!
    @IBOutlet weak var btnShutter: KYShutterButton!
    
    @IBOutlet weak var btnSend: UIButton!
    @IBOutlet weak var viewVideoContainer: UIView!
    @IBOutlet weak var viewVideo: SBVideoPlayerView!
    @IBOutlet weak var btnVideoPlayPause: UIButton!

    private var originalAudioURL: URL?
    private var finalVideoURL: URL?
    
    private var audioPlayer: AVAudioPlayer?
    private var audioDuration: Float = 0
    
    private var timerRecording: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initView()
    }

    deinit {
        cameraView.stopSession()
        
        NotificationCenter.default.removeObserver(self)
    }
    
    private func initView(){
        viewVideoContainer.isHidden = true
        setupVideoPlayerView()
        
        if let info = audioInfo {
            originalAudioURL = SBAudioManager.shared.getAudioURL(fileName: info.file)
        }
        
        cameraView.cameraPosition = .front
        cameraView.startSession()
        
        cameraView.outputMode = .video
        cameraView.flashMode = .off
        
        btnFlash.setImage(UIImage(named: "flash_off"), for: .normal)

        prepareToPlayAudio()

        btnShutter.shutterType = .normal
        btnShutter.rotateAnimateDuration = audioDuration
        btnShutter.buttonState = .normal

        cameraView.response = { response in
            if let url = response as? URL { // Recorded Video URL
                self.showVideoView(url)
            }
        }
        
        cameraView.didStartRecordingResponse = { fileURL in
            self.playAudioPlayer()
            self.startRecorderTimer()
            
        }
    }
    
    @objc func didEndVideoPlay(_ notification: Notification) {
        viewVideo.player?.seek(to: .zero)
        btnVideoPlayPause.isSelected = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        cameraView.startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cameraView.stopSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    private func mergeVideoAndAudio(_ videoURL: URL) -> Bool {
        guard let audioURL = originalAudioURL else {
            return false
        }
        
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)
        
        guard let videoAssetTrack = videoAsset.tracks(withMediaType: .video).first else {
            return false
        }
        
        guard let audioAssetTrack = audioAsset.tracks(withMediaType: .audio).first else {
            return false
        }
            
        let mixComposition = AVMutableComposition()
        let timeRange = CMTimeRangeMake(start: .zero, duration: videoAsset.duration)
       
        guard let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return false }
        
        do {
            try videoTrack.insertTimeRange( timeRange, of: videoAssetTrack, at: .zero)
        } catch {
          return false
        }
        
        guard let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return false }
        
        do {
            
            let audioStartTime = CMTime(seconds: 0.45, preferredTimescale: audioAsset.duration.timescale)
            let audioTimeRange = CMTimeRange(start: .zero, duration: videoAsset.duration - audioStartTime)
            
            try audioTrack.insertTimeRange(audioTimeRange, of: audioAssetTrack, at: audioStartTime)
        } catch {
          return false
        }
        
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = timeRange

        let videoTransform = videoAssetTrack.preferredTransform
        
        let videoInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        videoInstruction.setOpacity(0.0, at: videoAsset.duration)
        videoInstruction.setTransform(videoTransform, at: .zero)
        
        mainInstruction.layerInstructions = [videoInstruction]
        
        var isVideoAssetPortrait_ = false
        
        if videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0 { // Right
            isVideoAssetPortrait_ = true
        }
        if videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0 { // Left
            isVideoAssetPortrait_ = true
        }
        
        var naturalSize: CGSize = videoAssetTrack.naturalSize
        if isVideoAssetPortrait_ {
            naturalSize = CGSize(width: naturalSize.height, height: naturalSize.width)
        }
        
        let videoSize = naturalSize
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30) // videoAssetTrack.minFrameDuration
        mainComposition.renderSize = videoSize
        
        guard let url = SBAudioManager.shared.videoExportFileURL() else{
            return false
        }
        
        // Remove old file
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
        }
        
        guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
            return false
        }
        exporter.outputURL = url
        exporter.outputFileType = .mp4 //AVFileTypeQuickTimeMovie
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = mainComposition

        exporter.exportAsynchronously(completionHandler: {
            DispatchQueue.main.async(execute: {
                self.exportDidFinish(exporter)
            })
        })
        
        return true
    }
    
    func exportDidFinish(_ session: AVAssetExportSession) {
        guard
            session.status == AVAssetExportSession.Status.completed,
            let outputURL = session.outputURL
            else { return }
        
        updateVideoView(outputURL)
    }
    
    private func showVideoView(_ videoURL: URL) {
        btnSend.isEnabled = false
        
        self.mergeVideoAndAudio(videoURL)
        
        viewVideoContainer.isHidden = false
        cameraView.stopSession()
    }
    
    private func updateVideoView(_ videoURL: URL) {
        
        finalVideoURL = videoURL
        
        let playerItem = AVPlayerItem(url: videoURL)
        viewVideo.player?.replaceCurrentItem(with: playerItem)
        
        btnSend.isEnabled = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(didEndVideoPlay(_ :)), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
    }
    
    private func setupVideoPlayerView() {
        let videoPlayer = AVPlayer()
        videoPlayer.actionAtItemEnd = .pause
        viewVideo.player = videoPlayer
    }
    
    private func playVideo(){
        viewVideo.player?.play()
        btnVideoPlayPause.isSelected = true
    }
    
    private func pauseVideo(){
        viewVideo.player?.pause()
        btnVideoPlayPause.isSelected = false
    }
    
    
    private func retakeVideo() {
        finalVideoURL = nil
        
        pauseVideo()
        cameraView.startSession()
        viewVideoContainer.isHidden = true
    }
    
    // MARK: Audio Play
    
    private func prepareToPlayAudio() {
        guard let url = originalAudioURL else {
            return
        }
        
        if audioPlayer == nil {
            audioPlayer = try? AVAudioPlayer.init(contentsOf: url)
            audioPlayer?.delegate = self
            audioDuration = Float(audioPlayer?.duration ?? 0)
        }
        
        audioPlayer?.currentTime = .zero
        audioPlayer?.prepareToPlay()
    }
    
    private func playAudioPlayer() {
        audioPlayer?.play()
    }
    
    private func stopAudioPlayer(){
        audioPlayer?.stop()
    }
    
    
    // MARK: CameraView Interaction
    
    private func startVideoRecording() {
        if audioDuration <= 0 {
            return
        }
        
        btnShutter.buttonState = .recording
        
        prepareToPlayAudio()
        cameraView.startVideoRecording()
    }
    
    private func stopVideoRecording() {
        btnShutter.buttonState = .normal
        
        cameraView.stopVideoRecording()
        stopRecorderTimer()
        
        stopAudioPlayer()
    }
    
    private func startRecorderTimer() {
        let startDate = Date()
        
        timerRecording = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer) in
            let recordingDuration = Float(Date().timeIntervalSince(startDate))
            if recordingDuration >= self.audioDuration {
                self.stopVideoRecording()
            }
        })
    }
    
    private func stopRecorderTimer() {
        timerRecording?.invalidate()
        timerRecording = nil
    }
    
    private func closeView() {
        dismiss(animated: false)
    }
    // UI Actions
    
    @IBAction func onCancel(_ sender: Any) {
        closeView()
    }
    
    @IBAction func onRecord(_ sender: Any) {
        
        switch btnShutter.buttonState {
        case .normal:
            startVideoRecording()
        case .recording:
            stopVideoRecording()
        }
    }
    
    @IBAction func onFlash(_ sender: Any) {
        let flashMode = cameraView.flashMode
        
        switch flashMode {
        case .auto:
            cameraView.flashMode = .off
            btnFlash.setImage(UIImage(named: "flash_off"), for: .normal)
        case .off:
            cameraView.flashMode = .on
            btnFlash.setImage(UIImage(named: "flash_on"), for: .normal)
        case .on:
            cameraView.flashMode = .auto
            btnFlash.setImage(UIImage(named: "flash_auto"), for: .normal)
        default:
            break
        }
    }
    
    @IBAction func onChangeCamera(_ sender: Any) {
        cameraView.toggleCamera()
    }
    
    // Video View
    @IBAction func onSend(_ sender: Any) {
        if let url = finalVideoURL {
            pauseVideo()
            messagesMainVC?.sendVideoMessage(url)
            closeView()
        }
    }
    
    @IBAction func onRetakeVideo(_ sender: Any) {
        retakeVideo()
    }
    
    @IBAction func onPlayVideo(_ sender: Any) {
        if btnVideoPlayPause.isSelected {
            pauseVideo()
        }else{
            playVideo()
        }
    }
    
    @IBAction func onCloseVideoView(_ sender: Any) {
        closeView()
    }
    
}


extension SBVideoRecordingVC: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopAudioPlayer()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        stopAudioPlayer()
    }
    
    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        //pauseAudioPlayer()
    }
    
    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        //playAudioPlayer()
    }
}
