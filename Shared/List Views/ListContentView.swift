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
                listData.move(fromOffsets: IndexSet(integer: from),
                              toOffset: to > from ? to + 1 : to)
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
                            .animation(Animation.easeInOut(duration: 0.2))
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
                    listDoc = ListDoc()
                    return
                }
                guard let data = document.data() else {
                    print("Document data was empty.")
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


struct ListQuizView:View{
    @State var cards:[[String:String]]
    @State var cardChoice = 0
    @State var cardOptions: [Int] = []
    
    @State var previousCard:Int?
    @State var cardGuesses:[Int] = []
    @State var quizWordMode = "word"
    @State var quizDefinitionMode = "definition"
    var gridItems = [
        GridItem(.adaptive(minimum: 200),spacing:0)
    ]
    
    
    func updateCards(){
        if(previousCard != nil){
            var tempCards = Array(0..<cards.count)
            tempCards.remove(at: previousCard!)
            cardChoice = tempCards.shuffled()[0]
        }
        var tempCards = Array(0..<cards.count)
        tempCards.remove(at: cardChoice)
        var selectedCards = tempCards.prefix(3)
        selectedCards.append(cardChoice)
        selectedCards.shuffle()
        cardOptions =  Array(selectedCards)
        previousCard = cardChoice
        cardGuesses = []
    }
    
    var body: some View{
        VStack(alignment:.leading){
            if(cards.count > 1){
                HStack{
                    Text(cards[cardChoice][quizWordMode] ?? "unknown" )
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Button(action:{
                        if(quizWordMode == "word"){
                            quizWordMode = "definition"
                            quizDefinitionMode = "word"
                        }else{
                            quizWordMode = "word"
                            quizDefinitionMode = "definition"
                        }
                    }){
                        Text(Image(systemName:"arrow.2.squarepath"))
                            .font(.title2)
                            .fontWeight(.light)

                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.leading, 8)
                .padding(.bottom, -4)
                LazyVGrid(columns: gridItems, spacing: 0) {
                    ForEach(cardOptions,id:\.self){ card in
                        VStack(alignment: .leading){
                            Text(cards[card][quizDefinitionMode] ?? "unknown")
                                .frame(maxWidth:.infinity,alignment: .leading)
                            Spacer()
                        }
                        .frame(maxWidth:.infinity, idealHeight: 100, maxHeight:.infinity, alignment: .leading)
                        .padding()
                        .background(customColors.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(cardGuesses.contains(card) ? ( card == cardChoice ? Color.green : Color.red ): Color.gray.opacity(0.2), lineWidth: cardGuesses.contains(card) ? 2 : 1)
                        )
                        .padding(8)
                        .onTapGesture {
                            cardGuesses.append(card)
                            if(card == cardChoice){
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    updateCards()
                                }
                            }
                        }
                    }
                }
                .onAppear(perform:updateCards)
            }else{
                Text("you need more than one card to use quiz mode")
            }
        }
        .padding()
    }
}


