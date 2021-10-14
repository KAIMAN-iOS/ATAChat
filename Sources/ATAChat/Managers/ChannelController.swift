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
        form.dateStyle = .short
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
    
    public func createRideChannel(for ride: OngoingRide) {
        
        guard let driver = ride.driver, let passenger = ride.passenger else {
            return
        }
        
        guard driver.chatId.isEmpty == false, passenger.chatId.isEmpty == false else {
            getChatIds(for: [driver.id, passenger.id]) { [weak self] ids in
                guard let ids = ids else {
                    return
                }
                guard let driverChatId = ids[driver.id], let passengerChatId = ids[passenger.id] else {
                    return
                }
                self?.createRideChannel(for: ride, driverChatId: driverChatId, passengerChatId: passengerChatId)
            }
            return
        }
        createRideChannel(for: ride, driverChatId: driver.chatId, passengerChatId: passenger.chatId)
    }
    
    private func createRideChannel(for ride: OngoingRide, driverChatId: String, passengerChatId: String){
        let channelName = "%name% - Course du \(ChannelController.chanelNameDateFormatter.string(from: ride.ride.startDate.value))"
        let createdAt = ChannelController.createdDateFormatter.string(from: Date())
        let channelId = "\(Ride.rideChannelPrefix)\(ride.ride.id)"
        let data: [String:Any] = ["name": channelName, "user": [driverChatId, passengerChatId], "createdAt": createdAt, "driverName": ride.driver?.shortDisplayName ?? "", "passengerName": ride.passenger?.shortDisplayName ?? ""]
        self.channelReference.document(channelId).setData(data)
    }
    
    public func deleteRideChannel(for rideId: Int) {
        channelReference.document("\(Ride.rideChannelPrefix)\(rideId)").delete()
    }
    
    private func getChatIds(for userIds: [Int], completion: @escaping (([Int:String]?) -> Void)) {
        userReference.whereField("id", in: userIds).addSnapshotListener { (querySnapshot, error) in
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
        }
    }
}
