//
//  SBMessagesMainVC.swift
//  MessagesExtension
//
//  Created by Star on 7/5/21.
//  Copyright © 2021 SoundBite. All rights reserved.
//

import UIKit
import Messages

import MobileCoreServices
import AVFoundation
import EZAudio


class SBMessagesMainVC: MessagesViewController {

    @IBOutlet weak var tblAudios: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    // Audio Player View
    @IBOutlet weak var viewAudioPlay: UIView!
    @IBOutlet weak var lblAudioTitle: UILabel!
    @IBOutlet weak var audioPlot: EZAudioPlot!
    @IBOutlet weak var btnPlayPause: UIButton!
    
    private var audioInfoList: [SBAudioInfo] = []
    private var filteredAudioInfoList: [SBAudioInfo] = []
    private var selectedAudioInfo: SBAudioInfo?
    
    private var audioPlayer: AVAudioPlayer?
    private var audioFile: EZAudioFile?
    
    private var isSearchMode = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initView()
    }

    private func initView(){
        
        audioInfoList = SBAudioManager.shared.loadAudioInfoList()
        
        tblAudios.delegate = self
        tblAudios.dataSource = self
        tblAudios.tableFooterView = UIView(frame: .zero)
        
        searchBar.delegate = self
        searchBar.showsCancelButton = false
        searchBar.backgroundImage = UIImage()
        searchBar.searchTextField.backgroundColor = .white
        searchBar.searchTextField.textColor = .black
        searchBar.searchTextField.placeholder = "Search"
        
        viewAudioPlay.isHidden = true
    }
    
    private func searchAudioByTitle(_ searchWord: String?) {
        if let searchTitle = searchWord, searchTitle.isEmpty == false {
            isSearchMode = true
            filteredAudioInfoList = audioInfoList.filter({ (audioInfo) -> Bool in
                if audioInfo.title.lowercased().contains(searchTitle.lowercased()) {
                    return true
                }
                return false
            })
        }else{
            
            isSearchMode = false
            filteredAudioInfoList = []
        }
        
        tblAudios.reloadData()
    }
    
    func sendVideoMessage(_ url: URL) {
        activeConversation?.insertAttachment(url, withAlternateFilename: nil, completionHandler: nil)
        requestPresentationStyle(.compact)
    }
    
    
    // Audio Player
    private func prepareToPlayAudio() {
        guard let audioInfo = selectedAudioInfo, let url = SBAudioManager.shared.getAudioURL(fileName: audioInfo.file) else {
            return
        }
        
        if audioPlayer == nil {
            audioPlayer = try? AVAudioPlayer.init(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
        }
    }
    
    private func playAudioPlayer() {
        if audioPlayer == nil {
            prepareToPlayAudio()
        }
        
        audioPlayer?.play()
    }
    
    private func pauseAudioPlayer() {
        audioPlayer?.pause()
    }
    
    private func stopAudioPlayer(){
        audioPlayer?.stop()
    }
    
    private func selectAudio(_ audioInfo: SBAudioInfo) {
        stopAudioPlayer()
        audioPlayer = nil
        
        selectedAudioInfo = audioInfo

        lblAudioTitle.text = audioInfo.title
        
        let audioURL = SBAudioManager.shared.getAudioURL(fileName: audioInfo.file)
        setupAudioPlot(audioURL)
        
        btnPlayPause.isSelected = false
        viewAudioPlay.isHidden = false
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
    
    private func closeAudioPlayerView(){
        stopAudioPlayer()
        viewAudioPlay.isHidden = true
    }
    
    // MARK: UIActions
    @IBAction func onPlayPause(_ sender: Any) {
        if btnPlayPause.isSelected {
            pauseAudioPlayer()
            btnPlayPause.isSelected = false
        }else{
            playAudioPlayer()
            btnPlayPause.isSelected = true
        }
    }
    
    @IBAction func onDone(_ sender: Any) {
        
        if let audioInfo = selectedAudioInfo, let vc = self.storyboard?.instantiateViewController(identifier: "SBVideoRecordingVC") as? SBVideoRecordingVC {
            vc.audioInfo = audioInfo
            vc.messagesMainVC = self
            
            if presentationStyle != .expanded {
                requestPresentationStyle(.expanded)
            }
            
            present(vc, animated: false, completion: nil)
            
            closeAudioPlayerView()
        }
    }
    
    @IBAction func onCancel(_ sender: Any) {
        closeAudioPlayerView()
    }
    
}

extension SBMessagesMainVC: AVAudioPlayerDelegate {
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

extension SBMessagesMainVC: UITableViewDelegate, UITableViewDataSource, SBAudioCellDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearchMode ? filteredAudioInfoList.count : audioInfoList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AudioCell") as! SBAudioCell
        let list = isSearchMode ? filteredAudioInfoList : audioInfoList
        let audioInfo = list[indexPath.row]
        
        var isSelected = false
        if let selectedItem = selectedAudioInfo, selectedItem.file == audioInfo.file {
            isSelected = true
        }
        
        cell.delegate = self
        cell.initCell(audioInfo: audioInfo, isSelected: isSelected)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let list = isSearchMode ? filteredAudioInfoList : audioInfoList
        let audioInfo = list[indexPath.row]
        
        selectAudio(audioInfo)
    }
    
    // SBAudioCell Delegate
    
    func audioCellPlayAudio(_ audioInfo: SBAudioInfo?) {
        stopAudioPlayer()
        audioPlayer = nil
        
        selectedAudioInfo = audioInfo
        playAudioPlayer()
    }
    
    func audioCellPauseAudio(_ audioInfo: SBAudioInfo?) {
        pauseAudioPlayer()
        selectedAudioInfo = nil
    }
}

extension SBMessagesMainVC: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchAudioByTitle(searchBar.text)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.view.endEditing(true)
        searchAudioByTitle(nil)
        searchBar.text = ""
        searchBar.showsCancelButton = false
    }
    
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        requestPresentationStyle(.expanded)
        searchBar.showsCancelButton = true
        return true
    }
}
