//
//  File.swift
//  
//
//  Created by GG on 22/02/2021.
//

import UIKit
import KCoordinatorKit
import ATAConfiguration

public class ChatCoordinator<DeepLinkType>: Coordinator<DeepLinkType> {
    var channelController: ChannelsViewController!
    public init(router: RouterType, currentUser: ChatUser, conf: ATAConfiguration) {
        super.init(router: router)
        channelController = ChannelsViewController(currentUser: currentUser)
        ChannelsViewController.conf = conf
    }
    public override func toPresentable() -> UIViewController { channelController }
}

extension String {
    func bundleLocale() -> String {
        NSLocalizedString(self, bundle: .main, comment: self)
    }
}
