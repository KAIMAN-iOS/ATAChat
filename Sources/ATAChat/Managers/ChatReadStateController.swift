//
//  File.swift
//  
//
//  Created by GG on 25/02/2021.
//

import Foundation
import FirebaseFirestore

protocol ChatReadStateDelegate: NSObjectProtocol {
    func didupdate(readCount: Int, for channelId: String)
}

class ChatReadStateController {
    static let shared: ChatReadStateController = ChatReadStateController()
    private let db = Firestore.firestore()
    private var channelReference: CollectionReference {
        return db.collection("unreadCount")
    }
    private var channelListener: ListenerRegistration?
    private init() {}
    private var delegates: [ChatReadStateDelegate] = []
    
    public func addDelegate(_ delegate: ChatReadStateDelegate) {
        delegates.append(delegate)
    }
    public func removeDelegate(_ delegate: ChatReadStateDelegate) {
        delegates.removeAll(where: { $0 === delegate})
    }
    
    public func startListenning(for chatId: String) {
        channelListener = db.collection(["unreadCount", chatId, "groups"].joined(separator: "/"))
            //        channelListener = channelReference
            .addSnapshotListener(includeMetadataChanges: true) { querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    print("Error listening for channel updates: \(error?.localizedDescription ?? "No error")")
                    return
                }
                
                snapshot.documents.forEach { [weak self] doc in
                    let data = doc.data()
                    guard let groupId = data["groupId"] as? String,
                          let count = data["unreadCount"] as? Int else {
                        return
                    }
                    self?.delegates.forEach({ $0.didupdate(readCount: count, for: groupId) })
                }
            }
    }
    
    func getUnreadCount(for userId: String, channelId: String, completion: @escaping ((Int) -> Void)) {
//        db.collection(["unreadCount", userId, "groups"].joined(separator: "/"))
    }
    
    public func stopListenning() {
        channelListener?.remove()
        channelListener = nil
    }
}
