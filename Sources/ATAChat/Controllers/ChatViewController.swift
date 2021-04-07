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
import Photos
import Firebase
import MessageKit
import FirebaseFirestore
import InputBarAccessoryView
import ATAConfiguration
import DateExtension
import NSAttributedStringBuilder
import SwiftDate
import StringExtension
import ColorExtension
import UIViewControllerExtension
import Lightbox

final class ChatViewController: MessagesViewController {
    var conf: ATAConfiguration = ChannelsViewController.conf
    
    private var isSendingPhoto = false {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.messageInputBar.leftStackViewItems.forEach { item in
                    (item as? InputBarButtonItem)?.isEnabled = !self.isSendingPhoto
                }
            }
        }
    }
    static var inputColor = UIColor(hexString: "767676")
    
    private let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter
        }()
    private let db = Firestore.firestore()
    private var reference: CollectionReference?
    private let storage = Storage.storage().reference()
    private var messages: [Message] = []
    private var messageListener: ListenerRegistration?
    private let user: ChatUser
    private let channel: Channel
    lazy var refreshControl = UIRefreshControl()
    public var showAvatars: Bool = true  {
        didSet {
            guard showAvatars == false else { return }
            if let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout {
              layout.setMessageIncomingAvatarSize(.zero)
              layout.setMessageOutgoingAvatarSize(.zero)
            }
        }
    }
    var avatars: [String: UIImage] = [:]
    // used for read/distributed for one to one discussions
    var lastReadDate: Date?
    
    
    deinit {
        print("💀 DEINIT \(URL(fileURLWithPath: #file).lastPathComponent)")
        messageListener?.remove()
        ChatReadStateController.shared.stopListenning(from: self)
    }
    
    init(user: ChatUser, channel: Channel) {
        self.user = user
        self.channel = channel
        super.init(nibName: nil, bundle: nil)
        title = channel.name
        if channel.users.count == 2 {
            listenForRead()
        }
        IQKeyboardManager.shared.enable = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func listenForRead() {
        guard let userId = channel.users.filter({ $0 != user.chatId }).first else { return }
        ChatReadStateController.shared.startListenning(for: userId, delegate: self)
    }
    
    func downloadAvatars() {
        self.avatars.removeAll()
        channel.users.forEach { [weak self] userId in
            guard let self = self else { return }
            self.db.collection("user").document(userId).getDocument(completion: { (snap, error) in
                let data = snap?.data()
                if let url = URL(string: data?["avatarUrl"] as? String ?? ""),
                   let data = try? Data(contentsOf: url) {
                    self.avatars[userId] = UIImage(data: data)
                }
                self.messagesCollectionView.reloadData()
            })
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        ChatReadStateController.shared.resetUnreadCount(for: user.chatId, channel: channel)
        IQKeyboardManager.shared.enable = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        refreshControl.tintColor = ChannelsViewController.conf.palette.primary
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        messagesCollectionView.refreshControl = refreshControl
        ChatReadStateController.shared.resetUnreadCount(for: user.chatId, channel: channel)
        //downloadAvatars()
        hideBackButtonText = true
        
        loadMessages()
        navigationItem.largeTitleDisplayMode = .never
        maintainPositionOnKeyboardFrameChanged = true
        configureInputBar()
        showMessageTimestampOnSwipeLeft = true
        messageInputBar.delegate = self
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
//        scrollsToLastItemOnKeyboardBeginsEditing = true
        
        guard showAvatars == false else { return }
        if let layout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout {
          layout.setMessageIncomingAvatarSize(.zero)
          layout.setMessageOutgoingAvatarSize(.zero)
        }
    }
    
    func configureInputBar() {
        messageInputBar.inputTextView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 36)
        messageInputBar.inputTextView.placeholderLabelInsets = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 36)
        messageInputBar.inputTextView.layer.borderWidth = 1.0
        messageInputBar.inputTextView.layer.cornerRadius = 16.0
        messageInputBar.inputTextView.layer.masksToBounds = true
        messageInputBar.inputTextView.scrollIndicatorInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        messageInputBar.setRightStackViewWidthConstant(to: 38, animated: false)
        messageInputBar.sendButton.contentEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        messageInputBar.sendButton.setSize(CGSize(width: 36, height: 36), animated: false)
        messageInputBar.sendButton.title = nil
        messageInputBar.sendButton.imageView?.layer.cornerRadius = 16
        messageInputBar.sendButton.backgroundColor = .clear
        messageInputBar.middleContentViewPadding.right = -38
        messageInputBar.separatorLine.isHidden = true
        messageInputBar.inputTextView.layer.borderColor = conf.palette.inactive.cgColor
        messageInputBar.inputTextView.placeholder = "message".local()
        messageInputBar.backgroundColor = ChannelsViewController.conf.palette.background
        messageInputBar.sendButton.tintColor = ChatViewController.inputColor
        messageInputBar.sendButton.onTextViewDidChange { [weak self] (button, textView) in
            button.tintColor = textView.text.isEmpty ? ChatViewController.inputColor : self?.conf.palette.primary
        }
        messageInputBar.sendButton.configure {
            $0.image = UIImage(systemName: "arrow.up.circle.fill", withConfiguration: UIImage.SymbolConfiguration.init(scale: .large))
            $0.title = nil
        }
        messageInputBar.inputTextView.tintColor = ChatViewController.inputColor
        messageInputBar.sendButton.setTitleColor(ChatViewController.inputColor, for: .normal)
        
        let cameraItem = InputBarButtonItem(type: .system) // 1
        cameraItem.tintColor = ChatViewController.inputColor
        cameraItem.image = #imageLiteral(resourceName: "camera")
        cameraItem.addTarget(
            self,
            action: #selector(cameraButtonPressed), // 2
            for: .primaryActionTriggered
        )
        cameraItem.setSize(CGSize(width: 60, height: 30), animated: false)
        
        messageInputBar.leftStackView.alignment = .center
        messageInputBar.setLeftStackViewWidthConstant(to: 50, animated: false)
        messageInputBar.setStackViewItems([cameraItem], forStack: .left, animated: false) // 3
    }
    
    func loadMessages() {
        guard let id = channel.id else {
            navigationController?.popViewController(animated: true)
            return
        }
        reference = db.collection(["messages", id, "messages"].joined(separator: "/"))
        refresh()
    }
    
    var nextQuery: Query?
    private static let documentLimit = 20
    @objc func refresh() {
        guard messageListener != nil else {
            messageListener = reference?
                .order(by: "sentAt", descending: true)
                .limit(to: ChatViewController.documentLimit)
                .addSnapshotListener { [weak self] querySnapshot, error in
                    guard let self = self else { return }
                    guard let snapshot = querySnapshot else {
                        print("Error listening for channel updates: \(error?.localizedDescription ?? "No error")")
                        return
                    }
                    self.handle(snapshot: snapshot)
                }
            return
        }
        
        nextQuery?.addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }
            guard let snapshot = querySnapshot else {
                print("Error listening for channel updates: \(error?.localizedDescription ?? "No error")")
                return
            }
            self.handle(snapshot: snapshot)
        }
    }
    
    func handle(snapshot: QuerySnapshot) {
        messagesCollectionView.refreshControl?.endRefreshing()
        snapshot.documentChanges.forEach { change in
            self.handleDocumentChange(change)
        }
        
        guard let lastSnapshot = snapshot.documents.last else {
            // The collection is empty.
            messagesCollectionView.refreshControl = nil
            return
        }
        nextQuery = self.reference?.order(by: "sentAt", descending: true).start(afterDocument: lastSnapshot).limit(to: ChatViewController.documentLimit)
    }
    
    // MARK: - Actions
    @objc private func cameraButtonPressed() {
        presentImagePickerChoice(delegate: self, tintColor: conf.palette.primary)
    }
    
    // MARK: - Helpers
    private func save(_ message: Message) {
        reference?.addDocument(data: message.representation) { [weak self] error in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
                return
            }
//            self?.scrollToBottom()
        }
    }
    
    private func scrollToBottom() {
        messagesCollectionView.scrollToLastItem(at: .top)
    }
    
    private func insertNewMessage(_ message: Message) {
        guard !messages.contains(message) else {
            return
        }
        
        messages.append(message)
        messages.sort()
        
//        let isLatestMessage = messages.firstIndex(of: message) == (messages.count - 1)
//        let shouldScrollToBottom = messagesCollectionView.isAtBottom && isLatestMessage
        
        messagesCollectionView.reloadData()
        
        DispatchQueue.main.async { [weak self] in
            self?.scrollToBottom()
        }
    }
    
    private func handleDocumentChange(_ change: DocumentChange) {
        guard var message = Message(document: change.document) else {
            return
        }
        
        switch change.type {
        case .added:
            if let url = message.downloadURL {
                downloadImage(at: url) { [weak self] image in
                    guard let self = self else { return }
                    guard let image = image else {
                        return
                    }
                    
                    message.image = image
                    self.insertNewMessage(message)
                    self.messagesCollectionView.scrollToLastItem()
                }
            } else {
                insertNewMessage(message)
            }
            
            // mark as read right away if one to one conversation
            // otherwise, it will b marked as read once when the controller is dismissed
            if message.sender.senderId != user.chatId, channel.users.count == 2 {
                ChatReadStateController.shared.resetUnreadCount(for: user.chatId, channel: channel)
            }
            
        default: ()
        }
    }
    
    private func uploadImage(_ image: UIImage, to channel: Channel, completion: @escaping (URL?) -> Void) {
        guard let channelID = channel.id else {
            completion(nil)
            return
        }
        
        guard let scaledImage = image.scaledToSafeUploadSize, let data = scaledImage.jpegData(compressionQuality: 0.4) else {
            completion(nil)
            return
        }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let imageName = [UUID().uuidString, String(Date().timeIntervalSince1970)].joined()
        storage.child(channelID).child(imageName).putData(data, metadata: metadata) { [weak self] meta, error in
            guard let path = meta?.path else {
                completion(nil)
                return
            }
            self?.getDownloadURL(from: path, completion: { url, error in
                guard let url = url else {
                    completion(nil)
                    return
                }
                completion(url)
            })
        }
    }
    
    // MARK: - GET DOWNLOAD URL
    private func getDownloadURL(from path: String, completion: @escaping (URL?, Error?) -> Void) {
        self.storage.child(path).downloadURL(completion: completion)
    }
    
    private func sendPhoto(_ image: UIImage) {
        guard isSendingPhoto == false else { return }
        isSendingPhoto = true
        
        uploadImage(image, to: channel) { [weak self] url in
            guard let self = self else {
                return
            }
            self.isSendingPhoto = false
            
            guard let url = url else {
                return
            }
            
            var message = Message(user: self.user, image: image)
            message.downloadURL = url
            self.save(message)
            self.messagesCollectionView.scrollToLastItem()
        }
    }
    
    private func downloadImage(at url: URL, completion: @escaping (UIImage?) -> Void) {
        let ref = Storage.storage().reference(forURL: url.absoluteString)
        let megaByte = Int64(1 * 1024 * 1024)
        
        ref.getData(maxSize: megaByte) { data, error in
            guard let imageData = data else {
                completion(nil)
                return
            }
            
            completion(UIImage(data: imageData))
        }
    }
}

