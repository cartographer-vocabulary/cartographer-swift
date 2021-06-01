//
//  FolderSettingsSheet.swift
//  Cartographer
//
//  Created by Tony Zhang on 6/1/21.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions

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
                            showingSheet = false
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
