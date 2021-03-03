//
//  File.swift
//  
//
//  Created by GG on 22/02/2021.
//

import UIKit
import KCoordinatorKit
import ATAConfiguration

protocol ChatCoordinatorDelegate: NSObjectProtocol {
    func show(channel: Channel)
}

public class ChatCoordinator<DeepLinkType>: Coordinator<DeepLinkType> {
    dynamic var channelController: ChannelsViewController!
    var currentUser: ChatUser!
    var channelId: String?
    public init(router: RouterType,
                currentUser: ChatUser,
                channelId: String? = nil,
                groups: [AlertGroupable],
                conf: ATAConfiguration) {
        super.init(router: router)
        self.currentUser = currentUser
        self.channelId = channelId
        channelController = ChannelsViewController(currentUser: currentUser, groups: groups, coordinatorDelegate: self)
        channelController.startListenning()
        ChannelsViewController.conf = conf
    }
    public override func toPresentable() -> UIViewController { channelController }
    
    public func startAndPush(completion: @escaping (() -> Void)) {
        guard let channelId = self.channelId else {
            showChannels(animated: true, completion: completion)
            return
        }
        showTargetChannel(channelId: channelId, completion: completion)
    }
    
    func showChannels(animated: Bool, completion: @escaping (() -> Void)) {
        router.push(channelController, animated: animated, completion: completion)
    }
    
    var channelObserver: NSKeyValueObservation?
    func showTargetChannel(channelId: String, completion: @escaping (() -> Void)) {
        guard let channel = channelController.cellTypes.flatMap({ $0.channels }).filter({ $0.id == channelId }).first,
              channelObserver == nil else {
            channelObserver = channelController.observe(\.channels, options: [.new], changeHandler: { [weak self] (controller, change) in
                guard let self = self else { return }
                guard let channel = change.newValue?.first(where: { $0.id == channelId }) else { return }
                self.showChannels(animated: false, completion: completion)
                self.show(channel: channel)
                self.channelObserver = nil
            })
            return
        }
        showChannels(animated: false, completion: completion)
        show(channel: channel)
    }
}

extension ChatCoordinator: ChatCoordinatorDelegate {
    func show(channel: Channel) {
        let ctrl = ChatViewController(user: currentUser, channel: channel)
        router.push(ctrl, animated: true, completion: nil)
    }
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

