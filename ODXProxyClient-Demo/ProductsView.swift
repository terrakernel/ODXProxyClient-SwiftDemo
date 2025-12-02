//
//  ProductsView.swift
//  ODXProxyClient-Demo
//
//  Created by Julian Richie on 20/11/25.
//

import SwiftUI
import ODXProxyClientSwift

struct ProductRowView: View {
    @Binding var product: Product
    
    var body: some View {
        NavigationLink(destination: DetailProductView(product: $product)) {
            VStack(alignment:.leading) {
                Text(product.name)
                    .font(.headline)
                Text("Avail: \(product.qty_available.value.map { String(format: "%.2f", $0) } ?? "-")")
                    .font(.footnote)
            }
        }
        
    }
}

struct UpdateCountQtyView: View {
    @Binding var product: Product
    @State var countedQty: String = "0.0"
    @State var showConfirmDialog: Bool = false
    var body: some View {
        VStack {
            Text(product.qty_available.value.map{String(format: "%.2f", $0)} ?? "-")
                .font(.title)
            TextField("Counted Qty", text:$countedQty)
                .keyboardType(.decimalPad)
                .font(.title)
            Button("Confirm Count"){
                showConfirmDialog = true
            }.buttonStyle(.borderedProminent)
        }.navigationTitle(product.name)
            .alert("Confirmation", isPresented: $showConfirmDialog) {
                Button("Cancel", role:.cancel){}
                Button("Confirm", role:.confirm){UpdateQuant()}
            } message: {
                Text("This Action will update the stock quant and will affect your inventory valuation")
            }
    }
    
    func UpdateQuant() {
        
    }
}


// MARK: - Detail Product View
struct DetailProductView: View {
    @Binding var product: Product
    @State var showArchiveConfirmation: Bool = false
    @State var inProgress: Bool = false
    
    var body: some View {
        ZStack {
            List {
                HStack {
                    Image(systemName: "arrowshape.up.fill")
                                .foregroundColor(.red)
                    VStack(alignment:.leading) {
                        Text("Outgoing Qty")
                            .font(.caption2)
                        Text(product.outgoing_qty.value.map {String(format: "%.2f", $0)} ?? "-")
                            .font(.title2)
                    }
                }
                HStack {
                    Image(systemName: "arrowshape.down.fill")
                                .foregroundColor(.green)
                    VStack(alignment:.leading) {
                        Text("Incoming Qty")
                            .font(.caption2)
                        Text(product.incoming_qty.value.map{ String(format: "%.2f", $0)} ?? "-")
                            .font(.title2)
                            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                HStack {
                    Image(systemName:"archivebox.fill")
                    VStack(alignment: .leading) {
                        Text("Available Qty")
                            .font(.caption2)
                        Text(product.qty_available.value.map {String(format: "%2.f", $0)} ?? "-")
                            .font(.title2)
                    }
                }
                
                
            }
            .alert("Confirm Archive",isPresented: $showArchiveConfirmation){
                Button("Confirm", role:.destructive) {
                    Task {
                        inProgress.toggle()
                        try await archiveProduct()
                        inProgress.toggle()
                    }
                }.disabled(inProgress)
                Button("Cancel", role:.cancel){showArchiveConfirmation.toggle()}.disabled(inProgress)
            }
            .navigationTitle(product.name)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("More", systemImage: "ellipsis") {
                        Button("Archive", systemImage: "archivebox", role: .destructive){showArchiveConfirmation.toggle()
                        }.buttonStyle(.borderedProminent)
                        NavigationLink(destination: UpdateCountQtyView(product: $product)) {
                            Button("Adjust Qty", systemImage: "plus.forwardslash.minus"){}
                        }.disabled(product.type == "service")
                    }
                }
            }
            
            if inProgress {
                ProgressView().progressViewStyle(.circular)
            }
        }
        
    }
    
    func archiveProduct() async throws {
        if let product_tmpl_id = product.product_tmpl_id.value?.id {
            let data: [String: Codable & Sendable] = [
                "active" : false
            ]
            let params = OdxParams(
                [
                    [product_tmpl_id],
                    data
                ]
            )
            let context = OdxClientRequestContext(tz: "UTC")
            let keyword = OdxClientKeywordRequest.init(context: context)
            do {
                let _: OdxServerResponse<Bool> = try await OdxApi.write(model: "product.template", params: params, keyword: keyword)
                product.active = false
            } catch let e as OdxServerErrorResponse {
                print(e)
            } catch let e as OdxProxyError{
                print(e)
            } catch {
                print("\(error)")
            }
        }
    }
}

