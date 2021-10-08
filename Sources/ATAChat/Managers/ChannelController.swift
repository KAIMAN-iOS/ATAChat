//
//  File.swift
//  
//
//  Created by Etienne Chambon on 08/10/2021.
//

import Foundation
import FirebaseFirestore
import ATACommonObjects


public class ChannelController {
    public static let shared: ChannelController = ChannelController()
    private let db = Firestore.firestore()
    private var channelReference: CollectionReference { db.collection("messages") }
    private var userReference: CollectionReference { db.collection("user") }

    private init() {}
    
    static var chanelNameDateFormatter: DateFormatter = {
        let form = DateFormatter()
        form.locale = .current
        form.dateStyle = .medium
        form.timeStyle = .short
        form.doesRelativeDateFormatting = false
        return form
    }()
    
    static var createdDateFormatter: DateFormatter = {
        let form = DateFormatter()
        form.locale = .current
        form.dateFormat = "yyyy-MM-dd HH:mm:ss"
        form.doesRelativeDateFormatting = false
        return form
    }()
    
    public func createRideChannel(ride: OngoingRide) {
        
        guard let driver = ride.driver else {
            return
        }
        guard let passenger = ride.passenger else {
            return
        }
//        userReference.whereField("id", isEqualTo: passenger.id).addSnapshotListener { (querySnapshot, error) in
//                    guard let documents = querySnapshot?.documents else {
//                        print("No documents")
//                        return
//                    }
//
//                    let users = documents.map { (queryDocumentSnapshot) -> ChatUserT in
//                        let docId = queryDocumentSnapshot.reference.documentID
//                        let data = queryDocumentSnapshot.data()
//                        let name = data["name"] as? String ?? ""
//                        let id = data["id"] as? Int ?? 0
//                        let chatUser: ChatUserT = ChatUserT(id: id, name: name)
//                        return chatUser
//                    }
//                    print(users)
//                }
        
        getChatIds(for: [driver.id, passenger.id]) { ids in
            guard let ids = ids else {
                return
            }
            guard let driverChatId = ids[driver.id], let passengerChatId = ids[passenger.id] else {
                return
            }
            let channelName = "Course du \(ChannelController.chanelNameDateFormatter.string(from: ride.ride.startDate.value))"
            let createdAt = ChannelController.createdDateFormatter.string(from: Date())
            let channelId = [driverChatId, "#", passengerChatId].joined()
            let data: [String:Any] = ["name": channelName, "user": [driverChatId, passengerChatId], "createdAt":createdAt]
            self.channelReference.document(channelId).setData(data)
        }
        
        
        
        //let data: [String:Any] = ["name": channelName, "user": [driver.chatId, passenger.chatId]]
        //channelReference.document([driver.chatId, "#", passenger.chatId].joined()).setData(data)
        
//        let tmp = userReference.whereField("id", arrayContains: "\(passenger.id)").getDocuments{a, b in
//            print(a)
//            print(b)
//        }
//        print(tmp)
    }
    
    private func getChatIds(for ids: [Int], completion: @escaping (([Int:String]?) -> Void)){
        //userReference.whereF
        userReference.whereField("id", in: ids).addSnapshotListener { (querySnapshot, error) in
            guard let documents = querySnapshot?.documents else {
                print("No documents")
                return completion(nil)
            }
            completion(documents.reduce(into: [Int:String](), {
                let docId = $1.reference.documentID
                let data = $1.data()
                let id = data["id"] as? Int ?? 0
                $0[id] = docId
            }))
//                documents.map { (queryDocumentSnapshot) -> [Int:String] in
//                let docId = queryDocumentSnapshot.reference.documentID
//                let data = queryDocumentSnapshot.data()
//                let id = data["id"] as? Int ?? 0
//                return [id:docId]
//            } )
        }
    }
}
