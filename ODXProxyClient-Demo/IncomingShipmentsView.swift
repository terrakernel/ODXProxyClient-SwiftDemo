//
//  IncomingShipmentsView.swift
//  ODXProxyClient-Demo
//
//  Created by Julian Richie on 24/11/25.
//

import SwiftUI
import ODXProxyClientSwift

struct Picking: nonisolated Codable, Sendable, Identifiable {
    var id: Int
    var name: String
    var origin: OptionalOdxValue<String>
    var partner_id: OptionalOdxValue<OdxMany2One>
    var move_ids: [Int]
    var move_line_ids: [Int]
    var state: String

}

struct StockMove: nonisolated Codable, Sendable, Identifiable {
    var id: Int
    var product_id: OdxMany2One
    var product_tmpl_id: OdxMany2One
    var quantity: Double
    var product_uom_qty: Double
}

struct IncomingShipmentsView: View {
    @State var IncomingShipments: [Picking] = []
    @State var searchText: String = ""
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach($IncomingShipments) { $shipment in
                        NavigationLink(destination: DetailPickingView(picking: shipment)){
                            VStack(alignment:.leading) {
                                Text(shipment.name)
                                    .font(.headline)
                                Text("\(shipment.origin.value ?? "") - \(shipment.partner_id.value?.name ?? "")")
                                    .font(.caption)
                            }
                        }
                    }
                }
                if IncomingShipments.isEmpty {
                    ContentUnavailableView {
                        Label("No Incoming Shipments", systemImage: "tray.and.arrow.down.fill")
                    }
                }
                
            }
            .navigationTitle("Stock Receiving")
            .searchable(text:$searchText, placement: .automatic, prompt: Text("Any PO or picking number"))
            .onSubmit(of:.search) {
                Task.detached {
                    await findPicking()
                }
            }
        }
    }
    
    func findPicking() async {
        let context = OdxClientRequestContext(allowedCompanyIds: [1], defaultCompanyId: 1, tz: "UTC")
        let keyword = OdxClientKeywordRequest(fields: ["id", "name","partner_id","move_ids","move_line_ids","origin", "state"], order: "name asc", limit: 80, offset: 0, context: context)
        let params = OdxParams([
            [
                "|","&",
                ["name","ilike",searchText],
                ["origin","ilike", searchText],
                ["state","=","assigned"],
                ["picking_type_id.code","in", ["incoming","internal"]]
            ]
        ])
        do {
            let response: OdxServerResponse<[Picking]> = try await OdxApi.searchRead(model: "stock.picking", params: params, keyword: keyword)
            if let results = response.result {
                IncomingShipments = results
            }
        } catch let e as OdxServerErrorResponse {
            print(e)
        } catch let e {
            print(e)
        }
    }
}

struct DetailPickingView: View {
    @State var picking: Picking
    @State var moves: [StockMove] = []
    @State var displayingConfirmation = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Origin")
                    Text(picking.origin.value ?? "")
                }
                if let partner_id = picking.partner_id.value {
                    HStack {
                        Text("Partner")
                        Text(partner_id.name ?? "")
                    }
                }
                
            }
            Section("Products") {
                ForEach ($moves) { $move in
                    VStack(alignment:.leading) {
                        Text(move.product_id.name ?? "")
                            .font(.headline)
                        Divider()
                        HStack(alignment:.center) {
                            VStack {
                                Text("Requested")
                                    .font(.caption)
                                Text(String(format:"%.2f", move.product_uom_qty))
                            }.frame(maxWidth: .infinity)
                            Divider()
                            VStack {
                                Text("Delivered")
                                    .font(.caption)
                                Text(String(format:"%.2f", move.quantity))
                            }.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }.navigationTitle(picking.name)
            .task {
                await fetchStockMoves()
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button("Confirm", role:ButtonRole.confirm){
                        displayingConfirmation.toggle()
                    }.buttonStyle(.borderedProminent)
                }
            }.alert("Confirm Receiving", isPresented: $displayingConfirmation) {
                Button("Cancel", role: .cancel){}
                Button("Confirm", role: .confirm) {
                    Task.detached {
                        await confirmShipment()
                    }
                }
            }
    }
    
    func confirmShipment() async {
        // first we got to find any row that being edited; edited means the delivered qty is not the same as requested qty
        let editedQty = moves.filter { $0.quantity != $0.product_uom_qty }
        if editedQty.isEmpty {
            // all received lets just call the button_validate function
            let context = OdxClientRequestContext(allowedCompanyIds: [1], defaultCompanyId: 1, tz: "UTC")
            let keyword = OdxClientKeywordRequest(context: context)
            let params = OdxParams([[picking.id]])
            do {
                let response: OdxServerResponse<Bool> = try await OdxApi.callMethod(model:"stock.picking", functionName: "button_validate", params: params, keyword: keyword)
                if response.result != nil && response.result == true {
                    picking.state = "done"
                    dismiss()
                }
            } catch let e as OdxServerErrorResponse {
                print(e)
            } catch {
                print(error)
            }
            
        }
    }
    
    func fetchStockMoves() async {
        let context = OdxClientRequestContext(allowedCompanyIds: [1], defaultCompanyId: 1, tz: "UTC")
        let keyword = OdxClientKeywordRequest(fields: [
            "id",
            "product_id",
            "product_tmpl_id",
            "product_uom_qty",
            "quantity"
        ], order: "name asc", limit: 80, offset: 0, context: context)
        let params = OdxParams([picking.move_ids])
        do {
            let response: OdxServerResponse<[StockMove]> = try await OdxApi.read(model: "stock.move", params: params, keyword: keyword)
            if let results = response.result {
                moves = results
            }
        } catch let e as OdxServerErrorResponse {
            print(e)
        } catch let e {
            print(e)
        }
    }
}

#Preview {
    IncomingShipmentsView()
}