extension ChatViewController: MessageCellDelegate {
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }
        let message = messages[indexPath.section]
        switch message.kind {
        case .photo(let item):
            var images: [LightboxImage] = []
            if let image = item.image {
                images.append(LightboxImage(image: image))
            }
            guard images.count == 1 else { return }
            LightboxConfig.CloseButton.text = "close".local()
            let controller = LightboxController(images: images)
            controller.dynamicBackground = true
            present(controller, animated: true, completion: nil)
            
        default: ()
        }
    }
}

// MARK: - MessagesDisplayDelegate

extension ChatViewController: MessagesDisplayDelegate {
    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        conf.palette.textOnPrimary
    }
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? conf.palette.primary : conf.palette.secondary
    }
    
    func shouldDisplayHeader(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> Bool {
        return false
    }
    
    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
//        guard indexPath.section == messages.count - 1 else { return .bubble }
        let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
        return .bubbleTail(corner, .pointedEdge)
    }
    
}

// MARK: - MessagesLayoutDelegate

extension ChatViewController: MessagesLayoutDelegate {
    
    func avatarSize(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize {
        return .zero
    }
    
    func footerViewSize(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize {
        return CGSize(width: 0, height: 8)
    }
    
    func heightForLocation(message: MessageType, at indexPath: IndexPath, with maxWidth: CGFloat, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 0
    }
    
}

// MARK: - MessagesDataSource

extension ChatViewController: MessagesDataSource {
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    func currentSender() -> SenderType {
        return Sender(senderId: user.chatId, displayName: user.displayName)
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        let date = message.sentDate
        guard let strDate: String = (date.isToday || date.isYesterday) ? DateFormatter.relativeDayFormatter.string(for: date)?.capitalized : DateFormatter.readableDateFormatter.string(for: date) else { return nil }
        return NSAttributedString{
            AText(strDate)
                .font(.applicationFont(forTextStyle: .caption1))
                .foregroundColor(conf.palette.secondaryTexts)
        }
    }
    
    func detectorAttributes(for detector: DetectorType, and message: MessageType, at indexPath: IndexPath) -> [NSAttributedString.Key: Any] {
        switch detector {
        case .hashtag, .mention: return [.foregroundColor: UIColor.blue]
        default: return MessageLabel.defaultAttributes
        }
    }
    
    func enabledDetectors(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> [DetectorType] {
        return [.url, .address, .phoneNumber, .date, .transitInformation, .mention, .hashtag]
    }
    
    func messageBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        // bottom message (read/distribited) only for 2 people conversation
        guard channel.users.count == 2 else { return nil }
        // no lable if the message is not from the current sender
        guard message.sender.senderId == user.chatId else { return nil }
        guard indexPath.section == messages.count - 1 else { return nil }
        let date = message.sentDate
        guard let lastReadDate = self.lastReadDate, lastReadDate > date else {
            return NSAttributedString {
                AText("distributed".bundleLocale())
                    .font(.applicationFont(forTextStyle: .caption2))
                    .foregroundColor(conf.palette.inactive)
            }
        }
        return NSAttributedString {
            AText(String(format: "read at".bundleLocale(), DateFormatter.relativeDateFormatter.string(for: lastReadDate) ?? ""))
                .font(.applicationFont(forTextStyle: .caption2))
                .foregroundColor(conf.palette.inactive)
        }
    }
    
    func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        // display only when the date changes
        guard indexPath.section > 0 else { return 18 }
        let previousDate = messages[indexPath.section - 1].sentDate
        return previousDate.isInside(date: message.sentDate, granularity: .day) ? 0 : 18
    }
    
    func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        // display only if there are more than 2 people in the channel
        guard channel.users.count > 2, indexPath.section > 0 else { return 0 }
        return 20
    }
    
    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        16
    }

    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        avatarView.isHidden = showAvatars == false
