// Copyright (c) 2020 Razeware LLC
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
// distribute, sublicense, create a derivative work, and/or sell copies of the
// Software in any work that is designed, intended, or marketed for pedagogical or
// instructional purposes related to programming, coding, application development,
// or information technology.  Permission for such use, copying, modification,
// merger, publication, distribution, sublicensing, creation of derivative works,
// or sale is expressly withheld.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import Combine

final class SettingsManager: ObservableObject {
  // MARK: Internal Properties
  private let jsonEncoder = JSONEncoder()
  private let jsonDecoder = JSONDecoder()
  private let userDefaults: UserDefaults
  private let userModelController: UserModelController
  
  private var subscriptions = Set<AnyCancellable>()
  
  // MARK: Subjects
  private let playbackSpeedSubject = PassthroughSubject<PlaybackSpeed, Never>()
  private let closedCaptionOnSubject = PassthroughSubject<Bool, Never>()
  private let wifiOnlyDownloadsSubject = PassthroughSubject<Bool, Never>()
  private let downloadQualitySubject = PassthroughSubject<Attachment.Kind, Never>()
  
  // MARK: Initialisers
  init(userDefaults: UserDefaults = UserDefaults.standard, userModelController: UserModelController) {
    self.userDefaults = userDefaults
    self.userModelController = userModelController
    
    self.configureSubscriptions()
  }
  
  // MARK: Methods
  func resetAll() {
    SettingsKey.allCases.forEach { settingsKey in
      userDefaults.removeObject(forKey: settingsKey)
    }
  }
}

extension SettingsManager {
  private func configureSubscriptions() {
    userModelController.objectDidChange.sink { [weak self] _ in
      guard let self = self else { return }
      
      // Reset all settings if the user is blank—i.e. not logged in
      if self.userModelController.user == nil {
        self.resetAll()
      }
    }
    .store(in: &subscriptions)
  }
}

// We'll store all these settings inside 
extension SettingsManager: EmitronSettings {
  var filters: Set<Filter> {
    get {
      guard let data = userDefaults.object(forKey: .filters) as? [Data] else {
        return []
      }
      return Set(data.compactMap { try? jsonDecoder.decode(Filter.self, from: $0) })
    }
    set {
      objectWillChange.send()
      let encodedFilters = newValue.compactMap { try? jsonEncoder.encode($0) }
      userDefaults.set(encodedFilters, forKey: .filters)
    }
  }
  
  var sortFilter: SortFilter {
    get {
      guard let data = userDefaults.object(forKey: .sortFilters) as? Data,
        let sortFilter = try? jsonDecoder.decode(SortFilter.self, from: data) else {
        return SortFilter.newest
      }
      return sortFilter
    }
    set {
      objectWillChange.send()
      let encodedFilter = try? jsonEncoder.encode(newValue)
      userDefaults.set(encodedFilter, forKey: .sortFilters)
    }
  }
  
  var playbackToken: String? {
    get {
      userDefaults.object(forKey: .playbackToken) as? String
    }
    set {
      objectWillChange.send()
      userDefaults.set(newValue, forKey: .playbackToken)
    }
  }
  
  var playbackSpeed: PlaybackSpeed {
    get {
      guard let speed = userDefaults.object(forKey: .playbackSpeed) as? Int,
        let playbackSpeed = PlaybackSpeed(rawValue: speed) else {
          return PlaybackSpeed.standard
      }
      return playbackSpeed
    }
    set {
      objectWillChange.send()
      userDefaults.set(newValue.rawValue, forKey: .playbackSpeed)
      playbackSpeedSubject.send(newValue)
    }
  }
  
  var closedCaptionOn: Bool {
    get {
      userDefaults.object(forKey: .closedCaptionOn) as? Bool ?? false
    }
    set {
      objectWillChange.send()
      userDefaults.set(newValue, forKey: .closedCaptionOn)
      closedCaptionOnSubject.send(newValue)
    }
  }
  
  var downloadQuality: Attachment.Kind {
    get {
      guard let quality = userDefaults.object(forKey: .downloadQuality) as? Int,
        let downloadQuality = Attachment.Kind(rawValue: quality),
        [.hdVideoFile, .sdVideoFile].contains(downloadQuality) else {
        return Attachment.Kind.hdVideoFile
      }
      return downloadQuality
    }
    set {
      objectWillChange.send()
      userDefaults.set(newValue.rawValue, forKey: .downloadQuality)
      downloadQualitySubject.send(newValue)
    }
  }
  
  var wifiOnlyDownloads: Bool {
    get {
      userDefaults.object(forKey: .wifiOnlyDownloads) as? Bool ?? false
    }
    set {
      objectWillChange.send()
      userDefaults.set(newValue, forKey: .wifiOnlyDownloads)
      wifiOnlyDownloadsSubject.send(newValue)
    }
  }
  
  var playbackSpeedPublisher: AnyPublisher<PlaybackSpeed, Never> {
    playbackSpeedSubject.eraseToAnyPublisher()
  }
  
  var closedCaptionOnPublisher: AnyPublisher<Bool, Never> {
    closedCaptionOnSubject.eraseToAnyPublisher()
  }
  
  var downloadQualityPublisher: AnyPublisher<Attachment.Kind, Never> {
    downloadQualitySubject.eraseToAnyPublisher()
  }
  
  var wifiOnlyDownloadsPublisher: AnyPublisher<Bool, Never> {
    wifiOnlyDownloadsSubject.eraseToAnyPublisher()
  }
}
