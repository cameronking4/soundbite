//
//  HomeVC.swift
//  SoundBite
//
//  Created by Star on 7/1/21.
//

import UIKit
import MobileCoreServices
import AVFoundation

class SBHomeVC: UIViewController {
    
    @IBOutlet weak var tblAudios: UITableView!
    
    @IBOutlet weak var searchBar: UISearchBar!
    
    private var audioInfoList: [SBAudioInfo] = []
    private var filteredAudioInfoList: [SBAudioInfo] = []
    private var selectedAudioInfo: SBAudioInfo?
    
    private var audioPlayer: AVAudioPlayer?
    
    private var isSearchMode = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        initView()
        pauseAudioPlayer()
    }
    
    private func initView(){
        stopAudioPlayer()
        
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(refreshAudioFiles(_:)), name: .refreshAudioFiles, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func refreshAudioFiles(_ notification: Notification) {
        audioInfoList = SBAudioManager.shared.loadAudioInfoList()
        
        tblAudios.reloadData()
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
    
    @IBAction func onCreateAudio(_ sender: Any) {
        openVideoPicker()
    }
    
    private func openVideoPicker() {
        let picker = UIImagePickerController()
        picker.sourceType = .savedPhotosAlbum
        picker.mediaTypes = [kUTTypeMovie as String]
        picker.delegate = self
        
        
        self.present(picker, animated: true, completion: nil)
    }
    
    private func extractAudioFromVideo(_ videoURL: URL) {
        guard let outputUrl = SBAudioManager.shared.audioRecordingFileURL() else { return }
        
        let composition = AVMutableComposition()
        do {
            let asset = AVURLAsset(url: videoURL)
            guard let audioAssetTrack = asset.tracks(withMediaType: AVMediaType.audio).first else { return }
            guard let audioCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return }
            try audioCompositionTrack.insertTimeRange(audioAssetTrack.timeRange, of: audioAssetTrack, at: CMTime.zero)
        } catch {
            print(error)
        }

        // Get url for output
        if FileManager.default.fileExists(atPath: outputUrl.path) {
            try? FileManager.default.removeItem(atPath: outputUrl.path)
        }

        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: composition)
        var presetName = AVAssetExportPresetHighestQuality
        if compatiblePresets.contains(AVAssetExportPresetAppleM4A) {
            presetName = AVAssetExportPresetAppleM4A
        }

        // Create an export session
        let exportSession = AVAssetExportSession(asset: composition, presetName: presetName)!
        exportSession.outputFileType = AVFileType.m4a
        exportSession.outputURL = outputUrl
        
        // Export file
        exportSession.exportAsynchronously {
            guard case exportSession.status = AVAssetExportSession.Status.completed else {
                print(exportSession.error);
                return
            }

            DispatchQueue.main.async {
                // Present a UIActivityViewController to share audio file
                guard let outputURL = exportSession.outputURL else { return }
                self.presentAudioEdit(outputURL)
            }
        }
    }
    
    private func presentAudioEdit(_ audioURL: URL) {
        if let vc = self.storyboard?.instantiateViewController(identifier: "SBAudioEditVC") as? SBAudioEditVC {
            vc.originalAudioURL = audioURL
            
            self.present(vc, animated: true)
        }
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
        audioPlayer = nil
    }
    
    
}

extension SBHomeVC: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopAudioPlayer()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        stopAudioPlayer()
    }
    
    func audioPlayerBeginInterruption(_ player: AVAudioPlayer) {
        stopAudioPlayer()
    }
    
    func audioPlayerEndInterruption(_ player: AVAudioPlayer, withOptions flags: Int) {
        stopAudioPlayer()
    }
}

extension SBHomeVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      
        guard let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String,
                mediaType == (kUTTypeMovie as String),
                let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL
               else { return }
        
        dismiss(animated: true)
        
        extractAudioFromVideo(url)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

}


extension SBHomeVC: UITableViewDelegate, UITableViewDataSource, SBAudioCellDelegate {
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
        
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") {[weak self] (action, view, completionHandler) in
            self?.deleteAudio(indexPath.row)
            completionHandler(true)
        }
        
        deleteAction.backgroundColor = .red
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = false
        
        return configuration
    }
    
    private func deleteAudio(_ index: Int) {
        let list = isSearchMode ? filteredAudioInfoList : audioInfoList
        let audioInfo = list[index]
        
        SBAudioManager.shared.deleteAudio(audioInfo.file)
    }
    
    // SBAudioCell Delegate
    
    func audioCellPlayAudio(_ audioInfo: SBAudioInfo?) {
        stopAudioPlayer()
        
        selectedAudioInfo = audioInfo
        playAudioPlayer()
    }
    
    func audioCellPauseAudio(_ audioInfo: SBAudioInfo?) {
        pauseAudioPlayer()
        selectedAudioInfo = nil
    }
}

extension SBHomeVC: UISearchBarDelegate {
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
        searchBar.showsCancelButton = true
        return true
    }
}
