//
//  RoleView.swift
//  Cartographer
//
//  Created by Tony Zhang on 5/1/21.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions

struct RoleView: View {
    @State var selectedRole:String
    @State var userId:String
    @State var userName:String = "loading"
    @State var roles:[String:String]
    @State var docId:String
    @State var isList:Bool
    @State var roleOptions = ["creator","editor","viewer"]

    var docType: String {
        return isList ? "lists" : "folders"
    }
    
    var body: some View {
        HStack{
            Text(userName)
                .lineLimit(1)
            Spacer()
            Picker("", selection:$selectedRole){
                ForEach(roleOptions, id:\.self){
                    Text($0)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 180)
            .onChange(of: selectedRole) { _ in
                roles[userId] = selectedRole
                Firestore.firestore().collection(docType).document(docId).updateData([
                    "roles": roles
                ])
            }
            Button(action:{
                roles[userId] = nil
                Firestore.firestore().collection(docType).document(docId).updateData([
                    "roles": roles
                ])
            }){
                Image(systemName: "xmark")
            }
            .buttonStyle(BorderlessButtonStyle())
            Spacer()
                .frame(width:0)
        }
        .padding(.leading)
        .onChange(of: userId){ _ in
            FirebaseFunctions.Functions.functions().httpsCallable("getDisplayName").call(["uid":userId]) { result, error in
                if let error = error as NSError? {
                    print(error)
                }
                userName = (result?.data as? [String:Any])?["name"] as? String ?? "unnamed"
            }
        }
        .onAppear{
            FirebaseFunctions.Functions.functions().httpsCallable("getDisplayName").call(["uid":userId]) { result, error in
                if let error = error as NSError? {
                    print(error)
                }
                userName = (result?.data as? [String:Any])?["name"] as? String ?? "unnamed"
            }
        }
    }
}
