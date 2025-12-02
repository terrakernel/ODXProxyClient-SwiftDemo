//
//  OutgoingShipmentsView.swift
//  ODXProxyClient-Demo
//
//  Created by Julian Richie on 24/11/25.
//

import SwiftUI

struct OutgoingShipmentsView: View {
    @State var OutgoingShipments: [Picking] = []
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach($OutgoingShipments) { $shipment in
                        Text(shipment.name)
                    }
                }
                if OutgoingShipments.isEmpty {
                    ContentUnavailableView {
                        Label("No Outgoing Shipments", systemImage: "tray.and.arrow.up.fill")
                    }
                }
                
            }.navigationTitle("Incoming Shipments")
        }
    }
}

#Preview {
    OutgoingShipmentsView()
}
