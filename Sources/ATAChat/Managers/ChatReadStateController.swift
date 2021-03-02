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
    
    public func addDelegate(_ delegate: ChatReadStateDelegate) {
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
        }
    }
    
    func getUnreadCount(for userId: String, channelId: String, completion: @escaping ((Int) -> Void)) {

    }
    
    public func stopListenning() {
        handle = nil
    }
}
