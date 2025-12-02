# ODXProxyClient-Demo

A SwiftUI demo app showcasing how to connect Apple platforms to an Odoo backend via the ODX Proxy Gateway using the ODXProxyClientSwift package. The app demonstrates:

- Configuring the ODX client at runtime (instance URL, DB, user, API keys, gateway URL)
- Searching and reading Odoo models with strongly-typed Codable models
- Viewing and confirming incoming shipments (stock.picking) and reading related stock moves
- Selecting allowed companies and persisting settings locally


## Features

- SwiftUI UI targeting multiple Apple platforms
- Async/await networking with strict Sendable types
- Type-safe Odoo field helpers:
  - OdxMany2One for many2one fields
  - OptionalOdxValue<T> for Odoo’s null/false semantics
  - OdxParams for dynamic JSON parameters
- Simple settings persistence via UserDefaults
- Examples of common Odoo operations:
  - search, search_read, read, write/update, call_method, remove, fields_get

## Screens

- Settings
  - Enter Odoo URL, DB, User ID, Odoo API Key
  - Enter Gateway URL and ODX API Key
  - Select Companies
  - Save & Reload to reconfigure the client
- Incoming Shipments
  - Search stock.picking by name/origin
  - Filtered to assigned state and picking type (incoming/internal)
  - View detail with product lines and quantities
  - Confirm receiving (button_validate)

## Requirements

- Xcode 16 or newer (Swift 6+)
- Apple platforms:
  - iOS 15+, iPadOS 15+
  - macOS 12+
  - tvOS 15+
  - watchOS 8+
  - visionOS 1+
  - macCatalyst 15+
- An accessible Odoo instance and ODX Proxy Gateway:
  - Odoo URL
  - Database name
  - Odoo User ID
  - Odoo API Key
  - ODX API Key
  - ODX Gateway URL

## Project Structure

- ODXProxyClientSwift (Swift Package)
  - OdxApi.swift: High-level API for Odoo RPC actions (search, search_read, read, write, remove, fields_get, call_method)
  - OdxModels.swift: Shared models and helpers (OdxParams, OdxServerResponse, OdxMany2One, OptionalOdxValue, request structs)
- App/Demo
  - SettingsView.swift: UI for configuring the client and selecting companies
  - IncomingShipmentsView.swift: UI for searching and viewing stock pickings, viewing stock moves, and confirming receiving
  - Helper.swift: ConfigSettings and Product examples, product fetching, URL validation

## Setup

1. Open the project in Xcode.
2. Build the ODXProxyClientSwift package (included in this repo).
3. Run the app on your target platform.
4. Go to Settings:
   - Odoo instance URL: e.g. https://odoo.example.com
   - Odoo User ID: numeric user ID in that database
   - Database: Odoo database name
   - Odoo API Key: API key for the user
   - ODX Gateway URL: e.g. https://gateway.odxproxy.io/
   - ODX API Key: key provisioned for your ODX gateway
   - Optionally select companies
   - Tap “Save & Reload”
5. Navigate to “Stock Receiving” and search for incoming/internal pickings.

Settings are saved in UserDefaults with the following keys:
- uid (Int)
- odoo_url (String)
- db (String)
- odoo_api_key (String)
- gateway_url (String)
- odx_api_key (String)
- selected_companies (comma-separated Ints)

## How It Works

- Configuration:
  - ConfigSettings.save() validates URLs and persists values to UserDefaults.
  - ConfigSettings.initializeClient() and SettingsView.reloadOdxClient() configure OdxProxyClient.shared with OdxProxyClientInfo and OdxInstanceInfo.
- Networking:
  - OdxApi methods build OdxClientRequest and post through OdxProxyClient (shared singleton) to the ODX gateway.
  - OdxParams provides a dynamic JSON structure for Odoo’s flexible RPC payloads.
  - Responses are decoded into OdxServerResponse<T> with optional error payloads.
- Data Models:
  - OptionalOdxValue<T> decodes Odoo fields that may be null or false as nil.
  - OdxMany2One decodes many2one fields as an optional id/name pair.
- Concurrency:
  - Models conform to Sendable.
  - API functions are async and use async/await.
  - Some calls are made in Task.detached; UI updates occur on main thread.

## Example Calls

- Search/Read Products:
  - See Helper.swift → FetchProductsFromServer(offset:)
- Search/Read Pickings:
  - IncomingShipmentsView.findPicking()
- Read Stock Moves:
  - DetailPickingView.fetchStockMoves()
- Confirm a Picking:
  - DetailPickingView.confirmShipment() calling button_validate via OdxApi.callMethod

## License

MIT License © 2025 TERRAKERNEL. PTE. LTD — Author: julian richie wajong

See the LICENSE file for full text.
