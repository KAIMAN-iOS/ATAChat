//
//  File.swift
//  
//
//  Created by GG on 25/02/2021.
//

import Foundation
import FirebaseFirestore

class ChatReadStateController {
    static let shared: ChatReadStateController = ChatReadStateController()
    private let db = Firestore.firestore()
    private var channelReference: CollectionReference {
        return db.collection("group")
    }
    private var channelListener: ListenerRegistration?
    private init() {}
    
    public func startListenning(for chatId: String) {
        channelListener = channelReference
            .whereField("user", arrayContains: chatId)
            .addSnapshotListener { querySnapshot, error in
            guard let snapshot = querySnapshot else {
                print("Error listening for channel updates: \(error?.localizedDescription ?? "No error")")
                return
            }
            
            snapshot.documentChanges.forEach { change in
                self.handleDocumentChange(change)
            }
        }
    }
    
    public func stopListenning() {
        
    }
    
    private func handleDocumentChange(_ change: DocumentChange) {
        guard let channel = Channel(document: change.document) else {
            return
        }
        
        switch change.type {
        case .added: ()
        case .modified: ()
        case .removed: ()
        }
    }
}
