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

import FirebaseFirestore

@objc public class Channel: NSObject {
    public let id: String?
    let name: String
    let users: [String]
    var unreadCount: Int = 0
    let driverName: String
    let passengerName: String
    
    public static func rideChannelGroupTypeName(for mode: Mode) -> String {
        switch mode {
        case .passenger: return "passengerRideChannelsTitle".bundleLocale()
        case .driver: return "driverRideChannelsTitle".bundleLocale()
        }
    }
//    var isAlertGroup: Bool = false
    
    func update(_ unread: Int) {
        unreadCount = unread
    }
    
    init(name: String) {
        id = nil
        self.name = name
        self.users = []
        self.driverName = ""
        self.passengerName = ""
    }
    
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard let name = data["name"] as? String else {
            return nil
        }
        
        id = document.documentID
        self.name = name
        self.users = data["user"] as? [String] ?? []
        self.driverName = data["driverName"] as? String ?? "DriverName"
        self.passengerName = data["passengerName"] as? String ?? "PassengerName"
    }
    
    public func displayName(for mode: Mode) -> String{
        guard name.contains("%name%") else { return name }
        
        switch mode {
        case .passenger:
            return name.replacingOccurrences(of: "%name%", with: driverName)
        case .driver:
            return name.replacingOccurrences(of: "%name%", with: passengerName)
        }
    }
}
extension Channel: Channelable {}

extension Channel: DatabaseRepresentation {
    
    var representation: [String : Any] {
        var rep = ["name": name]
        
        if let id = id {
            rep["id"] = id
        }
        rep["driverName"] = driverName
        rep["passengerName"] = passengerName
        
        return rep
    }
    
}

extension Channel: Comparable {
    
    static func == (lhs: Channel, rhs: Channel) -> Bool {
        return lhs.id == rhs.id
    }
    
    public static func < (lhs: Channel, rhs: Channel) -> Bool {
        return lhs.name.lowercased() < rhs.name.lowercased()
    }
    
}
