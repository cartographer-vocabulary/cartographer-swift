//
//  CardView.swift
//  Cartographer
//
//  Created by Tony Zhang on 4/22/21.
//

import SwiftUI

struct CardView: View {
    @State var word:String
    @State var definition:String
    @State var canEdit:Bool
    @State var showingSheet = false

    @State var isDeleted = false
    @State var hovering = false

    var onDelete:() -> ()
    var onWordChange:(String) -> ()
    var onDefinitionChange:(String) -> ()
    
    @State var wordChanged = false
    @State var definitionChanged = false
    
    @Environment(\.colorScheme) var colorScheme
    
    
    #if os(macOS)
    var isMac = true
    #else
    var isMac = false
    #endif
    
    var body: some View {
        VStack(alignment:.leading){
            if(showingSheet && isMac){
                TextField("",text:$word,onEditingChanged:{_ in word = word.trimmingCharacters(in: .newlines); wordChanged = true})
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)

                TextEditor(text:$definition)
                    .padding(.horizontal,-5)
                    .onChange(of: definition, perform: { value in
                        definition = definition.trimmingCharacters(in: .newlines)
                        definitionChanged = true
                    })
                    .font(.body)
                    
                HStack{
                    Button(action:{
                        showingSheet = false
                        word = word.trimmingCharacters(in: .whitespacesAndNewlines)
                        definition = definition.trimmingCharacters(in: .whitespacesAndNewlines)
                        if(wordChanged){onWordChange(word)}
                        if(definitionChanged){onDefinitionChange(definition)}
                    },label:{
                        Image(systemName:"checkmark")
                    })
                    .frame(maxWidth:.infinity,maxHeight:.infinity)
                    .buttonStyle(PlainButtonStyle())
                    .background(Color.green)
                    .foregroundColor(customColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .onTapGesture {
                        showingSheet = false
                        word = word.trimmingCharacters(in: .whitespacesAndNewlines)
                        definition = definition.trimmingCharacters(in: .whitespacesAndNewlines)
                        if(wordChanged){onWordChange(word)}
                        if(definitionChanged){onDefinitionChange(definition)}
                    }
                    
                    Button(action:{
                        showingSheet = false
                        isDeleted = true
                    },label:{
                        Image(systemName:"trash")
                    })
                    .frame(maxWidth:.infinity,maxHeight:.infinity)
                    .buttonStyle(PlainButtonStyle())
                    .background(Color.red)
                    .foregroundColor(customColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .onTapGesture {
                        showingSheet = false
                        isDeleted = true
                        onDelete()
                    }
                }
                .frame(height:20)
                .padding(.bottom)
                .padding(.top,4)
            }else{
            Text(word)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .padding(.bottom, 1)
            Text(definition)
            Spacer()
            }
            
            #if os(iOS)
            EmptyView()
            .sheet(isPresented: $showingSheet, content: {
                CardEditSheet(showingSheet:$showingSheet, word:$word, definition:$definition,onDelete:onDelete,onWordChange:onWordChange,onDefinitionChange:onDefinitionChange)
            })
            #endif
        }
        .padding(.top).padding(.leading).padding(.trailing)
        .frame(maxWidth: .infinity, idealHeight:showingSheet && isMac ? nil : 150,maxHeight:.infinity, alignment:.leading)
        .animation(Animation.easeInOut(duration:0.2))
        .background(customColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: hovering ? (colorScheme == .light ? Color.black.opacity(0.04) : Color.black.opacity(0.6)) : Color.black.opacity(0), radius: 10, x: 0, y: 5)
        .onHover(perform: { hover in
            hovering = hover
        })
        .padding(8)
        .onTapGesture {
            if(canEdit){
                showingSheet = true
            }
        }
        
    }
}
struct CardEditSheet:View {
    @Binding var showingSheet:Bool
    @Binding var word:String
    @Binding var definition:String
    @State var wordChanged = false
    @State var isDeleted = false
    @State var definitionChanged = false
    var onDelete:() -> ()
    var onWordChange:(String) -> ()
    var onDefinitionChange:(String) -> ()
    
    var body: some View {
        VStack{
            TextField("",text:$word,onEditingChanged:{_ in word = word.trimmingCharacters(in: .newlines); wordChanged = true})
                .textFieldStyle(PlainTextFieldStyle())
                .padding(6)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5,style:.continuous)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .font(.title3)
            TextEditor(text:$definition)
                .frame(maxHeight:100)
                .padding(2)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5,style:.continuous)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .onChange(of: definition, perform: { value in
                    definition = definition.trimmingCharacters(in: .newlines)
                    definitionChanged = true
                })
            
            HStack{
                Button(action:{
                    showingSheet = false
                    
                },label:{
                    Image(systemName:"checkmark")
                })
                .frame(maxWidth:.infinity,maxHeight:.infinity)
                .buttonStyle(PlainButtonStyle())
                .padding(5)
                .background(Color.green)
                .foregroundColor(customColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .onTapGesture {
                    showingSheet = false
                }
                
                Button(action:{
                    showingSheet = false
                    isDeleted = true
                },label:{
                    Image(systemName:"trash")
                })
                .frame(maxWidth:.infinity,maxHeight:.infinity)
                .buttonStyle(PlainButtonStyle())
                .padding(5)
                .background(Color.red)
                .foregroundColor(customColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .onTapGesture {
                    showingSheet = false
                    isDeleted = true
                }
            }
            .frame(height:40)
        }
        .frame(minWidth:300,minHeight:180)
        .padding()
        .onDisappear(perform: {
            word = word.trimmingCharacters(in: .whitespacesAndNewlines)
            definition = definition.trimmingCharacters(in: .whitespacesAndNewlines)
            if(isDeleted){onDelete(); return}
            if(wordChanged){onWordChange(word)}
            if(definitionChanged){onDefinitionChange(definition)}
        })
    }
}
