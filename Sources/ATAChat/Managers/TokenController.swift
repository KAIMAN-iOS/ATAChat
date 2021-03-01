//
//  File.swift
//  
//
//  Created by GG on 01/03/2021.
//

import Foundation
import FirebaseFirestore

public struct TokenController {
    static private let db = Firestore.firestore()
    static private var userReference: CollectionReference { db.collection("user") }
    public static func update(token: String, for userId: String) {
        userReference.document(userId).updateData(["notificationTokens" : FieldValue.arrayUnion([token])])
    }
}
