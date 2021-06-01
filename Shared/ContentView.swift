//
//  ContentView.swift
//  Shared
//
//  Created by Tony Zhang on 4/17/21.
//

import SwiftUI
import CoreData
import FirebaseCore
import FirebaseFirestore


struct ListsArrayItem {
    var name:String
    var id:String
    var role:String
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var userInfo:UserInfo
    
    @Binding var showingSheet:Bool
    
    @State var listsArray:[ListsArrayItem]=[]
    @State var listsListener:ListenerRegistration?

    @State var foldersArray:[ListsArrayItem]=[]
    @State var foldersListener:ListenerRegistration?

    @State var selection:Int? = 0
    let signInPublisher = NotificationCenter.default
        .publisher(for: Notification.Name("userLoggedIn"))
    
    @State var showingAddSheet = false
    @State var addSheetIsList = true
    @State var addText:String = "New List"


    //the list view
    @ViewBuilder func listView() -> some View {
        List{
            NavigationLink(
                destination: FavoritesContentView().environmentObject(userInfo).environmentObject(userInfo),
                label: {
                    Label("Favorites",systemImage: "star")
                })
            Section(header:HStack{
                Text("My Lists")
                Button(action:{
                    addSheetIsList = true
                    showingAddSheet = true
                    addText = "New List"
                }){
                    Image(systemName: "plus")
                        .padding(.bottom,1)
                }
                .buttonStyle(PlainButtonStyle())
            }){
                ForEach(listsArray,id:\.self.id) { doc in
                    NavigationLink(
                        destination: ListContentView(listId: doc.id, tempName:doc.name).background(customColors.backgroundPrimary).environmentObject(userInfo),
                        label: {
                            Label(doc.name,systemImage: "list.bullet")
                        })
                }
            }
           

            Section(header:HStack{
                Text("My Folders")
                Button(action:{
                    addSheetIsList = false
                    showingAddSheet = true
                    addText = "New Folder"
                }){
                    Image(systemName: "plus")
                        .padding(.bottom,1)
                }
                .buttonStyle(PlainButtonStyle())
            }){
                ForEach(foldersArray,id:\.self.id) { doc in
                    NavigationLink(
                        destination: FolderContentView(folderId: doc.id,tempName: doc.name).background(customColors.backgroundPrimary),
                        label: {
                            Label(doc.name,systemImage: "folder")
                        })
                }
            }


        }
        .navigationTitle("Cartographer")
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
        .sheet(isPresented: $showingAddSheet) {
            VStack{
                Text("Add a new \(addSheetIsList ? "List" : "Folder")")
                TextField("",text:$addText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(6)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5,style:.continuous)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .foregroundColor(Color.primary)
                HStack{
                    Button(action:{
                        if(!userInfo.signedIn){
                            showingSheet = true;
                        }
                        showingAddSheet = false
                        if(addSheetIsList){
                            if(userInfo.uid != nil && addText.trimmingCharacters(in: .whitespacesAndNewlines) != ""){
                                Firestore.firestore().collection("lists").addDocument(data: [
                                    "name":addText.trimmingCharacters(in: .whitespacesAndNewlines),
                                    "public":false,
                                    "roles":[
                                        userInfo.uid:"creator"
                                    ],
                                    "cards":[]
                                ])
                            }
                        }else{
                            if(userInfo.uid != nil && addText.trimmingCharacters(in: .whitespacesAndNewlines) != ""){
                                Firestore.firestore().collection("folders").addDocument(data: [
                                    "name":addText.trimmingCharacters(in: .whitespacesAndNewlines),
                                    "public":false,
                                    "roles":[
                                        userInfo.uid:"creator"
                                    ]
                                ])
                            }
                        }
                    },label:{
                        Image(systemName:"checkmark")
                    })
                    .frame(maxWidth:.infinity,maxHeight:.infinity)
                    .buttonStyle(PlainButtonStyle())
                    .padding(5)
                    .background(Color.green)
                    .foregroundColor(customColors.backgroundPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .onTapGesture {
                        showingAddSheet = false
                        if(addSheetIsList){
                            if(userInfo.uid != nil && addText.trimmingCharacters(in: .whitespacesAndNewlines) != ""){
                                Firestore.firestore().collection("lists").addDocument(data: [
                                    "name":addText.trimmingCharacters(in: .whitespacesAndNewlines),
                                    "public":false,
                                    "roles":[
                                        userInfo.uid:"creator"
                                    ],
                                    "cards":[]
                                ])
                            }
                        }else{
                            if(userInfo.uid != nil && addText.trimmingCharacters(in: .whitespacesAndNewlines) != ""){
                                Firestore.firestore().collection("folders").addDocument(data: [
                                    "name":addText.trimmingCharacters(in: .whitespacesAndNewlines),
                                    "public":false,
                                    "roles":[
                                        userInfo.uid:"creator"
                                    ]
                                ])
                            }
                        }
                    }
                    
                    Button(action:{
                        showingAddSheet = false
                    },label:{
                        Image(systemName:"xmark")
                    })
                    .frame(maxWidth:.infinity,maxHeight:.infinity)
                    .buttonStyle(PlainButtonStyle())
                    .padding(5)
                    .background(Color.red)
                    .foregroundColor(customColors.backgroundPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .onTapGesture {
                        showingAddSheet = false
                    }
                }
                .frame(height:35)
                
            }
            .padding()
            .frame(minWidth:200)
            
        }
       
    }
        
    func fetchFirebaseData(){
        listsListener?.remove()
        foldersListener?.remove()
        listsListener = Firestore.firestore().collection("lists").whereField("roles.\(userInfo.uid ?? "")", in:["creator","editor","viewer"]).addSnapshotListener { (querySnapshot, error) in
            if let error = error {
                print("Error getting documents: \(error)")
                listsArray=[]
            } else {
                listsArray = []
                for document in querySnapshot!.documents {
                    if((document.data()["folder"] ?? "") as! String == ""){
                        let newListItem = ListsArrayItem(name: document.data()["name"] as? String ?? "Untitled", id: document.documentID, role: (document.data()["roles"] as? [String:String])?[userInfo.uid ?? ""] ?? "creator")
                        listsArray.append(newListItem)
                    }
                }
                listsArray.sort { (a, b) -> Bool in
                    return a.name.lowercased() < b.name.lowercased()
                }
                listsArray.sort { (a, b) -> Bool in
                    return a.role < b.role
                }
            }
        }
        foldersListener = Firestore.firestore().collection("folders").whereField("roles.\(userInfo.uid ?? "")", in:["creator","editor","viewer"]).addSnapshotListener { (querySnapshot, error) in
            if let error = error {
                print("Error getting documents: \(error)")
                foldersArray = []
            } else {
                foldersArray = []
                for document in querySnapshot!.documents {
                    let newFolderItem = ListsArrayItem(name: document.data()["name"] as? String ?? "Untitled", id: document.documentID, role: (document.data()["roles"] as? [String:String])?[userInfo.uid ?? ""] ?? "creator")
                    foldersArray.append(newFolderItem)
                }
                foldersArray.sort { (a, b) -> Bool in
                    return a.name.lowercased() < b.name.lowercased()
                }
                foldersArray.sort { (a, b) -> Bool in
                    return a.role < b.role
                }
            }
        }
    }
    
    var body: some View {
        NavigationView{
            #if os(macOS)
            listView()
                .listStyle(SidebarListStyle())
                .toolbar(content: {
                    ToolbarItem(placement: .navigation){
                        Button(action:toggleSidebar,label: {
                            Label("toggle sidebar",systemImage: "sidebar.left")
                        })
                    }
                    ToolbarItem(placement: .automatic){
                        Button(action: {
                            showingSheet = true
                        }, label: {
                            Label("profile", systemImage: "person.crop.circle")
                        })
                    }
                })
            #elseif os(iOS)
            listView()
                .listStyle(InsetGroupedListStyle())
                .toolbar(content: {
                    ToolbarItem(placement: .navigationBarTrailing){
                        Button(action: {
                            showingSheet = true
                        }, label: {Image(systemName: "person.crop.circle")})
                    }
                })
            #endif
            
            VStack(alignment: .leading){
                Text("Cartographer")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Hello \(userInfo.name ?? "Person")! click on some stuff on the side bar to use this app")
            }
            .frame(maxWidth:.infinity,maxHeight: .infinity)
            .padding()
            .ignoresSafeArea()
            .background(customColors.backgroundPrimary)
            
            
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
        .sheet(isPresented: $showingSheet) {
            SignInSheet(showingSheet:$showingSheet)
                .environmentObject(userInfo)
        }
        .onReceive(signInPublisher, perform: { _ in
            fetchFirebaseData()
        })
        .onAppear(perform: {
            if(userInfo.signedIn){
                fetchFirebaseData()
            }
        })
        .onDisappear(perform: {
            listsListener?.remove()
            foldersListener?.remove()
        })
        
    }
}

func toggleSidebar() {
    #if os(macOS)
    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    #endif
}

