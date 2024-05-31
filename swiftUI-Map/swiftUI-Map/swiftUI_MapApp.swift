//
//  swiftUI_MapApp.swift
//  swiftUI-Map
//
//  Created by zluof on 2024/5/30.
//

import SwiftUI

@main
struct swiftUI_MapApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
