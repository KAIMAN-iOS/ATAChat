//
//  File.swift
//  
//
//  Created by GG on 22/02/2021.
//

import UIKit
import KCoordinatorKit
import ATAConfiguration
import Lottie
import MessageKit
import FirebaseFirestore

protocol ChatCoordinatorDelegate: NSObjectProtocol {
    func show(channel: Channel)
}
// if one wnat to override the Message Cells or detectors, use this delegate
public protocol ATAChatMessageDelegate: AnyObject {
    func messageForDocument(_ doc: QueryDocumentSnapshot) -> Message?
    // returns wether the delegate handled the tap or not
    func didTapMessage(for item: Message) -> Bool
}

public enum Mode { case driver, passenger }

public class ChatCoordinator<DeepLinkType>: Coordinator<DeepLinkType> {
    dynamic var channelController: ChannelsViewController!
    var currentUser: ChatUser!
    var channelId: String?
    var chatMessageDelegate: ATAChatMessageDelegate?
    public init(router: RouterType,
                currentUser: ChatUser,
                channelId: String? = nil,
                mode: Mode = .driver,
                groups: [AlertGroupable] = [],
                conf: ATAConfiguration,
                chatMessageDelegate: ATAChatMessageDelegate? = nil,
                emojiAnimation: Animation,
                noChannelAnimation: Animation) {
        super.init(router: router)
        ChannelsViewController.conf = conf
        self.currentUser = currentUser
        self.channelId = channelId
        self.chatMessageDelegate = chatMessageDelegate
        channelController = ChannelsViewController.create(currentUser: currentUser,
                                                          groups: groups,
                                                          mode: mode,
                                                          coordinatorDelegate: self,
                                                          emojiAnimation: emojiAnimation,
                                                          noChannelAnimation: noChannelAnimation)
        channelController.startListenning()
    }
    public override func toPresentable() -> UIViewController { channelController }
    
    deinit {
        print("💀 DEINIT \(URL(fileURLWithPath: #file).lastPathComponent)")
        channelController.stopListenning()
    }
    
    public func startAndPush(showChannelsControllers: Bool = false, completion: @escaping (() -> Void)) {
        guard let channelId = self.channelId else {
            showChannels(animated: true, completion: completion)
            return
        }
        showTargetChannel(channelId: channelId, showChannelsControllers: showChannelsControllers, completion: completion)
    }
    
    func showChannels(animated: Bool, completion: @escaping (() -> Void)) {
        router.push(channelController, animated: animated, completion: completion)
    }
    
    var channelObserver: NSKeyValueObservation?
    func showTargetChannel(channelId: String, showChannelsControllers: Bool = false, completion: @escaping (() -> Void)) {
        guard let channel = channelController.cellTypes.flatMap({ $0.channels }).filter({ $0.id == channelId }).first,
              channelObserver == nil else {
            channelObserver = channelController.observe(\.channels, options: [.new], changeHandler: { [weak self] (controller, change) in
                guard let self = self else { return }
                guard let channel = change.newValue?.first(where: { $0.id == channelId }) else { return }
                if showChannelsControllers == false {
                    self.showChannels(animated: false, completion: completion)
                }
                self.show(channel: channel)
                self.channelObserver = nil
            })
            
            if showChannelsControllers {
                showChannels(animated: true, completion: completion)
            }
            return
        }
        showChannels(animated: false, completion: completion)
        show(channel: channel)
    }
}

extension ChatCoordinator: ChatCoordinatorDelegate {
    func show(channel: Channel) {
        let ctrl = ChatViewController(user: currentUser, channel: channel)
        ctrl.chatMessageDelegate = self.chatMessageDelegate
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

