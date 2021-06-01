//
//  FolderContentView.swift
//  cartographer
//
//  Created by Tony Zhang on 4/21/21.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions

struct FolderDoc {
    var name:String?
    var isPublic:Bool = false
    var roles:[String:String]?
}

struct FolderListDoc {
    var name:String
    var cardCount:Int
    var id:String
}

struct FolderContentView: View {
    
    @State var folderId:String
    @State var folderDoc = FolderDoc()
    @State var folderRole = 0
    @State var tempName:String
   
    
    @EnvironmentObject var userInfo:UserInfo

    @State var folderLists:[FolderListDoc] = []
    
    @State var folderListener:ListenerRegistration?
    @State var folderListsListener:ListenerRegistration?

    @State var showingAddSheet = false
    @State var addListText:String = "New List"


    #if os(macOS)
    @State var listId:String?
    #endif
    
    @State var showingSettingsSheet = false
    
    var gridItems = [
        GridItem(.adaptive(minimum: 200),spacing:0)
    ]

    
    @ViewBuilder func addFolderListSheet() -> some View{
        VStack{
            TextField("",text:$addListText)
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
                    showingAddSheet = false
                    if(userInfo.uid != nil && addListText.trimmingCharacters(in: .whitespacesAndNewlines) != ""){
                        Firestore.firestore().collection("lists").addDocument(data: [
                            "name":addListText.trimmingCharacters(in: .whitespacesAndNewlines),
                            "public":false,
                            "folder":folderId,
                            "roles":[
                                userInfo.uid:"creator"
                            ],
                            "cards":[]
                        ])
                    }
                    addListText = "New List"
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
                    if(userInfo.uid != nil && addListText.trimmingCharacters(in: .whitespacesAndNewlines) != ""){
                        Firestore.firestore().collection("lists").addDocument(data: [
                            "name":addListText.trimmingCharacters(in: .whitespacesAndNewlines),
                            "public":false,
                            "folder":folderId,
                            "roles":[
                                userInfo.uid:"creator"
                            ],
                            "cards":[]
                        ])
                    }
                    addListText = "New List"
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
    
    var body: some View {
        #if os(macOS)
        VStack{
            if(listId == nil){
                ScrollView{
                    LazyVGrid(columns:gridItems,spacing:0){
                        ForEach(folderLists,id:\.self.id){ list in
                            FolderOrListItem(name:list.name,cardCount: list.cardCount)
                                .onTapGesture {
                                    listId = list.id
                                }
                        }
                    }
                    .padding(.top).padding(.leading).padding(.trailing)
                    Button(action:{
                        showingAddSheet = true
                    }){
                        Label("Add list",systemImage:"plus")
                    }
                    .padding(.leading).padding(.trailing).padding(.bottom)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .background(customColors.backgroundPrimary)
                .navigationTitle(folderDoc.name ?? tempName)
                .toolbar{
                    ToolbarItemGroup(placement:.primaryAction){
                        Button(action: {
                            Firestore.firestore().collection("users").document(userInfo.uid ?? "").updateData([
                                "favoriteFolders": (userInfo.favoriteFolders?.contains(folderId) ?? false) ? (userInfo.favoriteFolders?.filter{$0 != folderId}) ?? [] : ((userInfo.favoriteFolders ?? []) + [folderId])
                            ])
                        },label:{
                            Label("Star",systemImage: userInfo.favoriteFolders?.contains(folderId) ?? false ? "star.fill" : "star")
                                .foregroundColor(userInfo.favoriteFolders?.contains(folderId) ?? false ? Color.accentColor : Color.primary)
                        })
                        Button(action: {showingSettingsSheet = true},label:{
                            Label("Folder Settings",systemImage:"ellipsis")
                        })
                    }
                }
                .onAppear(perform: {
                    let db = Firestore.firestore()
                    folderListener = db.collection("folders").document(folderId).addSnapshotListener { documentSnapshot, error in
                        guard let document = documentSnapshot else {
                            print("Error fetching document: \(error!)")
                            folderDoc = FolderDoc()
                            return
                        }
                        guard let data = document.data() else {
                            print("Document data was empty.")
                            folderDoc = FolderDoc()
                            return
                        }
                        if(data["name"] != nil){
                            folderDoc.name = data["name"] as? String
                        }else{
                            folderDoc.name = "untitled"
                        }
                        if(data["roles"] != nil){
                            folderDoc.roles = data["roles"] as? [String:String] ?? [:]
                        }else{
                            folderDoc.roles = [:]
                        }
                        if((data["roles"] as? [String:String] ?? [:])[userInfo.uid ?? ""] != nil){
                            folderRole = convertRoleToInt(role:(data["roles"] as? [String:String] ?? [:])[userInfo.uid ?? ""] ?? "")
                        }else{
                            folderRole = 0
                        }
                    }
                    folderListsListener = db.collection("lists").whereField("folder", isEqualTo: folderId).addSnapshotListener { querySnapshot, error in
                        if let error = error {
                            print("Error getting documents: \(error)")
                            folderLists = []
                        } else {
                            folderLists = []
                            for document in querySnapshot!.documents {
                                let folderList = FolderListDoc(name: document.data()["name"] as? String ?? "Untitled", cardCount: (document.data()["cards"] as? [[String:String]])?.count ?? 0, id: document.documentID)
                                folderLists.append(folderList)
                            }
                            folderLists.sort { a, b in
                                return a.name < b.name
                            }
                        }
                    }
                })
                .onDisappear {
                    folderListener?.remove()
                    folderListsListener?.remove()
                }
                .sheet(isPresented: $showingAddSheet) {
                    addFolderListSheet()
                }
                .sheet(isPresented: $showingSettingsSheet){
                    FolderSettingsSheet(folderId:folderId, folderDoc:$folderDoc, folderLists:folderLists, role:folderRole, showingSheet:$showingSettingsSheet)
                        .environmentObject(userInfo)
                }
            }else{
                ListContentView(listId: listId ?? "", tempName: folderLists.filter{$0.id == listId}.first?.name ?? "Undefined")
                    .toolbar{
                        ToolbarItem(placement:.navigation){
                            Button(action:{
                                listId = nil
                            }){
                                Label("back to folder", systemImage:"chevron.backward")
                            }
                        }
                    }
            }
        }
        #else
        ScrollView{
            LazyVGrid(columns:gridItems,spacing:0){
                ForEach(folderLists,id:\.self.id){ list in
                    NavigationLink(destination:ListContentView(listId: list.id,tempName: list.name)){
                        FolderOrListItem(name:list.name,cardCount: list.cardCount)
                    }
                }
            }
            .padding(.top).padding(.leading).padding(.trailing)
            Button(action:{
                showingAddSheet = true
            }){
                Label("Add list",systemImage:"plus")
            }
            .padding(.leading).padding(.trailing).padding(.bottom)
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(customColors.backgroundPrimary)
        .navigationTitle(folderDoc.name ?? tempName)
        .toolbar{
            ToolbarItem(placement: .navigationBarLeading) {
                Text("")
            }
            ToolbarItemGroup(placement:.navigationBarTrailing){
                    Button(action: {
                        Firestore.firestore().collection("users").document(userInfo.uid ?? "").updateData([
                            "favoriteFolders": (userInfo.favoriteFolders?.contains(folderId) ?? false) ? (userInfo.favoriteFolders?.filter{$0 != folderId}) ?? [] : ((userInfo.favoriteFolders ?? []) + [folderId])
                        ])
                    },label:{
                        Label("Favorite",systemImage: userInfo.favoriteFolders?.contains(folderId) ?? false ? "star.fill" : "star")
                            .foregroundColor(userInfo.favoriteFolders?.contains(folderId) ?? false ? Color.accentColor : nil)
                    })
                    Button(action: {showingSettingsSheet = true},label:{
                        Label("Menu",systemImage:"ellipsis")
                    })

            }
        }
        .onAppear(perform: {
            let db = Firestore.firestore()
            folderListener = db.collection("folders").document(folderId).addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching document: \(error!)")
                    folderDoc = FolderDoc()
                    return
                }
                guard let data = document.data() else {
                    print("Document data was empty.")
                    folderDoc = FolderDoc()
                    return
                }
                if(data["name"] != nil){
                    folderDoc.name = data["name"] as? String
                }else{
                    folderDoc.name = "untitled"
                }
                if(data["roles"] != nil){
                    folderDoc.roles = data["roles"] as? [String:String] ?? [:]
                }else{
                    folderDoc.roles = [:]
                }
                if((data["roles"] as? [String:String] ?? [:])[userInfo.uid ?? ""] != nil){
                    folderRole = convertRoleToInt(role:(data["roles"] as? [String:String] ?? [:])[userInfo.uid ?? ""] ?? "")
                }else{
                    folderRole = 0
                }
            }
            folderListsListener = db.collection("lists").whereField("folder", isEqualTo: folderId).addSnapshotListener { querySnapshot, error in
                if let error = error {
                    print("Error getting documents: \(error)")
                    folderLists = []
                } else {
                    folderLists = []
                    for document in querySnapshot!.documents {
                        let folderList = FolderListDoc(name: document.data()["name"] as? String ?? "Untitled", cardCount: (document.data()["cards"] as? [[String:String]])?.count ?? 0, id: document.documentID)
                        folderLists.append(folderList)
                    }
                    folderLists.sort { a, b in
                        return a.name < b.name
                    }
                }
            }
        })
        .onDisappear {
            folderListener?.remove()
            folderListsListener?.remove()
        }
        .sheet(isPresented: $showingAddSheet) {
            addFolderListSheet()
        }
        .sheet(isPresented: $showingSettingsSheet){
            FolderSettingsSheet(folderId:folderId, folderDoc:$folderDoc, folderLists:folderLists, role:folderRole, showingSheet:$showingSettingsSheet)
                .environmentObject(userInfo)
        }

        #endif
    }
}

struct FolderSettingsSheet:View{
    @State var folderId:String
    @Binding var folderDoc:FolderDoc
    @State var folderLists:[FolderListDoc]
    @State var showingDeleteAlert = false
    @State var showingEditSheet = false
    @State var editingText = ""
    @State var role:Int
    @Binding var showingSheet:Bool
    @EnvironmentObject var userInfo:UserInfo

    @State var showingAddPersonSheet = false
    @State var addPersonText = ""
    #if os(macOS)
    var listStyle = DefaultListStyle()
    #else
    var listStyle = GroupedListStyle()
    #endif
    @ViewBuilder func content() -> some View{
        List{
            Section(header: Text("sharing")){
                if(role != 0){
                    Toggle("Public", isOn:$folderDoc.isPublic)
                        .onChange(of: folderDoc.isPublic) { _ in
                            Firestore.firestore().collection("folders").document(folderId).updateData([
                                "public":folderDoc.isPublic
                            ])
                        }
                        .toggleStyle(SwitchToggleStyle())
                }
                Section{
                    ForEach(folderDoc.roles?.sorted(by:{return $0.value < $1.value}) ?? [], id:\.key){ key,value in
                        if(key != userInfo.uid && role != 0){
                            RoleView(selectedRole:value, userId:key, roles: folderDoc.roles ?? [:],docId:folderId, isList:false)
                        }else{
                            Text(userInfo.name ?? "untitled")
                                .padding(.leading)
                        }
                    }
                }
                
                if(role != 0){
                    Button(action:{
                        showingAddPersonSheet = true
                    }){
                        Text("Add Person")
                    }
                    .sheet(isPresented:$showingAddPersonSheet){
                        VStack{
                            Text("Enter an email")
                            TextField("",text: $addPersonText)
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
                                    if addPersonText.trimmingCharacters(in:.whitespacesAndNewlines) != "" {
                                        FirebaseFunctions.Functions.functions().httpsCallable("getUidFromEmail").call(["email":addPersonText.trimmingCharacters(in:.whitespacesAndNewlines)]) { result, error in
                                            if let error = error as NSError? {
                                                print(error)
                                            }
                                            let uid = (result?.data as? [String:Any])?["user"]as? String ?? ""
                                            folderDoc.roles?[uid] = "viewer"
                                            Firestore.firestore().collection("folders").document(folderId).updateData([
                                                "roles":folderDoc.roles as Any
                                            ])
                                            showingAddPersonSheet = false
                                        }
                                    }
                                    showingAddPersonSheet = false
                                    addPersonText = ""
                                    
                                }){
                                    Text("Add Viewer")
                                }
                                .frame(maxWidth:.infinity)
                                
                                Button(action:{
                                    if addPersonText.trimmingCharacters(in:.whitespacesAndNewlines) != "" {
                                        FirebaseFunctions.Functions.functions().httpsCallable("getUidFromEmail").call(["email":addPersonText.trimmingCharacters(in:.whitespacesAndNewlines)]) { result, error in
                                            if let error = error as NSError? {
                                                print(error)
                                            }
                                            let uid = (result?.data as? [String:Any])?["user"]as? String ?? ""
                                            folderDoc.roles?[uid] = "editor"
                                            Firestore.firestore().collection("folders").document(folderId).updateData([
                                                "roles":folderDoc.roles as Any
                                            ])
                                            showingAddPersonSheet = false
                                        }
                                    }
                                    showingAddPersonSheet = false
                                    addPersonText = ""
                                }){
                                    Text("Add Editor")
                                }
                                .frame(maxWidth:.infinity)
                            }
                            #if !os(iOS)
                            Button(action:{showingAddPersonSheet = false},label:{
                                Text("cancel")
                            })
                            #endif
                        }
                        .frame(idealWidth:200)
                        .padding()
                    }
                }
            }
            
        }
        .listStyle(listStyle)
        .frame(maxWidth:.infinity,maxHeight:.infinity)
        .navigationTitle(folderDoc.name ?? "Untitled Folder")
        .toolbar {
            HStack{
                if(role > 0){
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("edit",systemImage:"pencil")
                    }
                    .sheet(isPresented: $showingEditSheet) {
                        TextField("",text:$editingText,onCommit:{
                            showingEditSheet = false
                            Firestore.firestore().collection("folders").document(folderId).updateData([
                                "name":editingText
                            ])
                        })
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(6)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5,style:.continuous)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .font(.title3)
                        .padding()
                        .onAppear{
                            editingText = folderDoc.name ?? ""
                        }
                    }
                }
                if(role == 2){
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Label("delete",systemImage:"trash")
                    }
                    .alert(isPresented: $showingDeleteAlert) {
                        Alert(title: Text("Delete this folder?"), message: Text("you can't undo this action") ,primaryButton: .destructive(Text("delete")){
                            if(folderLists.count != 0){
                                let batchDelete = Firestore.firestore().batch()
                                for doc in folderLists {
                                    batchDelete.deleteDocument(Firestore.firestore().collection("lists").document(doc.id))
                                }
                                batchDelete.commit()
                            }
                            Firestore.firestore().collection("folders").document(folderId).delete()
                        },secondaryButton: .cancel())
                    }
                }
                #if !os(iOS)
                Button{
                    showingSheet = false
                } label:{
                    Text("close")
                }
                #endif
            }
        }
    }
    var body:some View{
        #if !os(macOS)
        NavigationView{
            content()
        }
        .frame(idealWidth:350, idealHeight:450)
        #else
        content()
            .frame(idealWidth:350, idealHeight:450)
        #endif
    }
}
