//
//  File.swift
//  
//
//  Created by GG on 10/03/2021.
//

import UIKit
import TableViewExtension
import ATAViews

class ChannelCell: UITableViewCell {
    @IBOutlet weak var badgeview: UIView! {
        didSet {
            badge = ATABadgeView(view: badgeview)
        }
    }
    
    @IBOutlet weak var arrow: UIImageView!  {
        didSet {
            arrow.tintColor = ChannelsViewController.conf.palette.inactive
        }
    }
    @IBOutlet weak var label: UILabel!
    var badge: BadgeHub!
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    func updateUnreadCount(_ count: Int) {
        badge.setCount(count)
    }
    
    func configure(_ channel: Channel, for mode: Mode) {
        backgroundColor = ChannelsViewController.conf.palette.background
        label.set(text: channel.displayName(for: mode), for: .subheadline, textColor: ChannelsViewController.conf.palette.mainTexts)
        layoutIfNeeded()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        addDefaultSelectedBackground(ChannelsViewController.conf.palette.primary.withAlphaComponent(0.3))
    }
}
