//
//  ListContentView.swift
//  cartographer
//
//  Created by Tony Zhang on 4/17/21.
//

import SwiftUI
import FirebaseFirestore
import FirebaseFunctions
import FirebaseCore
import UniformTypeIdentifiers


struct ListDoc {
    var name:String?
    var isPublic:Bool = false
    var cards:[[String:String]] = [["word":"Placeholder",
                                    "definition":"Placeholder",
                                    "index":"0"]]
    var folder:String = ""
    var roles:[String:String]?
}

#if os(macOS)
extension NSTextField {
    open override var focusRingType: NSFocusRingType {
        get { .none }
        set { }
    }
}
#endif

struct DragRelocateDelegate: DropDelegate {
    let item: [String:String]
    @Binding var listData: [[String:String]]
    @Binding var current: [String:String]?
    @Binding var changedView: Bool
    
    
    let listId:String
    
    func dropEntered(info: DropInfo) {
        
        if current == nil { current = item }
        
        changedView = true
        
        if item != current {
            let from = listData.firstIndex(of: current!)!
            let to = listData.firstIndex(of: item)!
            if listData[to]["index"] != current!["index"] {
                withAnimation(Animation.easeInOut(duration: 0.2)){
                listData.move(fromOffsets: IndexSet(integer: from),
                              toOffset: to > from ? to + 1 : to)
                }
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        Firestore.firestore().collection("lists").document(listId).updateData([
            "cards":listData.map({ cardItem -> [String:String] in
                return ["word":cardItem["word"] ?? "Untitled","definition":cardItem["definition"] ?? "Untitled"]
            })
        ])
        changedView = false
        self.current = nil
        return true
    }
    
}
struct DropOutsideDelegate: DropDelegate {
    @Binding var current: [String:String]?
    @Binding var changedView: Bool
    let update: () -> ()

    func dropEntered(info: DropInfo) {
        changedView = true
    }
    func performDrop(info: DropInfo) -> Bool {
        update()
        changedView = false
        current = nil
        return true
    }
}
func convertRoleToInt(role:String) -> Int{
    if(role == "creator"){return 2}
    if(role == "editor"){return 1}
    if(role == "viewer"){return 0}
    return -1
}


struct ListContentView: View {

    @State var listDoc = ListDoc()
    @State var listRole = 0
    @State var folderRole = 0
    var userRole:Int {
        return max(listRole, folderRole)
    }
    @EnvironmentObject var userInfo:UserInfo
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var listId:String
    @State var tempName:String
    
    @State var listListener:ListenerRegistration?
    @State var parentFolderListener:ListenerRegistration?

    var gridItems = [
        GridItem(.adaptive(minimum: 200),spacing:0)
    ]
    
    @State private var dragging: [String:String]?
    @State private var changedView: Bool = false

    
    @State var addCardWord = ""
    @State var addCardDefinition = ""
    
    @State var showingSettingsSheet = false
    
    @State var listModeOptions = ["card","quiz"]
    @State var listMode = "card"
    
    func addCard(){
        let word = addCardWord.trimmingCharacters(in: .whitespacesAndNewlines)
        let definition = addCardDefinition.trimmingCharacters(in: .whitespacesAndNewlines)
        if(word != "" && definition != ""){
            listDoc.cards.append(["word":addCardWord,"definition":addCardDefinition])
            Firestore.firestore().collection("lists").document(listId).updateData([
                "cards":listDoc.cards.map({ cardItem -> [String:String] in
                    return ["word":cardItem["word"] ?? "Untitled","definition":cardItem["definition"] ?? "Untitled"]
                })
            ])
            addCardWord = ""
            addCardDefinition = ""
        }
    }
    
    var body: some View {
        ScrollView{
            ScrollViewReader { value in
                VStack{
                    #if !os(macOS)
                    Picker("", selection:$listMode){
                        ForEach(listModeOptions, id:\.self){
                            Label($0,systemImage:$0 == "card" ? "rectangle.on.rectangle.angled" : "square.and.pencil")
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.top)
                    .padding(.leading, 23)
                    .padding(.trailing, 23)
                    #endif
                    
                    if listMode == "card"{
                        FlashcardView(cards:$listDoc.cards)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        //cards
                        LazyVGrid(columns:gridItems,spacing:0){
                            ForEach(listDoc.cards,id:\.self){ card in
                                let index = Int(card["index"] ?? "0")
                                if(userRole != 0){
                                    CardView(word:card["word"] ?? "Untitled",definition: card["definition"] ?? "Untitled",canEdit: userRole > 0, onDelete: {
                                        if(index != nil){
                                            listDoc.cards.remove(at: index ?? 0)
                                            Firestore.firestore().collection("lists").document(listId).updateData([
                                                "cards":listDoc.cards.map({ cardItem -> [String:String] in
                                                    return ["word":cardItem["word"] ?? "Untitled","definition":cardItem["definition"] ?? "Untitled"]
                                                })
                                            ])
                                        }
                                    },onWordChange:{ word in
                                        if(index != nil){
                                            listDoc.cards[index ?? 0]["word"] = word
                                            Firestore.firestore().collection("lists").document(listId).updateData([
                                                "cards":listDoc.cards.map({ cardItem -> [String:String] in
                                                    return ["word":cardItem["word"] ?? "Untitled","definition":cardItem["definition"] ?? "Untitled"]
                                                })
                                            ])

                                        }
                                    }, onDefinitionChange:{ definition in
                                        if(index != nil){
                                            print("definition")
                                            listDoc.cards[index ?? 0]["definition"] = definition
                                            Firestore.firestore().collection("lists").document(listId).updateData([
                                                "cards":listDoc.cards.map({ cardItem -> [String:String] in
                                                    return ["word":cardItem["word"] ?? "Untitled","definition":cardItem["definition"] ?? "Untitled"]
                                                })
                                            ])
                                        }
                                    })
                                    .cornerRadius(8)
                                    .opacity(dragging?["index"] == card["index"] && changedView ? 0 : 1)
                                    .onDrag{
                                        self.dragging = card
                                        changedView = false
                                        return NSItemProvider(object: String(card["index"] ?? "0") as NSString)
                                    }
                                    .onDrop(of: [UTType.text], delegate: DragRelocateDelegate(item: card, listData: $listDoc.cards, current: $dragging, changedView: $changedView,listId: listId))
                                }else{
                                    CardView(word:card["word"] ?? "Untitled",definition: card["definition"] ?? "Untitled",canEdit: userRole > 0, onDelete: {
                                    },onWordChange:{ word in
                                    }, onDefinitionChange:{ definition in
                                    })
                                    .cornerRadius(8)
                                    .opacity(dragging?["index"] == card["index"] && changedView ? 0 : 1)
                                }
                                
                            }
                        }
                        .padding()
                        
                        //adding lists view
                        if(userRole != 0){
                            VStack(spacing:8){
                                #if os(macOS)
                                TextField("Word",text:$addCardWord,onCommit:addCard)
                                    .font(.system(size: 18, weight: .heavy, design: .default))
                                    .focusable()
                                    .padding(6)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4,style:.continuous)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                TextField("Definition",text:$addCardDefinition,onCommit:addCard)
                                    .font(.system(size: 18, design: .default))
                                    .focusable()
                                    .padding(6)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4,style:.continuous)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                #else
                                TextField("Word",text:$addCardWord,onEditingChanged:{_ in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        withAnimation(.easeInOut){
                                            value.scrollTo("scroll")
                                        }
                                    }
                                },onCommit:addCard)
                                .font(.system(size: 18, weight: .heavy, design: .default))
                                .padding(6)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4,style:.continuous)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                TextField("Definition",text:$addCardDefinition,onEditingChanged:{_ in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        withAnimation(.easeInOut){
                                            value.scrollTo("scroll")
                                        }
                                    }
                                },onCommit:addCard)
                                .font(.system(size: 18, design: .default))
                                .padding(6)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4,style:.continuous)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                #endif
                            }
                                .id("scroll")
                                .padding(8)
                                .background(customColors.backgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8,style:.continuous)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.top,-10)
                                .padding(.leading,23)
                                .padding(.trailing,23)
                                .padding(.bottom,23)
                        }
                    }else{
                        ListQuizView(cards:listDoc.cards)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onDrop(of: [UTType.text], delegate: DropOutsideDelegate(current: $dragging, changedView: $changedView,update: {
            Firestore.firestore().collection("lists").document(listId).updateData([
                "cards":listDoc.cards.map({ cardItem -> [String:String] in
                    return ["word":cardItem["word"] ?? "Untitled","definition":cardItem["definition"] ?? "Untitled"]
                })
            ])
        }))
        .background(customColors.backgroundPrimary)
        .navigationTitle(listDoc.name ?? tempName)
        .toolbar{
            #if os(macOS)
            ToolbarItemGroup(placement:.primaryAction){
                Picker("", selection:$listMode){
                    ForEach(listModeOptions, id:\.self){
                        Label($0,systemImage:$0 == "card" ? "rectangle.on.rectangle.angled" : "square.and.pencil")
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                Button(action: {
                    let case1 = (userInfo.favoriteLists?.filter{$0 != listId}) ?? []
                    let case2 = ((userInfo.favoriteLists ?? []) + [listId])
                    Firestore.firestore().collection("users").document(userInfo.uid ?? "").updateData([
                        "favoriteLists": (userInfo.favoriteLists?.contains(listId) ?? false) ? case1 : case2
                    ])
                },label:{
                    Label("Star",systemImage: userInfo.favoriteLists?.contains(listId) ?? false ? "star.fill" : "star")
                        .foregroundColor(userInfo.favoriteLists?.contains(listId) ?? false ? Color.accentColor : nil)
                })
                Button(action: {showingSettingsSheet = true},label:{
                    Label("List Settings",systemImage:"ellipsis")
                })
            }
            #else
            ToolbarItem(placement: .navigationBarLeading) {
                Text("")
            }
            ToolbarItemGroup(placement:.navigationBarTrailing){
                Button(action: {
                    let case1 = (userInfo.favoriteLists?.filter{$0 != listId}) ?? []
                    let case2 = ((userInfo.favoriteLists ?? []) + [listId])
                    Firestore.firestore().collection("users").document(userInfo.uid ?? "").updateData([
                        "favoriteLists": (userInfo.favoriteLists?.contains(listId) ?? false) ? case1 : case2
                    ])
                },label:{
                    Image(systemName: userInfo.favoriteLists?.contains(listId) ?? false ? "star.fill" : "star")
                        .foregroundColor(userInfo.favoriteLists?.contains(listId) ?? false ? Color.accentColor : nil)
                })
                Button(action: {showingSettingsSheet = true},label:{
                    Label("Menu",systemImage:"ellipsis")
                })
            }
            #endif
        }
        .sheet(isPresented:$showingSettingsSheet){
            ListSettingsSheet(listId:listId, listDoc:$listDoc, role:userRole, showingSheet:$showingSettingsSheet)
                .environmentObject(userInfo)
        }
        .onAppear(perform: {
            let db = Firestore.firestore()
            listListener = db.collection("lists").document(listId).addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching document: \(error!)")
                    self.presentationMode.wrappedValue.dismiss()
                    listDoc = ListDoc()
                    return
                }
                guard let data = document.data() else {
                    print("Document data was empty.")
                    self.presentationMode.wrappedValue.dismiss()
                    listDoc = ListDoc()
                    return
                }
                if(data["cards"] != nil){
                    let tempCards = listDoc.cards.map({ cardItem -> [String:String] in
                        return ["word":cardItem["word"] ?? "Untitled","definition":cardItem["definition"] ?? "Untitled"]
                    })
                    if(tempCards != data["cards"] as! [Dictionary<String,String>]) {
                        listDoc.cards = data["cards"] as! [Dictionary<String,String>]
                    }
                    for i in listDoc.cards.indices{
                        listDoc.cards[i]["index"] = String(i)
                    }
                }
                if(data["name"] != nil){
                    listDoc.name = data["name"] as? String
                }
                if(data["roles"] != nil){
                    listDoc.roles = data["roles"] as? [String:String] ?? [:]
                }
                if((data["roles"] as? [String:String] ?? [:])[userInfo.uid ?? ""] != nil){
                    folderRole = convertRoleToInt(role:(data["roles"] as? [String:String] ?? [:])[userInfo.uid ?? ""] ?? "")
                }
                if(data["public"] != nil){
                    listDoc.isPublic = data["public"] as? Bool ?? false
                }
                if(data["folder"] != nil){
                    listDoc.folder = data["folder"] as? String ?? ""
                }
                
            }
            
            db.collection("lists").document(listId).getDocument { listDocument, error in
                if let listDocument = listDocument, listDocument.exists {
                    if listDocument.data()?["folder"] != nil && (listDocument.data()?["folder"] as? String ?? "") != "" {
                        parentFolderListener = db.collection("folders").document(listDoc.folder).addSnapshotListener({ documentSnapshot, error in
                            guard let document = documentSnapshot else {
                                print("Error fetching document: \(error!)")
                                return
                            }
                            guard let data = document.data() else {
                                print("Document data was empty.")
                                return
                            }
                            if((data["roles"] as? [String:String] ?? [:])[userInfo.uid ?? ""] != nil){
                               folderRole = convertRoleToInt(role:(data["roles"] as? [String:String] ?? [:])[userInfo.uid ?? ""] ?? "")
                            }
                        })
                    }
                } else {
                    print("Document does not exist")
                }
            }
        })
        .onDisappear(perform: {
            listListener?.remove()
            parentFolderListener?.remove()
        })
    
    }
}

