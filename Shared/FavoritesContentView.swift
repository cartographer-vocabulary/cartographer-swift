//
//  FavoritesContentView.swift
//  cartographer
//
//  Created by Tony Zhang on 4/17/21.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore


struct FavoritesContentView: View {
    
    @EnvironmentObject var userInfo:UserInfo
    let userDocChanged = NotificationCenter.default
        .publisher(for: Notification.Name("userDocChanged"))
    

    struct FavoritesListDoc {
        var name:String
        var cardCount:Int
        var id:String
    }

    struct FavoritesFolderDoc {
        var name:String
        var id:String
    }
    
    @State var favoriteLists:[FavoritesListDoc] = []
    @State var favoriteFolders:[FavoritesFolderDoc] = []
    
    #if os(macOS)
    @State var listId:String?
    @State var folderId:String?
    #endif
    
    var gridItems = [
        GridItem(.adaptive(minimum: 200),spacing:0)
    ]

    func updateFavorites(){
        let db = Firestore.firestore()
        var tempLists:[FavoritesListDoc] = []
        if((userInfo.favoriteLists?.count ?? 0) == 0){favoriteLists = []}
        for favoriteList in userInfo.favoriteLists ?? [] {
            db.collection("lists").document(favoriteList).getDocument { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching document: \(error!)")
                    return
                }
                guard let data = document.data() else {
                    print("Document data was empty.")
                    return
                }
                let listDoc = FavoritesListDoc(name:data["name"] as? String ?? "Untitled", cardCount: (document.data()?["cards"] as? [[String:String]])?.count ?? 0, id: document.documentID)
                tempLists.append(listDoc)
                if(tempLists.count == userInfo.favoriteLists?.count ?? 0){
                    favoriteLists = tempLists
                }
            }
        }
    
        var tempFolders:[FavoritesFolderDoc] = []
        if((userInfo.favoriteFolders?.count ?? 0) == 0){favoriteFolders = []}
        for favoriteFolder in userInfo.favoriteFolders ?? [] {
            db.collection("folders").document(favoriteFolder).getDocument { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching document: \(error!)")
                    return
                }
                guard let data = document.data() else {
                    print("Document data was empty.")
                    return
                }
                let folderDoc = FavoritesFolderDoc(name:data["name"] as? String ?? "Untitled", id: document.documentID)
                tempFolders.append(folderDoc)
                if(tempFolders.count == userInfo.favoriteFolders?.count ?? 0){
                    favoriteFolders = tempFolders
                }
            }
        }
    }
    
    
    @ViewBuilder
    var body: some View {
        #if os(macOS)
        if(listId != nil){
            ListContentView(listId: listId ?? "", tempName: favoriteLists.filter{$0.id == listId}.first?.name ?? "Undefined")
                .frame(maxWidth:.infinity,maxHeight: .infinity)
                .toolbar{
                    ToolbarItem(placement:.navigation){
                        Button(action:{
                            listId = nil
                        }){
                            Label("back to favorites", systemImage:"chevron.backward")
                        }
                    }
                }
        }else if(folderId != nil){
            FolderContentView(folderId: folderId ?? "", tempName: favoriteFolders.filter{$0.id == folderId}.first?.name ?? "Undefined")
                .toolbar{
                    ToolbarItem(placement:.navigation){
                        Button(action:{
                            folderId = nil
                        }){
                            Label("back to favorites", systemImage:"chevron.backward")
                        }
                    }
                }
        }else{
            ScrollView{
                VStack(alignment:.leading){
                    Text("LISTS")
                        .foregroundColor(Color.gray)
                        .padding(.leading,23)
                        .padding(.top)
                    VStack{
                        LazyVGrid(columns:gridItems,spacing:0){
                            ForEach(favoriteLists,id:\.self.id){ list in
                                FolderOrListItem(name:list.name,cardCount: list.cardCount)
                                    .onTapGesture {
                                        listId = list.id
                                    }
                            }
                        }
                        .padding(.top,0)
                        .padding(.leading)
                        .padding(.trailing)
                        .padding(.bottom)
                    }
                    
                    Text("FOLDERS")
                        .foregroundColor(Color.gray)
                        .padding(.leading,23)
                    VStack{
                        LazyVGrid(columns:gridItems,spacing:0){
                            ForEach(favoriteFolders,id:\.self.id){ folder in
                                FolderOrListItem(name:folder.name)
                                    .onTapGesture {
                                        folderId = folder.id
                                    }
                            }
                        }
                        .padding(.top,0)
                        .padding(.leading)
                        .padding(.trailing)
                        .padding(.bottom)
                    }
                
                }
            
            }
            .frame(maxWidth:.infinity, maxHeight: .infinity)
            .background(customColors.backgroundPrimary)
            .navigationTitle("Favorites")
            .onAppear(perform: updateFavorites)
            .onReceive(userDocChanged, perform:{ _ in
                updateFavorites()
            })
        }
        #else
        ScrollView{
            VStack(alignment:.leading){
                Text("LISTS")
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
                    .padding(.leading,23)
                    .padding(.top)
                
                LazyVGrid(columns:gridItems,spacing:0){
                    ForEach(favoriteLists,id:\.self.id){ list in
                        NavigationLink(destination:ListContentView(listId: list.id,tempName: list.name)){
                            FolderOrListItem(name:list.name,cardCount: list.cardCount)
                        }
                    }
                }
                .padding(.top,0)
                .padding(.leading)
                .padding(.trailing)
                .padding(.bottom)
                
                Text("FOLDERS")
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
                    .padding(.leading,23)
                LazyVGrid(columns:gridItems,spacing:0){
                    ForEach(favoriteFolders,id:\.self.id){ folder in
                        NavigationLink(destination:FolderContentView(folderId: folder.id,tempName: folder.name)){
                            FolderOrListItem(name:folder.name)
                        }
                    }
                }
                .padding(.top,0)
                .padding(.leading)
                .padding(.trailing)
                .padding(.bottom)
            }
            
        }
        .frame(maxWidth:.infinity, maxHeight: .infinity)
        .background(customColors.backgroundPrimary)
        .navigationTitle("Favorites")
        .onAppear(perform: updateFavorites)
        .onReceive(userDocChanged, perform:{ _ in
            updateFavorites()
        })
        #endif
    }
}



