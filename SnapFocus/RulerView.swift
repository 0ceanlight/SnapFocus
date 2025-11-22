//
//  RulerView.swift
//  SnapFocus
//
//  Created by 0ceanlight on 11/22/25.
//

import Foundation
import SwiftUI

struct RulerView: View {
    // you'll fine-tune this later — just a demo
    let segmentHeight: CGFloat = 20

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                // Repeat enough segments to feel "infinite"
                ForEach(0..<5000) { index in
                    RulerSegment(index: index)
                        .frame(height: segmentHeight)
                }
            }
        }
        .frame(width: 20)      // ~0.5 cm on most retina screens
        .background(.clear)
    }
}

struct RulerSegment: View {
    let index: Int

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.1))

            Rectangle()
                .fill(Color.white)
                .frame(width: index % 5 == 0 ? 18 : 10, height: 2)
                .offset(x: 0)
        }
    }
}
