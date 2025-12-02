//
//  ContentView.swift
//  ODXProxyClient-Demo
//
//  Created by Julian Richie on 19/11/25.
//

import SwiftUI
import ODXProxyClientSwift

struct ContentView: View {
    
    @State var showConfigAlert: Bool = false
    @State var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ProductsView()
                .tabItem {
                    Label("Products", systemImage: "shippingbox.fill")
                }
                .tag(0)
            
            IncomingShipmentsView()
                .tabItem {
                    Label("Stock Receiving", systemImage: "tray.and.arrow.down.fill")
                }
                .tag(1)
            
            SettingsView(config: ConfigSettings(url: "", user_id: "", db: "", apiKey: "", odxApiKey: "", gatewayUrl: "", timeout: 60, selectedCompanies: []))
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .task {
            do {
                let configSettings = try ConfigSettings.fetchFromUserDefaults()
                try configSettings.initializeClient()
            } catch {
                showConfigAlert = true
            }
        }
        .alert("No Configuration", isPresented: $showConfigAlert) {
            Button("OK", role: .cancel) {
                selectedTab = 3
            }
        } message: {
            Text("No valid configuration was found please adjust your instance configuration")
        }
    }
}

#Preview {
    ContentView()
}
