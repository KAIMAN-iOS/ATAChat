/// Copyright (c) 2018 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import FirebaseFirestore
import FirebaseAuth
import ATAConfiguration
import Ampersand
import UIViewControllerExtension
import SnapKit
import LabelExtension
import TableViewExtension
import EasyNotificationBadge
import Lottie
import UIViewExtension
import Combine
import ATACommonObjects
import PromiseKit

extension Mode {
    var noChannelTitle: String {
        switch self {
        case .driver: return "no channel".bundleLocale()
        case .passenger: return "no channel passenger".bundleLocale()
        }
    }
}

public protocol AlertGroupable {
    var groupId: String { get }
    var groupTypeId: Int { get }
}

public protocol AlertGroupTypable {
    var groupTypeId: Int { get }
    var groupTypeName: String { get }
    var groupSortIndex: Int { get }
}

public protocol ChatUser {
    var chatId: String { get }
    var displayName: String { get }
}

protocol Channelable {
    var id: String? { get }
    var name: String { get }
}

class ChannelsViewController: UITableViewController {
    var mode: Mode!
    class Section: NSObject, Comparable {
        static func == (lhs: Section, rhs: Section) -> Bool { lhs.groupTypeName == rhs.groupTypeName }
        override func isEqual(_ object: Any?) -> Bool {
            guard let rhs = object as? Section else { return false }
            return rhs.groupTypeName == groupTypeName
        }
        static func < (lhs: Section, rhs: Section) -> Bool { lhs.sortIndex < rhs.sortIndex }
        var channels: [Channel] = []
        var groupTypeName: String
        var sortIndex: Int
        
        init(channels: [Channel] = [],
             groupTypeName: String, sortIndex: Int) {
            self.channels = channels
            self.groupTypeName = groupTypeName
            self.sortIndex = sortIndex
        }
    }
    var sections: [Section] = []
    @objc dynamic var channels: [Channel] = []
    static var conf: ATAConfiguration!
    private let toolbarLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .applicationFont(forTextStyle: .body)
        return label
    }()
    weak var coordinatorDelegate: ChatCoordinatorDelegate!
    private static let channelCellIdentifier = "channelCell"
    private var currentChannelAlertController: UIAlertController?
    private let db = Firestore.firestore()
    private var channelReference: CollectionReference { db.collection("messages") }
    private var channelListener: ListenerRegistration?
