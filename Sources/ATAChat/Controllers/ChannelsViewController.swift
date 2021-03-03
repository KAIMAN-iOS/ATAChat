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
            case (.alert, .default): return true
            default: return false
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
    static var conf: ATAConfiguration!
    private let toolbarLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .applicationFont(forTextStyle: .body)
        return label
    }()
    
    private let channelCellIdentifier = "channelCell"
    private var currentChannelAlertController: UIAlertController?
    private let db = Firestore.firestore()
    private var channelReference: CollectionReference { db.collection("messages") }
    private var channelListener: ListenerRegistration?
//    private var channels = [Channel]()
    private let currentUser: ChatUser
    private let groups: [AlertGroupable]
    
    deinit {
        channelListener?.remove()
        ChatReadStateController.shared.stopListenning(from: self)
    }
    
    init(currentUser: ChatUser, groups: [AlertGroupable]) {
        self.currentUser = currentUser
        self.groups = groups
        super.init(style: .grouped)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Channels".bundleLocale()
        view.backgroundColor = .white
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        hideBackButtonText = true
        navigationController?.navigationBar.prefersLargeTitles = true
        clearsSelectionOnViewWillAppear = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: channelCellIdentifier)
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
    
    // MARK: - Helpers
    private func createChannel() {
        guard let ac = currentChannelAlertController else {
            return
        }
        
        guard let channelName = ac.textFields?.first?.text else {
            return
        }
        
        let channel = Channel(name: channelName)
        channelReference.addDocument(data: channel.representation) { error in
            if let e = error {
                print("Error saving channel: \(e.localizedDescription)")
            }
        }
    }
    
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
        update(cellType, with: channels)
        tableView.deleteRows(at: [IndexPath(row: index, section: cellTypes.firstIndex(of: cellType) ?? 0)], with: .automatic)
    }
    
    private func handleDocumentChange(_ change: DocumentChange) {
        guard var channel = Channel(document: change.document) else {
            return
        }
        channel.isAlertGroup = groups.compactMap({ $0.groupId }).contains(channel.id)
        channel.unreadCount = ChatReadStateController.shared.getUnreadCount(channelId: channel.id ?? "") ?? 0
        
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
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 55
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let index = cellTypes.firstIndex(of: .alert([])), section == index else { return 0 }
        return 44
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: channelCellIdentifier, for: indexPath)
        let channel = cellTypes[indexPath.section].channels[indexPath.row]
        cell.accessoryType = .disclosureIndicator
        cell.textLabel?.set(text: channel.name,
                            for: .body,
                            textColor: ChannelsViewController.conf.palette.mainTexts)
        cell.textLabel?.font = .applicationFont(forTextStyle: .callout)
        cell.addDefaultSelectedBackground(ChannelsViewController.conf.palette.primary.withAlphaComponent(0.3))
        
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
        let vc = ChatViewController(user: currentUser, channel: channel)
        navigationController?.pushViewController(vc, animated: true)
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
            make.bottom.equalToSuperview().offset(8)
            make.trailingMargin.equalToSuperview()
        }
        return view
    }
}

extension ChannelsViewController: ChatReadStateDelegate {
    func didupdate(readCount: Int, for channelId: String) {
        guard var channel = cellTypes.flatMap({ $0.channels }).filter({ $0.id == channelId }).first else { return }
        channel.update(readCount)
        updateChannelInTable(channel)
    }
}
