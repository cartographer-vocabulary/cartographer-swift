//
//  cartographerApp.swift
//  Shared
//
//  Created by Tony Zhang on 4/17/21.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

class UserInfo:ObservableObject{
    @Published var signedIn = false
    @Published var email:String?
    @Published var name:String?
    @Published var uid:String?
    @Published var favoriteFolders:[String]?
    @Published var favoriteLists:[String]?
}


@main
struct cartographerApp: App {
    let persistenceController = PersistenceController.shared;
    
    @StateObject var userInfo = UserInfo()
    @State var userListener:ListenerRegistration?
    @State var isAlreadyLaunchedOnce = false
    
    func appLoad(){
        if(!isAlreadyLaunchedOnce){
            isAlreadyLaunchedOnce = true
            FirebaseApp.configure()
            FirebaseAuth.Auth.auth().addStateDidChangeListener{ (auth, user) in
                if let user = user {
                    self.userInfo.uid = user.uid
                    self.userInfo.email = user.email
                    self.userInfo.name = user.displayName
                    self.userInfo.signedIn = true
                    
                    NotificationCenter.default.post(name:Notification.Name("userLoggedIn"),object: nil)
             
                    //get the user document
                    userListener = Firestore.firestore().collection("users").document(user.uid).addSnapshotListener{ documentSnapshot, error in
                        guard let document = documentSnapshot else {
                            print("Error fetching document: \(error!)")
                            return
                        }
                        guard let data = document.data() else {
                            print("Document data was empty.")
                            return
                        }
                        if(data["favoriteLists"] != nil){
                            userInfo.favoriteLists = data["favoriteLists"] as? [String]
                        }
                        if(data["favoriteFolders"] != nil){
                            userInfo.favoriteFolders = data["favoriteFolders"] as? [String]
                        }
                        if(data["displayName"] != nil){
                            userInfo.name = data["displayName"] as? String
                        }
                        NotificationCenter.default.post(name:Notification.Name("userDocChanged"),object: nil)
                    }
                    
                }else{
                    userInfo.signedIn = false
                    userInfo.signedIn = false
                    userInfo.email = nil
                    userInfo.name = nil
                    userInfo.uid = nil
                    userInfo.favoriteLists = nil
                    userInfo.favoriteFolders = nil
                    NotificationCenter.default.post(name:Notification.Name("userDocChanged"),object: nil)

                }
            }
        }
    }
    
    @State var showingSheet = false;
    var body: some Scene {
        WindowGroup {
            ContentView(showingSheet: $showingSheet)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(userInfo)
                .onOpenURL(perform: { url in
                    //website sends a url with a id-token, and then the app calls a cloud function which returns a sign-in token, which is used to sign in
                    if(url.absoluteString.starts(with: "cartographer://idtoken/")){
                        FirebaseFunctions.Functions.functions().httpsCallable("signInWithToken").call(["token":url.lastPathComponent]){(result, error) in
                            if let error = error as NSError? {
                                print(error)
                            }
                            let customToken = (result?.data as? [String:Any])?["customToken"] as? String ?? ""
                            FirebaseAuth.Auth.auth().signIn(withCustomToken: customToken) { (user, error) in
                                showingSheet = false
                            }
                        }
                    }
                })
                .onAppear(perform:appLoad)
        }
    }
}