//    private var channels = [Channel]()
    private var currentUser: ChatUser!
    private var groups: [AlertGroupable] = []
    private var groupTypes: [AlertGroupTypable] = []
    private var noChannelAnimation: Animation!
    private var emojiAnimation: Animation!
    private var subscriptions = Set<AnyCancellable>()
    
    deinit {
        print("💀 DEINIT \(URL(fileURLWithPath: #file).lastPathComponent)")
        channelListener?.remove()
    }
    
    static func create(currentUser: ChatUser,
                       groups: [AlertGroupable],
                       groupTypes: [AlertGroupTypable],
                       mode: Mode = .driver,
                       coordinatorDelegate: ChatCoordinatorDelegate,
                       emojiAnimation: Animation,
                       noChannelAnimation: Animation) -> ChannelsViewController {
        let ctrl: ChannelsViewController = UIStoryboard(name: "ATAChat", bundle: Bundle.module).instantiateViewController(identifier: "ChannelsViewController") as! ChannelsViewController
        ctrl.currentUser = currentUser
        ctrl.mode = mode
        ctrl.groups = groups
        ctrl.groupTypes = groupTypes
        ctrl.coordinatorDelegate = coordinatorDelegate
        ctrl.emojiAnimation = emojiAnimation
        ctrl.noChannelAnimation = noChannelAnimation
        ctrl.tableView.separatorStyle = .none
        ctrl.clearsSelectionOnViewWillAppear = true
        return ctrl
    }
    
    func startListenning() {
        guard channelListener == nil, currentUser.chatId.isEmpty == false else { return }
        channelListener = channelReference
            .whereField("user", arrayContains: currentUser.chatId)
            .addSnapshotListener { querySnapshot, error in
            guard let snapshot = querySnapshot else {
                print("Error listening for channel updates: \(error?.localizedDescription ?? "No error")")
                return
            }
            
            snapshot.documentChanges.forEach { [weak self] change in
                self?.handleDocumentChange(change)
            }
        }
        
        ChatReadStateController
            .shared
            .startListenning(for: currentUser.chatId)
            .receive(on: DispatchQueue.main)
            .sink { unreads in
                unreads.forEach { [weak self] unread in
                    self?.updateRead(unread)
                }
            }
            .store(in: &subscriptions)
    }
    
    private func updateRead(_ data: ChatRead) {
        guard let channel = sections.flatMap({ $0.channels }).filter({ $0.id == data.channelId }).first else { return }
        channel.update(data.count)
        updateChannelInTable(channel)
    }
    
    func stopListenning() {
        channelListener?.remove()
    }
    
    var emojiAnimationView: AnimationView?
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ChannelsViewController.conf.palette.background
        tableView.backgroundColor = ChannelsViewController.conf.palette.background
        navigationController?.navigationBar.prefersLargeTitles = true
        title = "Channels".bundleLocale()
        hideBackButtonText = true
        emojiAnimationView = AnimationView(animation: emojiAnimation)
        tableView.estimatedRowHeight = 45
        tableView.rowHeight = UITableView.automaticDimension
    }
    
    var noChannelAnimationView: AnimationView?
    var noChannelContainer: UIStackView!
    private func loadNoChannelView() {
        noChannelAnimationView = AnimationView(animation: noChannelAnimation)
        if let animationView = noChannelAnimationView {
            noChannelContainer = UIStackView()
            noChannelContainer.axis = .vertical
            noChannelContainer.spacing = 20
            noChannelContainer.distribution = .fill
            noChannelContainer.addArrangedSubview(animationView)
            let label = UILabel()
            label.backgroundColor = .clear
            label.numberOfLines = 0
            label.textAlignment = .center
            label.set(text: mode.noChannelTitle.uppercased(), for: .callout, textColor: ChannelsViewController.conf.palette.inactive)
            noChannelContainer.addArrangedSubview(label)
            animationView.snp.makeConstraints {
                $0.height.equalTo(100)
            }
            tableView.addSubview(noChannelContainer)
            noChannelContainer.snp.makeConstraints {
                $0.centerX.equalToSuperview()
                $0.leftMargin.rightMargin.equalToSuperview()
                $0.top.equalToSuperview().offset(view.bounds.midY / 2.0)
            }
            animationView.loopMode = .loop
            animationView.play { _ in }
            animationView.alpha = 0.8
        }
    }
    
    private func loadEmojiView() {
        if let animationView = emojiAnimationView {
            tableView.addSubview(animationView)
            animationView.snp.makeConstraints({
                $0.edges.equalToSuperview()
                $0.height.width.equalToSuperview()
            })
            animationView.contentMode = .scaleAspectFit
            animationView.translatesAutoresizingMaskIntoConstraints = false
            animationView.isUserInteractionEnabled = false
            view.bringSubviewToFront(animationView)

            animationView.play(completion: { [weak self] success in
                self?.emojiAnimationView?.removeFromSuperview()
                self?.emojiAnimationView = nil
            })
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if sections.isEmpty {
            loadNoChannelView()
        } else if emojiAnimationView != nil {
            loadEmojiView()
        }
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.shadowImage = UIImage()
        super.viewWillAppear(animated)
        startListenning()
    }
    
    // MARK: - Helpers
    func section(for groupType: AlertGroupTypable?) -> Section? {
        guard let groupType = groupType else {
            return nil
        }
        guard let section = sections.first(where: { $0.groupTypeName == groupType.groupTypeName }) else {
            let section = Section(groupTypeName: groupType.groupTypeName, sortIndex: groupType.groupSortIndex)
            sections.append(section)
            sections.sort()
            return section
        }
        return section
    }
    func section(for channel: Channel) -> Section? {
        if (channel.id ?? "").contains(Ride.rideChannelPrefix) {
            return section(for: groupTypes.first(where: { $0.groupTypeName == Ride.rideChannelPrefix }))
        }
        if (channel.id ?? "").contains(Ride.webChannelPrefix) {
            return section(for: groupTypes.first(where: { $0.groupTypeName == Ride.webChannelPrefix }))
        }
        guard let group = groups.first(where: { $0.groupId == channel.id }),
              let groupType = groupTypes.first(where: { $0.groupTypeId == group.groupTypeId }) else { return nil }
        return section(for: groupType)
    }
    
    func isEmptyChannel(for channel: Channel) -> Promise<Bool> {
        return Promise<Bool> { resolver in
            db.collection(["messages", channel.id ?? "", "messages"].joined(separator: "/")).getDocuments(completion: { docs, error in
                if docs?.isEmpty == false {
                    resolver.fulfill(false)
                } else {
                    resolver.fulfill(true)
                }
            })
        }
    }
    
    private func addChannelToTable(_ channel: Channel) {
        if (channel.id ?? "").contains(Ride.webChannelPrefix) {
            isEmptyChannel(for: channel).done({ [weak self] result in
                guard let self = self else { return }
                if result == false {
                    guard let section = self.section(for: channel) else { return }
                    guard !section.channels.contains(channel) else {
                        return
                    }
                    section.channels.append(channel)
                    guard !self.channels.contains(channel) else {
                        return
                    }
                    self.channels.append(channel)
                    section.channels.sort()
                    guard section.channels.firstIndex(of: channel) != nil else {
                        return
                    }
                    self.tableView.reloadData()
                }
            })
        } else {
            guard let section = self.section(for: channel) else { return }
            guard !section.channels.contains(channel) else {
                return
            }
            section.channels.append(channel)
            guard !channels.contains(channel) else {
                return
            }
            channels.append(channel)
            section.channels.sort()
            guard section.channels.firstIndex(of: channel) != nil else {
                return
            }
            tableView.reloadData()
        }
    }
    
    private func updateChannelInTable(_ channel: Channel) {
        guard let section = self.section(for: channel) else { return }
        guard let index = section.channels.firstIndex(of: channel) else {
            return
        }
        section.channels[index] = channel
//        tableView.reloadRows(at: [IndexPath(row: index, section: cellTypes.firstIndex(of: cellType) ?? 0)], with: .automatic)
        tableView.reloadData()
    }
    
    private func removeChannelFromTable(_ channel: Channel) {
        guard let section = self.section(for: channel) else { return }
        guard let index = section.channels.firstIndex(of: channel) else {
            return
        }
        section.channels.remove(at: index)
        tableView.deleteRows(at: [IndexPath(row: index, section: sections.firstIndex(of: section) ?? 0)], with: .automatic)
    }
    
    private func handleDocumentChange(_ change: DocumentChange) {
        guard let channel = Channel(document: change.document) else {
            return
        }
        noChannelContainer?.isHidden = true
        if sections.count == 0 {
            loadEmojiView()
        }
//        channel.isAlertGroup = groups.filter({ $0.isAlertGroup }).compactMap({ $0.groupId }).contains(channel.id)
        channel.unreadCount = ChatReadStateController.shared.getUnreadCount(channelId: channel.id ?? "", userId: currentUser.chatId) ?? 0
        
        switch change.type {
        case .added:
            addChannelToTable(channel)
            
        case .modified:
            updateChannelInTable(channel)
            
        case .removed:
            removeChannelFromTable(channel)
        }
    }
}

