//
//  PushPassApp.swift
//  PushPass
//
//  Created by Max Blanksby on 6/26/26.
//

import SwiftUI

@main
struct PushPassApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
        }
    }
}
