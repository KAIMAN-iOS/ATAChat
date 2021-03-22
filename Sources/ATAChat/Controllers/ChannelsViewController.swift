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

public protocol AlertGroupable {
    var isAlertGroup: Bool { get }
    var groupId: String { get }
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
    enum CellType: Equatable, Comparable {
        static func == (lhs: CellType, rhs: CellType) -> Bool {
            switch (lhs, rhs) {
            case (.alert, .alert): return true
            case (.default, .default): return true
            default: return false
            }
        }
        static func < (lhs: CellType, rhs: CellType) -> Bool {
            switch (lhs, rhs) {
            case (.alert, .default): return false
            default: return true
            }
        }
        
        case alert(_: [Channel])
        case `default`(_: [Channel])
        
        var channels: [Channel] {
            switch self {
            case .alert(let channels): return channels
            case .default(let channels): return channels
            }
        }
    }
    var cellTypes: [CellType] = []
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
    private var noChannelAnimation: Animation!
    private var emojiAnimation: Animation!
    
    deinit {
        print("💀 DEINIT \(URL(fileURLWithPath: #file).lastPathComponent)")
        channelListener?.remove()
        ChatReadStateController.shared.stopListenning(from: self)
    }
    
    static func create(currentUser: ChatUser,
                       groups: [AlertGroupable],
                       coordinatorDelegate: ChatCoordinatorDelegate,
                       emojiAnimation: Animation,
                       noChannelAnimation: Animation) -> ChannelsViewController {
        let ctrl: ChannelsViewController = UIStoryboard(name: "ATAChat", bundle: Bundle.module).instantiateViewController(identifier: "ChannelsViewController") as! ChannelsViewController
        ctrl.currentUser = currentUser
        ctrl.groups = groups
        ctrl.coordinatorDelegate = coordinatorDelegate
        ctrl.emojiAnimation = emojiAnimation
        ctrl.noChannelAnimation = noChannelAnimation
        ctrl.tableView.separatorStyle = .none
        ctrl.clearsSelectionOnViewWillAppear = true
        return ctrl
    }
    
    func startListenning() {
        guard channelListener == nil else { return }
        channelListener = channelReference
            .whereField("user", arrayContains: currentUser.chatId)
            .addSnapshotListener { querySnapshot, error in
            guard let snapshot = querySnapshot else {
                print("Error listening for channel updates: \(error?.localizedDescription ?? "No error")")
                return
            }
            
            snapshot.documentChanges.forEach { change in
                self.handleDocumentChange(change)
            }
        }
        ChatReadStateController.shared.startListenning(for: currentUser.chatId, delegate: self)
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
            label.set(text: "no channel".bundleLocale().uppercased(), for: .callout, textColor: ChannelsViewController.conf.palette.inactive)
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
        if channels.isEmpty {
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
    func cellType(for channel: Channel) -> CellType {
        var cellType: CellType? = cellTypes.filter({ $0 == (channel.isAlertGroup ? CellType.alert([]) : CellType.default([])) }).first
        if cellType == nil {
            cellType = channel.isAlertGroup ? CellType.alert([]) : CellType.default([])
        }
        return cellType!
    }
    
    func update(_ cellType: CellType, with channels: [Channel]) {
        switch cellType {
        case .alert:
            cellTypes.removeAll(where: { $0 == CellType.alert([]) })
            cellTypes.append(CellType.alert(channels.sorted()))
            
        case .default:
            cellTypes.removeAll(where: { $0 == CellType.default([]) })
            cellTypes.append(CellType.default(channels.sorted()))
        }
        cellTypes.sort()
    }
    
    private func addChannelToTable(_ channel: Channel) {
        let cellType = self.cellType(for: channel)
        var channels = cellType.channels
        guard !channels.contains(channel) else {
            return
        }
        channels.append(channel)
        self.channels.append(channel)
        update(cellType, with: channels)
        
        guard channels.firstIndex(of: channel) != nil else {
            return
        }
        tableView.reloadData()
    }
    
    private func updateChannelInTable(_ channel: Channel) {
        let cellType = self.cellType(for: channel)
        var channels = cellType.channels
        guard let index = channels.firstIndex(of: channel) else {
            return
        }
        channels[index] = channel
        self.channels.removeAll(where: { $0 == channel })
        self.channels.append(channel)
        update(cellType, with: channels)
        tableView.reloadRows(at: [IndexPath(row: index, section: cellTypes.firstIndex(of: cellType) ?? 0)], with: .automatic)
    }
    
    private func removeChannelFromTable(_ channel: Channel) {
        let cellType = self.cellType(for: channel)
        var channels = cellType.channels
        guard let index = channels.firstIndex(of: channel) else {
            return
        }
        channels.remove(at: index)
        self.channels.removeAll(where: { $0 == channel })
        update(cellType, with: channels)
        tableView.deleteRows(at: [IndexPath(row: index, section: cellTypes.firstIndex(of: cellType) ?? 0)], with: .automatic)
    }
    
    private func handleDocumentChange(_ change: DocumentChange) {
        guard let channel = Channel(document: change.document) else {
            return
        }
        noChannelContainer?.isHidden = true
        if channels.count == 0 {
            loadEmojiView()
        }
        channel.isAlertGroup = groups.compactMap({ $0.groupId }).contains(channel.id)
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
        return cellTypes.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellTypes[section].channels.count
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let index = cellTypes.firstIndex(of: .alert([])), section == index else { return 0 }
        return 64
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell: ChannelCell = tableView.automaticallyDequeueReusableCell(forIndexPath: indexPath) else {
            return UITableViewCell()
        }
        let channel = cellTypes[indexPath.section].channels[indexPath.row]
        cell.configure(channel)
        cell.textLabel?.font = .applicationFont(forTextStyle: .callout)
        
        if channel.unreadCount > 0 {
            cell.imageView?.image = UIImage()
            cell.imageView?.badge(text: "\(channel.unreadCount)", appearance: BadgeAppearance(font: .applicationFont(forTextStyle: .caption1),
                                                                                   backgroundColor: ChannelsViewController.conf.palette.primary,
                                                                                   textColor: ChannelsViewController.conf.palette.textOnPrimary,
                                                                                   animate: true))
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let channel = cellTypes[indexPath.section].channels[indexPath.row]
        coordinatorDelegate.show(channel: channel)
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let index = cellTypes.firstIndex(of: .alert([])), section == index else { return nil }
        let view = UIView()
        let label = UILabel()
        label.set(text: "Alert".bundleLocale().uppercased(), for: .subheadline, textColor: ChannelsViewController.conf.palette.mainTexts)
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
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

extension ChannelsViewController: ChatReadStateDelegate {
    func didupdateRead(_ data: ChatRead) {
        guard let channel = cellTypes.flatMap({ $0.channels }).filter({ $0.id == data.channelId }).first else { return }
        channel.update(data.count)
        updateChannelInTable(channel)
    }
}
