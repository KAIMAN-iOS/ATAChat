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
    init(router: RouterType, conf: ATAConfiguration) {
        super.init(router: router)
    }
}
