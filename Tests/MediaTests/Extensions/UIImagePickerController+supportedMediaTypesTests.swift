//
//  UIImagePickerController+supportedMediaTypesTests.swift
//  MediaTests
//
//  Created by Christian Elies on 17.12.19.
//

#if canImport(UIKit) && !os(tvOS) && !os(visionOS)
@testable import MediaCore
import XCTest
import UIKit

final class UIImagePickerController_supportedMediaTypesTests: XCTestCase {
    /*
        Camera is not supported in simulator
     */
    func testSupportedMediaTypesForCameraWithNoGivenMediaTypes() {
        let supportedMediaTypes = UIImagePickerController.supportedMediaTypes(from: [], sourceType: .camera)
        XCTAssertNil(supportedMediaTypes)
    }

    func testSupportedMediaTypesForPhotoLibraryWithNoGivenMediaTypes() {
        let supportedMediaTypes = UIImagePickerController.supportedMediaTypes(from: [], sourceType: .photoLibrary)
        XCTAssertNotNil(supportedMediaTypes)
        let availableMediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary)
        XCTAssertEqual(supportedMediaTypes, availableMediaTypes)
    }

    func testSupportedMediaTypesForSavedPhotosAlbumWithNoGivenMediaTypes() {
        let supportedMediaTypes = UIImagePickerController.supportedMediaTypes(from: [], sourceType: .savedPhotosAlbum)
        XCTAssertNotNil(supportedMediaTypes)
        let availableMediaTypes = UIImagePickerController.availableMediaTypes(for: .savedPhotosAlbum)
        XCTAssertEqual(supportedMediaTypes, availableMediaTypes)
    }

    func testSupportedMediaTypesForPhotoLibraryWithSomeGivenMediaTypes() {
        let supportedMediaTypes = UIImagePickerController.supportedMediaTypes(from: Set(UIImagePickerController.MediaType.allCases), sourceType: .photoLibrary)
        let expectedMediaTypes: [String] = [UIImagePickerController.MediaType.image.cfString, .movie].map { $0 as String }
        XCTAssertEqual(supportedMediaTypes?.sorted(), expectedMediaTypes.sorted())
    }

    func testSupportedMediaTypesForSavedPhotosAlbumWithSomeGivenMediaTypes() {
        let supportedMediaTypes = UIImagePickerController.supportedMediaTypes(from: Set(UIImagePickerController.MediaType.allCases), sourceType: .savedPhotosAlbum)
        let expectedMediaTypes: [String] = [UIImagePickerController.MediaType.image.cfString, .movie].map { $0 as String }
        XCTAssertEqual(supportedMediaTypes?.sorted(), expectedMediaTypes.sorted())
    }

    /*
        Live photos seem to be unsupported in simulator
     */
    func testSupportedMediaTypesForPhotoLibraryWithLivePhotoMediaType() {
        let supportedMediaTypes = UIImagePickerController.supportedMediaTypes(from: [.livePhoto], sourceType: .photoLibrary)
        XCTAssertNil(supportedMediaTypes)
    }

    /*
        Live photos seem to be unsupported in simulator
     */
    func testSupportedMediaTypesForSavedPhotosAlbumWithLivePhotoMediaType() {
        let supportedMediaTypes = UIImagePickerController.supportedMediaTypes(from: [.livePhoto], sourceType: .savedPhotosAlbum)
        XCTAssertNil(supportedMediaTypes)
    }
}
#endif
