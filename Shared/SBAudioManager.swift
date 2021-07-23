//
//  SBAudioManager.swift
//  SoundBite
//

import UIKit

class SBAudioManager: NSObject {

    static let shared = SBAudioManager()
    
    // Shared Keys
    private let keyAudioList = "shared_audios"
    
    // URL paths
    private let kAudioFileExtension = ".m4a"
    private let kAudiosPath = "audios"
    private let kTempAudioFile = "sb_temp.m4a"
    private let kRecordingAudioFile = "sb_recording.m4a"
    private let kTrimmedAudioFile = "sb_trimmed.m4a"
    
    private let kVideoExportFile = "sb_video_export.mp4"
    
    private let fileManager: FileManager = FileManager.default
    
    private var sharedUserDefaults: UserDefaults?
    private let appGroupID: String = "group.com.kynginc.soundbite"
    
    private var documentURL: URL?
    private var sharedAudiosBaseURL: URL?
    
    override init() {
        super.init()
        
        sharedUserDefaults = UserDefaults.init(suiteName: appGroupID)
        createAudiosDirectory()
    }
    
    private func documentsDirectory() -> URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let appDocumentDirectory = paths[0]
        
        return appDocumentDirectory
    }
    
    private func createAudiosDirectory() {
        
        documentURL = documentsDirectory()
        
        // Get Shared App Group URL
        let baseURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        sharedAudiosBaseURL = baseURL?.appendingPathComponent(kAudiosPath, isDirectory:  true)
        
        // Check projects directory in Documents directory, if not exist, then create and create the sticker images from old project thumbnail image
        
        if let url = sharedAudiosBaseURL {
            if fileManager.fileExists(atPath: url.path) == false {
               try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            }
        }
    }
    
    private func generateAudioFileName() -> String {
        //let projectId = UUID().uuidString
        
        let timeStamp = Int(Date().timeIntervalSince1970 * 1000)
        let fileName = String(timeStamp) + kAudioFileExtension
        return fileName
    }
    
    private func loadAudioList() -> [[String: Any]] {
        if let list = sharedUserDefaults?.array(forKey: keyAudioList) as? [[String: Any]] {
            return list
        }
        
        return []
    }
    
    // Get Audio List
    func loadAudioInfoList() -> [SBAudioInfo] {
        
        let list = loadAudioList()
        var result: [SBAudioInfo] = []
        for obj in list {
            result.append(SBAudioInfo(dic: obj))
        }
        return result
    }
    
    func getAudioURL(fileName: String) -> URL? {
        return sharedAudiosBaseURL?.appendingPathComponent(fileName)
    }
    
    func audioRecordingFileURL() -> URL? {
        return documentURL?.appendingPathComponent(kRecordingAudioFile)
    }
    
    func audioTempFileURL() -> URL? {
        return documentURL?.appendingPathComponent(kTempAudioFile)
    }
    
    func audioTrimmedFileURL() -> URL? {
        return documentURL?.appendingPathComponent(kTrimmedAudioFile)
    }
    
    func videoExportFileURL() -> URL? {
        return documentURL?.appendingPathComponent(kVideoExportFile)
    }
    
    func saveAudioFileData(_ audioData: Data, title: String) -> Bool {
        let fileName = generateAudioFileName()
        if let audioURL = sharedAudiosBaseURL?.appendingPathComponent(fileName) {
            do {
                try audioData.write(to: audioURL)
                
                let audioInfo = ["title": title,
                                 "file": fileName
                                ]
                var audioList = loadAudioList()
                audioList.insert(audioInfo, at: 0)
                sharedUserDefaults?.set(audioList, forKey: keyAudioList)
                sharedUserDefaults?.synchronize()
                
                NotificationCenter.default.post(name: .refreshAudioFiles, object: nil)
                return true
            }catch {
                print("Has error in saving the audio file.")
            }
        }
        
        return false
    }
    
    func saveAudioFile(_ audioURL: URL, title: String) -> Bool {
        
        if let audioData = try? Data.init(contentsOf: audioURL) {
            return saveAudioFileData(audioData, title: title)
        }
         
        return false
    }
    
    func deleteAudio(_ audioFileName: String) {
        var audioList = loadAudioList()
        audioList.removeAll { (info) -> Bool in
            if let file = info["file"] as? String, file == audioFileName {
                return true
            }
            
            return false
        }
        
        sharedUserDefaults?.set(audioList, forKey: keyAudioList)
        sharedUserDefaults?.synchronize()
        
        NotificationCenter.default.post(name: .refreshAudioFiles, object: nil)
    }
    
}
