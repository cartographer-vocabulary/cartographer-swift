//
//  colors.swift
//  Cartographer
//
//  Created by Tony Zhang on 5/14/21.
//

import Foundation
import SwiftUI

#if os(macOS)
struct customColors {
    static var backgroundPrimary = Color(NSColor.controlBackgroundColor)
    static var backgroundSecondary =  Color(NSColor.controlBackgroundColor)
}
#else
struct customColors {
    static var backgroundPrimary = Color(UIColor.systemBackground)
    static var backgroundSecondary =  Color(UIColor.secondarySystemGroupedBackground)
}
#endif