struct AddNewProductView: View {
    @State var NewProductName: String = ""
    @State var NewProductBarcode: String = ""
    @State var NewProductNote: String = ""
    @State var isWorking: Bool = false
    @Binding var currentProducts: [Product]
    @Environment(\.dismiss) var dismiss
    var body: some View {
        ZStack {
            Form {
                TextField("Product Name", text: $NewProductName)
                TextField("Barcode", text: $NewProductBarcode)
                TextEditor(text: $NewProductNote)
            }
            .disabled(isWorking)
            .toolbar {
                ToolbarItem(placement:.topBarTrailing) {
                    Button("Save"){
                        Task {
                            await AddNewProductAction()
                        }
                    }.disabled(isWorking)
                }
            }
            if isWorking {
                ProgressView().progressViewStyle(.circular)
            }
            
        }.navigationTitle("New Product")
            .progressViewStyle(.circular)
        
    }
    
    @MainActor
    func AddNewProductAction() async {
        guard !NewProductName.isEmpty else {
            return
        }
        isWorking = true
        let params = OdxParams([
            [
                ["name": NewProductName, "barcode": NewProductBarcode.DefaultOrFalse, "description": NewProductNote.DefaultOrFalse]
            ]
        ])
        let context = OdxClientRequestContext(tz: "UTC")
        let keyword = OdxClientKeywordRequest(context: context)
        do {
            let _: OdxServerResponse<[Int]> = try await OdxApi.create(model: "product.template", params: params, keyword: keyword)
            let products = try await FetchProductsFromServer(offset: 0)
            if products != nil {
                currentProducts = products!
            }
            dismiss()
        } catch let e as OdxServerErrorResponse {
            print("Server error: \(e)")
        } catch {
            print("Unexpected error: \(error)")
        }
        isWorking = false
    }
}

struct ProductsView: View {
    @State var Products: [Product] = [];
    @State var ShowAddNewProduct: Bool = false
    @State var NewProductName: String = ""
    @State var NewProductBarcode: String = ""
    @State var isLoading: Bool = false
    @State var isError: Bool = false
    @State var errorMessage: String = ""
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach ($Products) { $product in
                        ProductRowView(product: $product)
                    }
                }
                if Products.isEmpty {
                    ContentUnavailableView {
                        Label("No Products", systemImage: "tray.fill")
                    }
                }
                if isLoading {
                    ProgressView()
                }
            }
            .progressViewStyle(.circular)
            .navigationTitle("Products")
            .toolbar {
                ToolbarItem(placement: .primaryAction, content: {
                        NavigationLink(destination: AddNewProductView(currentProducts:$Products)) {
                                Button("add", systemImage: "plus"){}
                            }
                        })
                ToolbarSpacer(.fixed, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction, content: {
                            Button("refresh", systemImage: "arrow.clockwise", action: {
                                Task {
                                    await fetchActiveProduct(offset: 0)
                                }
                            })
                        })
                    }
        }.task {
            if Products.isEmpty {
                await fetchActiveProduct(offset: 0)
            }
        }.alert("Error", isPresented: $isError) {
            Button("OK",role:.close){
                isError = false
                errorMessage = ""
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    func AddNewProduct() {
        NewProductName = ""
        NewProductBarcode = ""
        ShowAddNewProduct = true
    }
    
    func AddNewProductAction() {
        ShowAddNewProduct = false
    }
    
    @MainActor
    func fetchActiveProduct(offset: Int?) async {
        do {
            isLoading.toggle()
            let result = try await FetchProductsFromServer(offset: 0)
            Products = result ?? []
            isLoading.toggle()
        } catch let e as OdxProxyError {
            errorMessage = e.localizedDescription
            isError.toggle()
            isLoading.toggle()
        } catch {
            print(error)
            isLoading.toggle()
        }
        
    }
}

#Preview {
    ProductsView()
}
