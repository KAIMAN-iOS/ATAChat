//
//  File.swift
//  
//
//  Created by GG on 22/02/2021.
//

import UIKit
import KCoordinatorKit
import ATAConfiguration

class ChatCoordinator<DeepLinkType>: Coordinator<DeepLinkType> {
    var channelController: ChannelsViewController!
    init(router: RouterType, currentUser: ChatUser, conf: ATAConfiguration) {
        super.init(router: router)
        channelController = ChannelsViewController(currentUser: currentUser)
    }
    override func toPresentable() -> UIViewController { channelController }
}

extension String {
    func bundleLocale() -> String {
        NSLocalizedString(self, bundle: .main, comment: self)
    }
}
