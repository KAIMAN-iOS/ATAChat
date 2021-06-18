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

import Firebase
import MessageKit
import FirebaseFirestore
import UIKit
import ImageExtension

public struct Sender: SenderType {
    public var senderId: String
    public var displayName: String
}

struct AvatarDisplay {
    var senderId: String
    var avatarUrl: URL?
}

extension CodableImage: MediaItem {
    public var url: URL? { self.imageURL }
    public var placeholderImage: UIImage { UIImage(named: "")!}
    public var size: CGSize { CGSize(width: 1200, height: 1200) }
}

public struct Message: MessageKit.MessageType {
    public var kind: MessageKind {
        if let image = image {
            return .photo(CodableImage(image))
        } else if let kind = customKind {
            return kind
        } else {
            return .text(content)
        }
    }
    public var customKind: MessageKind?
    public let id: String?
    public let content: String
    public let sentDate: Date
    public let sender: SenderType
    public var messageId: String {
        return id ?? UUID().uuidString
    }
    
    public var image: UIImage? = nil
    public var imageURL: URL? = nil
    public var linkURL: URL? = nil
    public var isTemporaryImage: Bool?
    
    public init(user: ChatUser, content: String) {
        sender = Sender(senderId: user.chatId, displayName: user.displayName)
        self.content = content
        sentDate = Date()
        id = nil
    }
    
    public init(user: ChatUser, image: UIImage) {
        sender = Sender(senderId: user.chatId, displayName: user.displayName)
        self.image = image
        content = ""
        sentDate = Date()
        id = nil
    }
    
    public init(id: String, senderId: String, displayName: String, content: String, linkURL: URL, sentDate: Date, customKind: MessageKind) {
        self.id = id
        self.sender = Sender(senderId: senderId, displayName: displayName)
        self.content = content
        self.linkURL = linkURL
        self.sentDate = sentDate
        self.customKind = customKind
    }
    
    public init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard let sentDate = data["sentAt"] as? Timestamp else {
            return nil
        }
        guard let senderID = data["sentBy"] as? String else {
            return nil
        }
        
        id = document.documentID
        self.sentDate = sentDate.dateValue()
        sender = Sender(senderId: senderID, displayName: data["senderName"] as? String ?? "unknown")
        
        if let content = data["text"] as? String {
            self.content = content
            imageURL = nil
        } else if let urlString = data["url"] as? String, let url = URL(string: urlString) {
            imageURL = url
            content = ""
        } else {
            return nil
        }
    }
    
}

extension Message: DatabaseRepresentation {
    
    var representation: [String : Any] {
        var rep: [String : Any] = [
            "sentAt": sentDate,
            "sentBy": sender.senderId,
            "senderName": sender.displayName
        ]
        
        if let url = imageURL {
            rep["url"] = url.absoluteString
        } else {
            rep["text"] = content
        }
        
        return rep
    }
    
}

extension Message: Comparable {
    
    public static func == (lhs: Message, rhs: Message) -> Bool {
        return lhs.id == rhs.id
    }
    
    public static func < (lhs: Message, rhs: Message) -> Bool {
        return lhs.sentDate < rhs.sentDate
    }
    
}
