//
//  FlashcardView.swift
//  cartographer
//
//  Created by Tony Zhang on 4/18/21.
//

import SwiftUI


struct FlashcardView: View {
    @Binding var cards: [[String:String]]
    @State var flipped = false
    @State var cardIndex = 0
    @Environment(\.colorScheme) var colorScheme
    @ViewBuilder func card() -> some View{
        ZStack{
            Text(cards.indices.contains(cardIndex) ? (cards[cardIndex]["word"] ?? "Placeholder") : "Placeholder")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
                .opacity(flipped ? -1 : 1)

            Text(cards.indices.contains(cardIndex) ? (cards[cardIndex]["definition"] ?? "Placeholder") : "Placeholder")
                .rotation3DEffect(Angle(degrees: 180), axis: (x: CGFloat(180), y: CGFloat(0), z: CGFloat(0)))
                .padding()
                .opacity(flipped ? 1 : -1)
        }
        .frame(minWidth: 0, maxWidth: 400 , minHeight: 250, maxHeight: .infinity, alignment: .center)
        .background(customColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: colorScheme == .light ? Color.black.opacity(0.1) : Color.black.opacity(0.6), radius: 10, x: 0, y: flipped ? -5 : 5)
        .rotation3DEffect(self.flipped ? Angle(degrees: 180): Angle(degrees: 0), axis: (x: CGFloat(180), y: CGFloat(0), z: CGFloat(0)))
    }
    var body: some View {
        VStack{
            #if !os(macOS)
            card()
                .onTapGesture {
                    withAnimation(Animation.easeInOut){
                        flipped.toggle()
                    }
                }
                .padding()
                .padding(6)
            #else
            card()
                .onHover(perform: {_ in
                    withAnimation(Animation.easeInOut.delay(0.2)){
                                flipped.toggle()
                            }
                })
                .padding()
            #endif
            HStack{
                Button(action: {
                    if cardIndex > 0 {
                        if(flipped){
                            withAnimation(Animation.easeInOut){flipped = false}
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                cardIndex -= 1;
                            }
                        }else{
                            cardIndex -= 1;
                        }
                    }
                    if cardIndex <= 0 {cardIndex = 0}
                    if cards.count <= cardIndex + 1 {cardIndex = cards.count - 1}
                }, label: {
                    Image(systemName: "arrow.left")
                })
                .disabled(cardIndex <= 0).buttonStyle(PlainButtonStyle())
                Text("\(cardIndex+1) / \(cards.count)")
                Button(action: {
                    if cards.count > cardIndex+1 {
                        if(flipped){
                            withAnimation(Animation.easeInOut){flipped = false}
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                cardIndex += 1;
                            }
                        }else{
                            cardIndex += 1;
                        }
                    }
                    if cardIndex <= 0 {cardIndex = 0}
                    if cards.count <= cardIndex + 1 {cardIndex = cards.count - 1}
                }, label: {
                    Image(systemName: "arrow.right")
                })
                .disabled(cards.count <= cardIndex+1).buttonStyle(PlainButtonStyle())
            }.onChange(of: cards) { _ in
                if cardIndex <= 0 {cardIndex = 0}
                if cards.count <= cardIndex + 1 {cardIndex = cards.count - 1}
            }
        }
    }
}
