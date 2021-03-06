//
//  Request+AlamofireImage.swift
//
//  Copyright (c) 2015-2016 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Alamofire
import Foundation

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(watchOS)
import UIKit
import WatchKit
#elseif os(OSX)
import Cocoa
#endif

extension DataRequest {
    static var acceptableImageContentTypes: Set<String> = [
        "image/tiff",
        "image/jpeg",
        "image/gif",
        "image/png",
        "image/ico",
        "image/x-icon",
        "image/bmp",
        "image/x-bmp",
        "image/x-xbitmap",
        "image/x-ms-bmp",
        "image/x-win-bitmap"
    ]

    /// Adds the content types specified to the list of acceptable images content types for validation.
    ///
    /// - parameter contentTypes: The additional content types.
    public class func addAcceptableImageContentTypes(_ contentTypes: Set<String>) {
        DataRequest.acceptableImageContentTypes.formUnion(contentTypes)
    }

    // MARK: - iOS, tvOS and watchOS

#if os(iOS) || os(tvOS) || os(watchOS)

    /// Creates a response serializer that returns an image initialized from the response data using the specified
    /// image options.
    ///
    /// - parameter imageScale:           The scale factor used when interpreting the image data to construct
    ///                                   `responseImage`. Specifying a scale factor of 1.0 results in an image whose
    ///                                   size matches the pixel-based dimensions of the image. Applying a different
    ///                                   scale factor changes the size of the image as reported by the size property.
    ///                                   `Screen.scale` by default.
    /// - parameter inflateResponseImage: Whether to automatically inflate response image data for compressed formats
    ///                                   (such as PNG or JPEG). Enabling this can significantly improve drawing
    ///                                   performance as it allows a bitmap representation to be constructed in the
    ///                                   background rather than on the main thread. `true` by default.
    ///
    /// - returns: An image response serializer.
    public class func imageResponseSerializer(
        imageScale: CGFloat = DataRequest.imageScale,
        inflateResponseImage: Bool = true)
        -> DataResponseSerializer<Image>
    {
        return DataResponseSerializer { request, response, data, error in
            let result = serializeResponseData(response: response, data: data, error: error)

            guard case let .success(data) = result else { return .failure(result.error!) }

            do {
                try DataRequest.validateContentType(for: request, response: response)

                let image = try DataRequest.image(from: data, withImageScale: imageScale)
                if inflateResponseImage { image.af_inflate() }

                return .success(image)
            } catch {
                return .failure(error)
            }
        }
    }

    /// Adds a handler to be called once the request has finished.
    ///
    /// - parameter imageScale:           The scale factor used when interpreting the image data to construct
    ///                                   `responseImage`. Specifying a scale factor of 1.0 results in an image whose
    ///                                   size matches the pixel-based dimensions of the image. Applying a different
    ///                                   scale factor changes the size of the image as reported by the size property.
    ///                                   This is set to the value of scale of the main screen by default, which
    ///                                   automatically scales images for retina displays, for instance.
    ///                                   `Screen.scale` by default.
    /// - parameter inflateResponseImage: Whether to automatically inflate response image data for compressed formats
    ///                                   (such as PNG or JPEG). Enabling this can significantly improve drawing
    ///                                   performance as it allows a bitmap representation to be constructed in the
    ///                                   background rather than on the main thread. `true` by default.
    /// - parameter completionHandler:    A closure to be executed once the request has finished. The closure takes 4
    ///                                   arguments: the URL request, the URL response, if one was received, the image,
    ///                                   if one could be created from the URL response and data, and any error produced
    ///                                   while creating the image.
    ///
    /// - returns: The request.
    @discardableResult
    public func responseImage(
        imageScale: CGFloat = DataRequest.imageScale,
        inflateResponseImage: Bool = true,
        completionHandler: @escaping (DataResponse<Image>) -> Void)
        -> Self
    {
        return response(
            responseSerializer: DataRequest.imageResponseSerializer(
                imageScale: imageScale,
                inflateResponseImage: inflateResponseImage
            ),
            completionHandler: completionHandler
        )
    }

    private class func image(from data: Data, withImageScale imageScale: CGFloat) throws -> UIImage {
        if let image = UIImage.af_threadSafeImage(with: data, scale: imageScale) {
            return image
        }

        throw AFIError.imageSerializationFailed
    }

    private class var imageScale: CGFloat {
        #if os(iOS) || os(tvOS)
            return UIScreen.main.scale
        #elseif os(watchOS)
            return WKInterfaceDevice.current().screenScale
        #endif
    }

#elseif os(OSX)

    // MARK: - OSX

    /// Creates a response serializer that returns an image initialized from the response data.
    ///
    /// - returns: An image response serializer.
    public class func imageResponseSerializer() -> DataResponseSerializer<Image> {
        return DataResponseSerializer { request, response, data, error in
            let result = serializeResponseData(response: response, data: data, error: error)

            guard case let .success(data) = result else { return .failure(result.error!) }

            do {
                try DataRequest.validateContentType(for: request, response: response)
            } catch {
                return .failure(error)
            }

            guard let bitmapImage = NSBitmapImageRep(data: data) else {
                return .failure(AFIError.imageSerializationFailed)
            }

            let image = NSImage(size: NSSize(width: bitmapImage.pixelsWide, height: bitmapImage.pixelsHigh))
            image.addRepresentation(bitmapImage)

            return .success(image)
        }
    }

    /// Adds a handler to be called once the request has finished.
    ///
    /// - parameter completionHandler: A closure to be executed once the request has finished. The closure takes 4
    ///                                arguments: the URL request, the URL response, if one was received, the image, if
    ///                                one could be created from the URL response and data, and any error produced while
    ///                                creating the image.
    ///
    /// - returns: The request.
    @discardableResult
    public func responseImage(completionHandler: @escaping (DataResponse<Image>) -> Void) -> Self {
        return response(
            responseSerializer: DataRequest.imageResponseSerializer(),
            completionHandler: completionHandler
        )
    }

#endif

    // MARK: - Private - Shared Helper Methods

    private class func validateContentType(for request: URLRequest?, response: HTTPURLResponse?) throws {
        if let url = request?.url, url.isFileURL { return }

        guard let mimeType = response?.mimeType else {
            let contentTypes = Array(DataRequest.acceptableImageContentTypes)
            throw AFError.responseValidationFailed(reason: .missingContentType(acceptableContentTypes: contentTypes))
        }

        guard DataRequest.acceptableImageContentTypes.contains(mimeType) else {
            let contentTypes = Array(DataRequest.acceptableImageContentTypes)

            throw AFError.responseValidationFailed(
                reason: .unacceptableContentType(acceptableContentTypes: contentTypes, responseContentType: mimeType)
            )
        }
    }
}
