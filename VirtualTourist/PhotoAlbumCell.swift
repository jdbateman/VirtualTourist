//
//  PhotoAlbumCell.swift
//  VirtualTourist
//
//  Created by john bateman on 9/19/15.
//  Copyright (c) 2015 John Bateman. All rights reserved.
//

import UIKit

class PhotoAlbumCell: UICollectionViewCell {

    var activityIndicator : UIActivityIndicatorView = UIActivityIndicatorView(frame: CGRectMake(0, 0, 84, 84)) as UIActivityIndicatorView

    @IBOutlet weak var imageView: UIImageView!
    
    /* show activity indicator */
    func startActivityIndicator() {
        activityIndicator.center =  CGPointMake(42.0, 42.0) // self.imageView.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.WhiteLarge
        imageView.addSubview(activityIndicator)
        activityIndicator.startAnimating()
    }
    
    /* hide acitivity indicator */
    func stopActivityIndicator() {
        dispatch_async(dispatch_get_main_queue()) {
            self.activityIndicator.stopAnimating()
        }
    }
}
