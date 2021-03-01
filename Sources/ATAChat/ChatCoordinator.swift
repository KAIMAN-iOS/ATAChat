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
    public init(router: RouterType, currentUser: ChatUser, groups: [AlertGroupable], conf: ATAConfiguration) {
        super.init(router: router)
        channelController = ChannelsViewController(currentUser: currentUser, groups: groups)
        ChannelsViewController.conf = conf
    }
    public override func toPresentable() -> UIViewController { channelController }
}

extension String {
    func bundleLocale() -> String {
        NSLocalizedString(self, bundle: .moduleBundle, comment: self)
    }
}

private class BundleFinder {}
extension Foundation.Bundle {
    /// Returns the resource bundle associated with the current Swift module.
    static var moduleBundle: Bundle = {
        let bundleName = "ATAChat_ATAChat"

        let candidates = [
            // Bundle should be present here when the package is linked into an App.
            Bundle.main.resourceURL,

            // Bundle should be present here when the package is linked into a framework.
            Bundle(for: BundleFinder.self).resourceURL,

            // For command-line tools.
            Bundle.main.bundleURL,
        ]

        for candidate in candidates {
            let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
                return bundle
            }
        }
        fatalError("unable to find bundle named ATAChat_ATAChat")
    }()
}