//        let avatar = SampleData.shared.getAvatarFor(sender: message.sender)
        avatarView.set(avatar: Avatar(image: avatars[message.sender.senderId],
                                      initials: message
                                        .sender
                                        .displayName
                                        .uppercased()
                                        .components(separatedBy: " ")
                                        .reduce("") { ($0 == "" ? "" : "\($0.first!)") + "\($1.first!)" }))
        avatarView.backgroundColor = conf.palette.inactive
        avatarView.placeholderTextColor = conf.palette.textOnPrimary
    }
    
    
//    func cellBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
//        return 17
//    }
    
//    func cellTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
//        if indexPath.section % 3 == 0 {
//            return NSAttributedString(string: MessageKitDateFormatter.shared.string(from: message.sentDate), attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 10), NSAttributedString.Key.foregroundColor: UIColor.darkGray])
//        }
//        return nil
//    }

//    func cellBottomLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
//        return NSAttributedString(string: "Read", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 10), NSAttributedString.Key.foregroundColor: UIColor.darkGray])
//    }

    func messageTopLabelAttributedText(for message: MessageType, at indexPath: IndexPath) -> NSAttributedString? {
        NSAttributedString{
            AText(message.sender.displayName)
                .font(.applicationFont(forTextStyle: .caption1))
                .foregroundColor(conf.palette.mainTexts)
        }
    }    
}

