//
//  File.swift
//  
//
//  Created by GG on 25/02/2021.
//

import Foundation
import FirebaseDatabase

protocol ChatReadStateDelegate: NSObjectProtocol {
    func didupdate(readCount: Int, for channelId: String)
}

class ChatReadStateController {
    static let shared: ChatReadStateController = ChatReadStateController()
    private let db = Database.database(url: "https://ata-chauffeur-app-default-rtdb.europe-west1.firebasedatabase.app").reference()
    private var handle: DatabaseHandle?
    private init() {}
    private var delegates: [ChatReadStateDelegate] = []
    private var unreadCount: [String: Int] = [:]
    
    public func addDelegate(_ delegate: ChatReadStateDelegate) {
        guard delegates.contains(where: { $0 === delegate }) == false else { return }
        delegates.append(delegate)
    }
    public func removeDelegate(_ delegate: ChatReadStateDelegate) {
        delegates.removeAll(where: { $0 === delegate})
    }
    
    public func startListenning(for chatId: String, delegate: ChatReadStateDelegate) {
        addDelegate(delegate)
        handle = db.child("messages").child(chatId).observe(DataEventType.value) { snap in
            let postDict = snap.value as? [String : AnyObject] ?? [:]
            print(postDict)
            postDict.forEach { [weak self] (key, value) in
                guard let dict = value as? [String : AnyObject],
                      let count = dict["value"] as? Int else {
                    return
                }
                self?.unreadCount[key] = count
                self?.delegates.forEach({ $0.didupdate(readCount: count, for: key) })
            }
        }
    }
    
    func getUnreadCount(channelId: String) -> Int? { unreadCount[channelId] }
    
    public func stopListenning() {
        handle = nil
    }
}
