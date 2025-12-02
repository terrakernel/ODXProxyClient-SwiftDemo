//
//  Helper.swift
//  ODXProxyClient-Demo
//
//  Created by Julian Richie on 20/11/25.
//
import ODXProxyClientSwift
import Foundation

struct Company: nonisolated Codable, Sendable, Identifiable, Equatable {
    var id: Int
    var name: String
    var selected: Bool?
}

struct ConfigError: Error {}

struct ConfigSettings: nonisolated Codable, Sendable {
    var url: String
    var user_id: String
    var db: String
    var apiKey: String
    var odxApiKey: String
    var gatewayUrl: String
    var timeout: Int
    var selectedCompanies: [Int]?
    
    init(url: String, user_id: String, db: String, apiKey: String, odxApiKey: String, gatewayUrl: String, timeout: Int, selectedCompanies: [Int]?) {
        self.url = url
        self.user_id = user_id
        self.db = db
        self.apiKey = apiKey
        self.odxApiKey = odxApiKey
        self.gatewayUrl = gatewayUrl
        self.timeout = timeout
        self.selectedCompanies = selectedCompanies
    }
    
    static func fetchFromUserDefaults() throws -> ConfigSettings{
        let defaults = UserDefaults.standard
        
        func get(_ key: String) throws -> String {
            guard let value = defaults.string(forKey: key) else {
                throw ConfigError()
            }
            return value
        }
        
        let uidString = try get("uid")
//        String had to be INT
        guard let _ = Int(uidString) else { throw ConfigError() }
        
        let selectedCompanies = try? get("selected_companies")
            .split(separator:",")
            .compactMap{ Int($0.trimmingCharacters(in: .whitespaces))}
        return ConfigSettings(
            url: try get("odoo_url"),
            user_id: uidString,
            db: try get("db"),
            apiKey: try get("odoo_api_key"),
            odxApiKey: try get("odx_api_key"), gatewayUrl: try get("gateway_url"), timeout: 60, selectedCompanies: selectedCompanies)
    }
    
    func save() throws {
        guard let uid = Int(user_id) else {return}
        UserDefaults.standard.set(uid, forKey: "uid")
        if isValidURL(url), isValidURL(gatewayUrl) {
            UserDefaults.standard.set(url, forKey: "odoo_url")
            UserDefaults.standard.set(gatewayUrl, forKey: "gateway_url")
        } else {
            throw ConfigError()
        }
                
        if !apiKey.isEmpty, !odxApiKey.isEmpty, !db.isEmpty {
            UserDefaults.standard.set(apiKey, forKey: "odoo_api_key")
            UserDefaults.standard.set(odxApiKey, forKey: "odx_api_key")
            UserDefaults.standard.set(db, forKey: "db")
        } else {
            throw ConfigError()
        }
    }
    
    func initializeClient() throws {
        let instanceInfo = OdxInstanceInfo(
            url: url,
            userId: Int(user_id)!,
            db: db,
            apiKey: apiKey)
        let clientInfo = OdxProxyClientInfo(
            instance: instanceInfo,
            odxApiKey: odxApiKey,
            gatewayUrl: gatewayUrl)
        OdxProxyClient.shared.configure(with: clientInfo, timeout: 60)
    }
}



struct Product: nonisolated Codable, Identifiable, Sendable {
    let id: Int
    var name: String
    let barcode: OptionalOdxValue<String>
    var qty_available: OptionalOdxValue<Double>
    let incoming_qty: OptionalOdxValue<Double>
    let outgoing_qty: OptionalOdxValue<Double>
    let product_tag_ids: OptionalOdxValue<[Int]>
    let product_tmpl_id: OptionalOdxValue<OdxMany2One>
    let image_256: OptionalOdxValue<String>
    let type: String
    var active: Bool
}




func FetchProductsFromServer(offset: Int?) async throws -> [Product]? {
    let context = OdxClientRequestContext(
        allowedCompanyIds: [1],
        defaultCompanyId: 1,
        tz: "Asia/Jakarta")
    let keyword = OdxClientKeywordRequest(
        fields: ["id",
                 "name",
                 "qty_available",
                 "incoming_qty",
                 "outgoing_qty",
                 "product_tmpl_id",
                 "image_256",
                 "barcode",
                 "product_tag_ids",
                 "active",
                 "type"],
        order: "default_code asc",
        limit: 80,
        offset: offset ?? 0,
        context: context,
        
    )
    
    let params = OdxParams([
        [
            ["active", "=", true]
        ]
    ])
    let x: OdxServerResponse<[Product]> =  try await OdxApi.searchRead(model:"product.product", params: params, keyword:keyword)
    return x.result
}

func isValidURL(_ string: String) -> Bool {
    guard let url = URL(string: string),
          let scheme = url.scheme,
          let host = url.host,
          (scheme == "http" || scheme == "https")
    else {
        return false
    }
    return true
}
