//
//  ContentView.swift
//  LOAD
//
//  Created by Supachai Thawatchokthavee on 17/12/25.
//


import SwiftUI

struct ContentView: View {
  var body: some View {
    HStack(spacing: 12) {
      Text("figma.com")
        .font(Font.custom("SF Pro", size: 12).weight(.regular))
        .tracking(0.12)
        .foregroundColor(.white)
    }
    .padding(EdgeInsets(top: 9, leading: 18, bottom: 9, trailing: 18))
    .frame(height: 32)
    .background(Color(red: 0.08, green: 0.08, blue: 0.08).opacity(0.80))
    .cornerRadius(24)
    .overlay(
      RoundedRectangle(cornerRadius: 24)
        .inset(by: 0.50)
        .stroke(.white, lineWidth: 0.50)
    )
    .shadow(
      color: Color(red: 0, green: 0, blue: 0, opacity: 0.10), radius: 40, y: 2
    );
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
