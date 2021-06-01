//
//  ListSettingsSheet.swift
//  Cartographer
//
//  Created by Tony Zhang on 6/1/21.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions

struct ListSettingsSheet:View{
    @State var listId:String
    @Binding var listDoc:ListDoc
    @State var showingDeleteAlert = false
    @State var showingEditSheet = false
    @State var editingText = ""
    @State var role:Int
    @Binding var showingSheet:Bool
    @EnvironmentObject var userInfo:UserInfo

    @State var folderOptions:[ListsArrayItem] = []
    @State var foldersListener:ListenerRegistration?
    
    @State var showingAddPersonSheet = false
    @State var addPersonText = ""
    @State var showingQuizletImportSheet = false
    @State var quizletText = ""
    #if os(macOS)
    var listStyle = DefaultListStyle()
    #else
    var listStyle = GroupedListStyle()
    #endif
    @ViewBuilder func content() -> some View{
        List{
            if(role != 0){
                Picker("Folder",selection:$listDoc.folder){
                    ForEach(folderOptions, id:\.id){
                        Text($0.name)
                    }
                }
                .onAppear{
                    foldersListener = Firestore.firestore().collection("folders").whereField("roles.\(userInfo.uid ?? "")", in:["creator","editor","viewer"]).addSnapshotListener { (querySnapshot, error) in
                        if let error = error {
                            print("Error getting documents: \(error)")
                        } else {
                            folderOptions = []
                            for document in querySnapshot!.documents {
                                let newFolderItem = ListsArrayItem(name: document.data()["name"] as? String ?? "Untitled", id: document.documentID, role: (document.data()["roles"] as? [String:String])?[userInfo.uid ?? ""] ?? "creator")
                                folderOptions.append(newFolderItem)
                            }
                            folderOptions.sort { (a, b) -> Bool in
                                return a.name.lowercased() < b.name.lowercased()
                            }
                            folderOptions.sort { (a, b) -> Bool in
                                return a.role < b.role
                            }
                            folderOptions.insert(ListsArrayItem(name: "none",id:"",role:"creator"), at: 0)
                        }
                    }
                }
                .onChange(of: listDoc.folder) { _ in
                    Firestore.firestore().collection("lists").document(listId).updateData([
                        "folder":listDoc.folder
                    ])
                }
            }
            Section(header: Text("sharing")){
                if(role != 0){
                    Toggle("Public", isOn:$listDoc.isPublic)
                        .onChange(of: listDoc.isPublic) { _ in
                            Firestore.firestore().collection("lists").document(listId).updateData([
                                "public":listDoc.isPublic
                            ])
                        }
                        .toggleStyle(SwitchToggleStyle())
                }
                Section{
                    ForEach(listDoc.roles?.sorted(by:{return $0.value < $1.value}) ?? [], id:\.key){ key,value in
                        if(key != userInfo.uid && role != 0){
                            RoleView(selectedRole:value, userId:key, roles: listDoc.roles ?? [:],docId:listId, isList:true)
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
                                            listDoc.roles?[uid] = "viewer"
                                            Firestore.firestore().collection("lists").document(listId).updateData([
                                                "roles":listDoc.roles as Any
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
                                            listDoc.roles?[uid] = "editor"
                                            Firestore.firestore().collection("lists").document(listId).updateData([
                                                "roles":listDoc.roles as Any
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
            if(role != 0){
                Button(action:{
                    showingQuizletImportSheet = true
                }){
                    Text("import from quizlet")
                }
                .sheet(isPresented:$showingQuizletImportSheet){
                    VStack{
                        Text("To import from quizlet, open the list and press the more button (3 dots) and select export. paste the text here. this will not erase your other cards \n\nhttps://help.quizlet.com/hc/en-us/articles/360034345672-Exporting-your-sets")
                        TextEditor(text:$quizletText)
                            .frame(maxHeight:100)
                            .padding(2)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5,style:.continuous)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        HStack{
                            Button(action:{
                                showingQuizletImportSheet = false
                                quizletText = quizletText.trimmingCharacters(in:.whitespacesAndNewlines)
                                if(quizletText != ""){
                                    var cards = quizletText.components(separatedBy: "\n").map{ value -> [String:String] in
                                        let split = value.components(separatedBy: "\t")
                                        var word = "no value"
                                        var definition = "no value"
                                        if(split.indices.contains(0)){
                                            word = split[0]
                                        }
                                        if(split.indices.contains(1)){
                                            definition = split[1]
                                        }
                                        return [
                                            "word": word,
                                            "definition": definition
                                        ]
                                        
                                    }
                                    cards = listDoc.cards + cards
                                    Firestore.firestore().collection("lists").document(listId).updateData([
                                        "cards":cards
                                    ])
                                    print(cards)
                                }
                                
                            },label:{
                                Image(systemName:"checkmark")
                            })
                            .padding(.trailing)
                            
                            
                            Button(action:{
                                showingQuizletImportSheet = false
                            },label:{
                                Image(systemName:"xmark")
                            })
                            .padding(.leading)
                            
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .frame(idealWidth:350,idealHeight:300)
                }
            }
            
        }
        .listStyle(listStyle)
        .frame(maxWidth:.infinity,maxHeight:.infinity)
        .navigationTitle(listDoc.name ?? "Untitled List")
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
                            Firestore.firestore().collection("lists").document(listId).updateData([
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
                            editingText = listDoc.name ?? ""
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
                        Alert(title: Text("Delete this list?"), message: Text("you can't undo this action") ,primaryButton: .destructive(Text("delete")){
                            showingSheet = false
                            Firestore.firestore().collection("lists").document(listId).delete()
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