// MARK: - TableViewDelegate

extension ChannelsViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].channels.count
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
//        guard let index = cellTypes.firstIndex(of: .alert([])), section == index else { return 0 }
        return 64
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell: ChannelCell = tableView.automaticallyDequeueReusableCell(forIndexPath: indexPath) else {
            return UITableViewCell()
        }
        let channel = sections[indexPath.section].channels[indexPath.row]
        cell.configure(channel, for: mode)
        cell.textLabel?.font = .applicationFont(forTextStyle: .callout)
        cell.updateUnreadCount(channel.unreadCount)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let channel = sections[indexPath.section].channels[indexPath.row]
        coordinatorDelegate.show(channel: channel)
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//        guard let index = cellTypes.firstIndex(of: .alert([])), section == index else { return nil }
        let view = UIView()
        view.backgroundColor = ChannelsViewController.conf.palette.background
        let label = UILabel()
        var grpTypeName = sections[section].groupTypeName
        if grpTypeName.contains(Ride.rideChannelPrefix) {
            grpTypeName = Channel.rideChannelGroupTypeName(for: mode)
        }
        if grpTypeName.contains(Ride.webChannelPrefix) {
            grpTypeName = Channel.webChannelGroupTypeName
        }
        label.set(text: grpTypeName.capitalized, for: .headline, traits: [.traitBold], textColor: ChannelsViewController.conf.palette.mainTexts)
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(18)
            make.top.equalToSuperview().offset(12)
            make.bottom.equalToSuperview().offset(16)
            make.trailingMargin.equalToSuperview()
        }
        let separator = UIView()
        separator.backgroundColor = ChannelsViewController.conf.palette.lightGray
        view.addSubview(separator)
        separator.snp.makeConstraints {
            $0.bottom.equalToSuperview()
            $0.left.equalToSuperview().offset(16)
            $0.right.equalToSuperview().inset(16)
            $0.height.equalTo(1)
        }
        return view
    }
}
