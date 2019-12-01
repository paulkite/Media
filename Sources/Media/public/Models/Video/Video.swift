//
//  Video.swift
//  Media
//
//  Created by Christian Elies on 21.11.19.
//  Copyright © 2019 Christian Elies. All rights reserved.
//

import Photos

public struct Video: MediaProtocol {
    public let phAsset: PHAsset

    public let type: MediaType = .video
    public var isFavorite: Bool { phAsset.isFavorite }

    public init(phAsset: PHAsset) {
        self.phAsset = phAsset
    }
}

public extension Video {
    var subtypes: [VideoSubtype] {
        var types: [VideoSubtype] = []

        switch phAsset.mediaSubtypes {
        case [.videoHighFrameRate, .videoStreamed, .videoTimelapse]:
            types.append(contentsOf: [.highFrameRate, .streamed, .timelapse])

        case [.videoHighFrameRate, .videoStreamed]:
            types.append(contentsOf: [.highFrameRate, .streamed])
        case [.videoStreamed, .videoTimelapse]:
            types.append(contentsOf: [.streamed, .timelapse])

        case [.videoHighFrameRate]:
            types.append(.highFrameRate)
        case [.videoStreamed]:
            types.append(.streamed)
        case [.videoTimelapse]:
            types.append(.timelapse)
        default: ()
        }

        return types
    }
}

public extension Video {
    func playerItem(_ completion: @escaping (Result<AVPlayerItem, Error>) -> Void) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestPlayerItem(forVideo: phAsset, options: options) { playerItem, info in
            PHImageManager.handleResult(result: (playerItem, info), completion)
        }
    }

    func avAsset(_ completion: @escaping (Result<AVAsset, Error>) -> Void) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { asset, _, info in
            PHImageManager.handleResult(result: (asset, info), completion)
        }
    }

    func export(_ exportOptions: Video.ExportOptions, progress: @escaping (Video.ExportProgress) -> Void, _ completion: @escaping (Result<Void, Error>) -> Void) {
        let requestOptions = PHVideoRequestOptions()
        requestOptions.isNetworkAccessAllowed = true

        PHImageManager.default().requestExportSession(forVideo: phAsset,
                                                      options: requestOptions,
                                                      exportPreset: exportOptions.quality.avAssetExportPreset)
        { exportSession, info in
            if let error = info?[PHImageErrorKey] as? Error {
                completion(.failure(error))
            } else if let exportSession = exportSession {
                // TODO: improve
                exportSession.determineCompatibleFileTypes { compatibleFileTypes in
                    guard compatibleFileTypes.contains(exportOptions.fileType.avFileType) else {
                        completion(.failure(VideoError.unsupportedFileType))
                        return
                    }

                    exportSession.outputURL = exportOptions.outputURL
                    exportSession.outputFileType = exportOptions.fileType.avFileType

                    var timer: Timer?
                    if #available(iOS 10.0, *) {
                        timer = Timer(timeInterval: 1, repeats: true) { timer in
                            self.handleProgressTimerFired(exportSession: exportSession,
                                                          timer: timer,
                                                          progress: progress)
                        }
                    } else {
                        let timerWrapper = TimerWrapper(timeInterval: 1, repeats: true) { timer in
                            self.handleProgressTimerFired(exportSession: exportSession,
                                                          timer: timer,
                                                          progress: progress)
                        }
                        timer = timerWrapper.timer
                    }

                    if let timer = timer {
                        RunLoop.main.add(timer, forMode: .common)
                    }

                    exportSession.exportAsynchronously {
                        switch exportSession.status {
                        case .completed:
                            timer?.invalidate()
                            completion(.success(()))
                        case .failed:
                            timer?.invalidate()
                            completion(.failure(exportSession.error ?? PhotosError.unknown))
                        default: ()
                        }
                    }
                }
            } else {
                completion(.failure(PhotosError.unknown))
            }
        }
    }
}

