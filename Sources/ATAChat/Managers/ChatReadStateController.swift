//
//  File.swift
//  
//
//  Created by GG on 25/02/2021.
//

import Foundation
import FirebaseDatabase
import Combine

public protocol ChatReadStateDelegate: NSObjectProtocol {
    func didupdateRead(_ data: ChatRead)
}

public struct ChatRead: Hashable, Equatable, CustomDebugStringConvertible {
    public static func == (lhs: ChatRead, rhs: ChatRead) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
    public let channelId: String
    public let userId: String
    public let count: Int
    let date: Date
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(channelId)
        hasher.combine(userId)
    }
    
    public var debugDescription: String { "ChatRead <\(channelId)> - <\(count)>" }
}

public class ChatReadStateController {
    public static let shared: ChatReadStateController = ChatReadStateController()
    private let db = Database.database(url: "https://ata-chauffeur-app-default-rtdb.europe-west1.firebasedatabase.app").reference()
    private var handler: DatabaseHandle!
    private var child: DatabaseReference!
    private var uncountSubject: CurrentValueSubject<Set<ChatRead>, Never> = CurrentValueSubject<Set<ChatRead>, Never>(Set<ChatRead>())
    private var totalcountSubject: CurrentValueSubject<Int, Never> = CurrentValueSubject<Int, Never>(0)
    private init() {}
    
    private func loadRef(for chatId: String) {
        if child == nil  {
            child = db.child("messages").child(chatId)
            handler = child.observe(DataEventType.value) { snap in
                print("🙀 unreadCount changed")
                let postDict = snap.value as? [String : AnyObject] ?? [:]
                print(postDict)
                var set = Set<ChatRead>()
                postDict.forEach { (key, value) in
                    guard let dict = value as? [String : AnyObject],
                          let count = dict["value"] as? Int,
                          let timestamp: Double = dict["timestamp"] as? Double else {
                        return
                    }
                    // the timestamp contains 3 more digits than necessary
                    let timeinterval = Double(Int(timestamp / 1000.0))
                    let readData = ChatRead(channelId: key, userId: chatId, count: count, date: Date(timeIntervalSince1970: timeinterval))
                    print("🙀 readData \(readData)")
                    set.insert(readData)
                }
                let previousValue = self.uncountSubject.value.compactMap({ $0.count }).reduce(0, +)
                self.uncountSubject.send(set)
                let currentValue = self.uncountSubject.value.compactMap({ $0.count }).reduce(0, +)
                // do not send if the same as before
                if currentValue != previousValue {
                    self.totalcountSubject.send(currentValue)
                }
            }
        }
    }
    
    public func reset() {
        handler = nil
        child = nil
    }
    
    public func startListenning(for chatId: String) -> AnyPublisher<Set<ChatRead>, Never> {
        loadRef(for: chatId)
        return uncountSubject
            .share()
            .eraseToAnyPublisher()
    }
    
    public func startListenningForTotal(for chatId: String) -> AnyPublisher<Int, Never> {
        loadRef(for: chatId)
        return totalcountSubject
            .share()
            .eraseToAnyPublisher()
    }
    
    public func startListenning(for chatId: String, channelId: String) -> AnyPublisher<ChatRead, Never> {
        loadRef(for: chatId)
        return uncountSubject
            .compactMap({ $0.first(where: { $0.channelId == channelId && $0.userId == chatId }) })
            .share()
            .eraseToAnyPublisher()
    }
    
    func getUnreadCount(channelId: String, userId: String) -> Int? { uncountSubject.value.filter({ $0.channelId == channelId && $0.userId == userId }).first?.count }
    public func getTotalUnreadCount() -> Int { uncountSubject.value.compactMap({ $0.count }).reduce(0, +) }
    
    func resetUnreadCount(for userId: String,  channel: Channel) {
        guard let channelId = channel.id else { return }
        db.child("messages/\(userId)/\(channelId)/value").setValue(0)
    }
}
