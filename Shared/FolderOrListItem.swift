//
//  FolderOrListItem.swift
//  cartographer
//
//  Created by Tony Zhang on 4/21/21.
//

import SwiftUI

struct FolderOrListItem: View {
    @State var name:String
    @State var cardCount:Int?
    @State var hovering = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment:.leading){
            Text(name)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
            if(cardCount != nil){
                Text("\(String(cardCount!)) terms")
                    .font(.subheadline)
                    .foregroundColor(Color.gray)
                    .lineLimit(1)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, idealHeight:60,maxHeight:.infinity, alignment:.leading)
        .padding()
        .background(customColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5,style:.continuous)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: hovering ? (colorScheme == .light ? Color.black.opacity(0.04) : Color.black.opacity(0.6)) : Color.black.opacity(0), radius: 10, x: 0, y: 5)
        .padding(8)
        .animation(Animation.easeInOut(duration: 0.15))
        .onHover(perform: { _ in
            hovering.toggle()
        })
        
    }
}