public extension Video {
    static func with(identifier: String) -> Video? {
        let options = PHFetchOptions()
        let predicate = NSPredicate(format: "localIdentifier = %@ && mediaType = %d", identifier, MediaType.video.rawValue)
        options.predicate = predicate

        let video = PHAssetFetcher.fetchAsset(options: options) { asset in
            if asset.localIdentifier == identifier && asset.mediaType == .video {
                return true
            }
            return false
        } as Video?
        return video
    }
}

public extension Video {
    static func save(_ url: URL, _ completion: @escaping (Result<Video, Error>) -> Void) {
        guard Media.isAccessAllowed else {
            completion(.failure(Media.currentPermission.permissionError ?? PermissionError.unknown))
            return
        }

        let supportedPathExtensions = Set(Video.FileType.allCases.map { $0.pathExtension })

        switch url.pathExtension {
        case \.isEmpty:
            completion(.failure(VideoError.missingPathExtension))
            return
        case .unsupportedPathExtension(supportedPathExtensions: supportedPathExtensions):
            completion(.failure(VideoError.unsupportedPathExtension))
            return
        default: ()
        }

        PHAssetChanger.createRequest({ PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) }, completion)
    }

    // TODO:
    func edit(_ change: @escaping (inout PHContentEditingInput?) -> Void, completion: @escaping (Result<Void, Error>) -> Void) -> Cancellable {
        let options = PHContentEditingInputRequestOptions()
        let contentEditingInputRequestID = phAsset.requestContentEditingInput(with: options) { contentEditingInput, info in
            var contentEditingInput = contentEditingInput
            change(&contentEditingInput)

            if let editingInput = contentEditingInput {
                guard Media.isAccessAllowed else {
                    completion(.failure(Media.currentPermission.permissionError ?? PermissionError.unknown))
                    return
                }

                let output = PHContentEditingOutput(contentEditingInput: editingInput)

                PHPhotoLibrary.shared().performChanges({
                    let assetChangeRequest = PHAssetChangeRequest(for: self.phAsset)
                    assetChangeRequest.contentEditingOutput = output
                }) { isSuccess, error in
                    if !isSuccess {
                        completion(.failure(error ?? PhotosError.unknown))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        }

        return {
            self.phAsset.cancelContentEditingInputRequest(contentEditingInputRequestID)
        }
    }

    func favorite(_ favorite: Bool, _ completion: @escaping (Result<Void, Error>) -> Void) {
        guard Media.isAccessAllowed else {
            completion(.failure(Media.currentPermission.permissionError ?? PermissionError.unknown))
            return
        }

        PHAssetChanger.favorite(phAsset: phAsset, favorite: favorite, completion)
    }
}

extension Video {
    private func handleProgressTimerFired(exportSession: AVAssetExportSession,
                                          timer: Timer,
                                          progress: @escaping (Video.ExportProgress) -> Void) {
        guard exportSession.progress < 1 else {
            let exportProgress: ExportProgress = .completed
            progress(exportProgress)
            timer.invalidate()
            return
        }
        let exportProgress: ExportProgress = .pending(value: exportSession.progress)
        progress(exportProgress)
    }
}

#if canImport(SwiftUI)
import SwiftUI

@available (iOS 13, OSX 10.15, tvOS 13, *)
public extension Video {
    var view: some View {
        VideoView(video: self)
    }

    static func browser(_ completion: @escaping (Result<Video, Error>) -> Void) throws -> some View {
        try ViewCreator.browser(mediaTypes: [.movie], completion)
    }
}

@available (iOS 13, OSX 10.15, *)
public extension Video {
    static func camera(_ completion: @escaping (Result<URL, Error>) -> Void) throws -> some View {
        try ViewCreator.camera(for: [.movie], completion)
    }

    // TODO: UIVideoEditorController
//    static func editor() -> some View {
//        EmptyView()
//    }
}
#endif
