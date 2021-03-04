//
//  File.swift
//  
//
//  Created by GG on 25/02/2021.
//

import Foundation
import FirebaseDatabase

public protocol ChatReadStateDelegate: NSObjectProtocol {
    func didupdateRead(_ data: ChatRead)
}

public struct ChatRead: Hashable, Equatable {
    public static func == (lhs: ChatRead, rhs: ChatRead) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
    let channelId: String
    let userId: String
    let count: Int
    let date: Date
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(channelId)
        hasher.combine(userId)
    }
}

public class ChatReadStateController {
    static let shared: ChatReadStateController = ChatReadStateController()
    private let db = Database.database(url: "https://ata-chauffeur-app-default-rtdb.europe-west1.firebasedatabase.app").reference()
//    private var handle: DatabaseHandle?
    private struct ChatHandler {
        let handle: DatabaseHandle
        weak var delegate: ChatReadStateDelegate!
    }
    private var handles: [String: ChatHandler] = [:]
    private init() {}
    private var unreadData: Set<ChatRead> = Set<ChatRead>()
    
    public func startListenning(for chatId: String, delegate: ChatReadStateDelegate) {
        var handle = handles[chatId]
        guard handle == nil || handle?.delegate !== delegate else { return }
        
        handle = ChatHandler(handle: db.child("messages").child(chatId).observe(DataEventType.value) { snap in
            let postDict = snap.value as? [String : AnyObject] ?? [:]
            print(postDict)
            postDict.forEach { [weak self] (key, value) in
                guard let dict = value as? [String : AnyObject],
                      let count = dict["value"] as? Int,
                      let timestamp: Double = dict["timestamp"] as? Double else {
                    return
                }
                // the timestamp contains 3 more digits than necessary
                let timeinterval = Double(Int(timestamp / 1000.0))
                let readData = ChatRead(channelId: key, userId: chatId, count: count, date: Date(timeIntervalSince1970: timeinterval))
                self?.unreadData.remove(readData)
                self?.unreadData.insert(readData)
                self?.handles
                    .filter({ $0.key == chatId })
                    .values
                    .compactMap({ $0.delegate })
                    .forEach({ $0.didupdateRead(readData) })
            }
        }, delegate: delegate)
        handles[chatId] = handle
    }
    
    func getUnreadCount(channelId: String, userId: String) -> Int? { unreadData.filter({ $0.channelId == channelId && $0.userId == userId }).first?.count }
    
    public func stopListenning(from delegate: ChatReadStateDelegate) {
        let keys = handles.filter({ $0.value.delegate === delegate }).keys
        keys.forEach({ handles.removeValue(forKey: $0) })
    }
    
    func resetUnreadCount(for userId: String,  channel: Channel) {
        guard let channelId = channel.id else { return }
        db.child("messages/\(userId)/\(channelId)/value").setValue(0)
    }
}
