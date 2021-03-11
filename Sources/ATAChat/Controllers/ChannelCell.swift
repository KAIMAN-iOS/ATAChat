//
//  File.swift
//  
//
//  Created by GG on 10/03/2021.
//

import UIKit
import TableViewExtension

class ChannelCell: UITableViewCell {
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var arrow: UIImageView!  {
        didSet {
            arrow.tintColor = ChannelsViewController.conf.palette.inactive
        }
    }
    @IBOutlet weak var label: UILabel!
    func configure(_ channel: Channel) {
        icon.isHidden = true
        label.set(text: channel.name, for: .subheadline, textColor: ChannelsViewController.conf.palette.mainTexts)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        addDefaultSelectedBackground(ChannelsViewController.conf.palette.primary.withAlphaComponent(0.3))
    }
}
