//
//  SwiftUIView.swift
//  ODXProxyClient-Demo
//
//  Created by Julian Richie on 24/11/25.
//

import SwiftUI
import ODXProxyClientSwift


struct SettingsView: View {
    
    @State var url: String = ""
    @State var user_id: String = ""
    @State var api_key: String = ""
    @State var gateway_url: String = "https://gateway.odxproxy.io/"
    @State var odx_api_key: String = ""
    @State var db: String = ""
    
    @State var config: ConfigSettings;
    
    @State var showOdooAPIKeyChar: Bool = false
    @State var showOdxAPIKeyChar: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Odoo instance url", text: $config.url)
                        .keyboardType(.URL)
                    TextField("Odoo User ID", text: $config.user_id)
                        .keyboardType(.numberPad)
                    TextField("Database", text: $config.db)
                    HStack {
                        if (showOdooAPIKeyChar) {
                            TextField("Odoo Api Key", text: $config.apiKey)
                        } else {
                            SecureField("Odoo Api Key", text: $config.apiKey)
                        }
                        Button(
                            action: {
                                        showOdooAPIKeyChar.toggle()
                                    }) {
                                        Image(systemName: showOdooAPIKeyChar ? "eye.slash" : "eye")
                                            .foregroundColor(.gray)
                                    }
                    }
                }
                Section {
                    TextField("Odx Gateway URL", text: $config.gatewayUrl).keyboardType(.URL)
                    HStack {
                        if (showOdxAPIKeyChar) {
                            TextField("Odx API Key", text: $config.odxApiKey)
                        } else {
                            SecureField("Odx API Key", text: $config.odxApiKey)
                        }
                        Button(
                            action: {
                                        showOdxAPIKeyChar.toggle()
                                    }) {
                                        Image(systemName: showOdxAPIKeyChar ? "eye.slash" : "eye")
                                            .foregroundColor(.gray)
                                    }
                    }
                    
                }
                Section("Company") {
                    NavigationLink(destination: SelectCompany(selectedCompanies:config.selectedCompanies ?? [])) {
                        Text("Some");
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                    ToolbarItem(placement:.topBarTrailing) {
                        Button("Save & Reload") {
                            SaveSettings()
                        }
                    }
                }
        }.task {
            do {
                config = try ConfigSettings.fetchFromUserDefaults()
            } catch {
                config = ConfigSettings(url: "", user_id: "", db: "", apiKey: "", odxApiKey: "", gatewayUrl: "", timeout: 0, selectedCompanies: [])
            }
            
        }
    }
    
    func SaveSettings() {
        do {
            try config.save()
            reloadOdxClient()
        } catch {
            print(error)
        }
    }
    
    func loadSettings() {
        user_id = UserDefaults.standard.string(forKey: "uid") ?? ""
        url = UserDefaults.standard.string(forKey: "odoo_url") ?? ""
        gateway_url = UserDefaults.standard.string(forKey: "gateway_url") ?? "https://gateway.odxproxy.io/"
        api_key = UserDefaults.standard.string(forKey: "odoo_api_key") ?? ""
        odx_api_key = UserDefaults.standard.string(forKey: "odx_api_key") ?? ""
        db = UserDefaults.standard.string(forKey: "db") ?? ""
    }
    func reloadOdxClient() {
        let instanceInfo = OdxInstanceInfo(url: url, userId: Int(user_id) ?? 0, db: db, apiKey: api_key)
        let clientInfo = OdxProxyClientInfo(instance: instanceInfo, odxApiKey: odx_api_key, gatewayUrl: gateway_url)
        OdxProxyClient.shared.configure(with: clientInfo, timeout: 60)
    }
    
}

struct SelectCompany: View {
    @State var selectedCompanies: [Int] = []
    @State var Companies: [Company] = []
    @State var isLoading: Bool = false
    var body: some View {
        ZStack {
            List {
                ForEach($Companies) {$company in
                    HStack {
                        Button(company.name) {
                            if company.selected == nil {
                                company.selected = true
                                let filteredCompanies = Companies.filter { $0.selected ?? false }.map{$0.id}
                                UserDefaults.standard.set(
                                    filteredCompanies.map(String.init)
                                        .joined(separator: ","),
                                    forKey: "selected_companies")
                            } else {
                                company.selected?.toggle()
                            }
                        }
                        if company.selected ?? false {
                            Text("V")
                        }
                    }
                }
            }.task {
                await fetchAllCompanies()
            }.navigationTitle("Companies")
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Fetching please wait").font(.caption)
                }
                
            }
        }
    }
    
    func fetchAllCompanies() async {
        let context = OdxClientRequestContext(tz: "Asia/Singapore")
        let params: OdxParams = OdxParams([])
        let keyword = OdxClientKeywordRequest(context: context)
        do {
            isLoading.toggle()
            let response: OdxServerResponse<[Company]> = try await OdxApi.searchRead(model: "res.company", params: params, keyword: keyword)
            if var _companies = response.result {
                let ids = Set(selectedCompanies)
                for i in 0..<_companies.count {
                    if ids.contains(_companies[i].id) {
                        _companies[i].selected = true
                    }
                }
                Companies = _companies
            }
            isLoading.toggle()
        } catch let e as OdxServerErrorResponse {
            print(e)
            isLoading.toggle()
        } catch {
            print(error)
            isLoading.toggle()
        }
        
    }
}

#Preview {
    SettingsView(config: ConfigSettings(url: "", user_id: "", db: "", apiKey: "", odxApiKey: "", gatewayUrl: "", timeout: 60, selectedCompanies: []))
}
