//
//  ListQuizView.swift
//  Cartographer
//
//  Created by Tony Zhang on 6/1/21.
//

import SwiftUI

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


