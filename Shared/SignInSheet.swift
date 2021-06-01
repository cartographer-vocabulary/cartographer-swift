//
//  SignInSheet.swift
//  cartographer
//
//  Created by Tony Zhang on 4/19/21.
//

import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
struct SignInSheet: View {
    @Binding var showingSheet:Bool
    @EnvironmentObject var userInfo:UserInfo
    @State var showingEditNameSheet:Bool = false;
    @State var editingNameText = ""
    #if os(macOS)
    var listStyle = DefaultListStyle()
    #else
    var listStyle = GroupedListStyle()
    #endif
    var body: some View {
        List{
            if !userInfo.signedIn {
                Text("sign up or log in")
                Button(action: {
                    if let url = URL(string: "https://cartographer-vocabulary.web.app/applogin") {
                        #if !os(macOS)
                        UIApplication.shared.open(url)
                        #else
                        NSWorkspace.shared.open(url)
                        #endif
                    }
                }, label:{Text("Log In")})
                #if os(macOS)
                Button(action: {showingSheet = false}, label: {
                    Text("cancel")
                })
                #endif
            }else{
                Text(userInfo.name ?? "signed in")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Button(action: {
                    showingEditNameSheet = true;
                }, label: {
                    Text("edit name")
                })
                .sheet(isPresented: $showingEditNameSheet, content: {
                    VStack{
                        TextField("",text:$editingNameText,onCommit:{
                            showingEditNameSheet = false
                            if(editingNameText.trimmingCharacters(in:.whitespacesAndNewlines) != ""){
                                Firestore.firestore().collection("users").document(userInfo.uid ?? "").updateData([
                                    "displayName":editingNameText.trimmingCharacters(in: .whitespacesAndNewlines)
                                ])
                            }
                        })
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(6)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5,style:.continuous)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .font(.title3)
                        .padding(4)
                    
                        Button(action: {
                            showingEditNameSheet = false
                            if(editingNameText.trimmingCharacters(in:.whitespacesAndNewlines) != ""){
                                Firestore.firestore().collection("users").document(userInfo.uid ?? "").updateData([
                                    "displayName":editingNameText.trimmingCharacters(in: .whitespacesAndNewlines)
                                ])
                            }
                        }, label: {
                            Label("done",systemImage:"checkmark")
                        })
                        .padding(.horizontal,4)
                        
                        Button(action: {showingEditNameSheet = false}, label: {
                            Label("cancel",systemImage:"xmark")
                        })
                        .padding(.horizontal,4)
                    }
                    .frame(idealWidth:200)
                    .padding()
                })
                .onAppear(perform: {
                    editingNameText = userInfo.name ?? ""
                })
                
                Button(action: {
                    do{
                        try FirebaseAuth.Auth.auth().signOut()
                        userInfo.signedIn = false
                    }catch let signOutError as NSError{
                        print ("Error signing out: %@", signOutError)
                    }
                }, label: {
                    Text("sign out")
                })
            }
        }
        .listStyle(listStyle)
        .toolbar(content: {
            #if os(macOS)
            Button(action: {showingSheet = false}, label: {
                Text("cancel")
            })
            #endif
        })
        .frame(minWidth:400, minHeight: 300)
    }
}