extension Sender {
    var color: UIColor {
        return UIColor(hexString: "\(displayName.hash)", defaultReturn: ChannelsViewController.conf.palette.secondary)
    }
}

// MARK: - MessageInputBarDelegate

extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        let message = Message(user: user, content: text)
        save(message)
        inputBar.inputTextView.text = ""
    }
}

// MARK: - UIImagePickerControllerDelegate

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        if let asset = info[.phAsset] as? PHAsset { // 1
            let size = CGSize(width: 1500, height: 1500)
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: nil) { [weak self] result, info in
                guard let image = result,
                      let info = info,
                      (info[PHImageResultIsDegradedKey] as? Int ?? Int.max) == 0 else {
                    return
                }
                
                self?.sendPhoto(image)
            }
        } else if let image = info[.originalImage] as? UIImage { // 2
            sendPhoto(image.scalePreservingAspectRatio(targetSize: CGSize(width: 1500, height: 1500)))
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

extension ChatViewController: ChatReadStateDelegate {
    func didupdateRead(_ data: ChatRead) {
        guard data.channelId == channel.id, data.count == 0 else { return }
        lastReadDate = data.date
        guard let lastMessage = messages.last,
              lastMessage.sender.senderId == user.chatId  else { return }
        messagesCollectionView.reloadItems(at: [IndexPath(row: 0, section: messages.count - 1)])
    }
}
