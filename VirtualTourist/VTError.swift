//
//  VTError.swift
//  VirtualTourist
//
//  Created by john bateman on 10/6/15.
//  Copyright (c) 2015 John Bateman. All rights reserved.
//

import Foundation


class VTError {
    
    var error: NSError?
    
    struct Constants {
        static let ERROR_DOMAIN: String = "self.VirtualTourist.Error"
    }
    
    enum ErrorCodes: Int {
        case CORE_DATA_INIT_ERROR = 9000
        case JSON_PARSE_ERROR = 9001
        case FLICKR_REQUEST_ERROR = 9002
        case FLICKR_FILE_DOWNLOAD_ERROR = 9003
        case IMAGE_CONVERSION_ERROR = 9004
        case FILE_NOT_FOUND_ERROR = 9005
    }
    
    init(errorString: String, errorCode: ErrorCodes) {
        // output to console
        println(errorString)
        
        // construct NSError
        var dict = [String: AnyObject]()
        dict[NSLocalizedDescriptionKey] = errorString
        error = NSError(domain: VTError.Constants.ERROR_DOMAIN, code: errorCode.rawValue, userInfo: dict)
    }
}