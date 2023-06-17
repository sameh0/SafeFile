//
//  ContentView.swift
//  SafeFile
//
//  Created by Sameh Sayed on 10/9/22.
//

import CryptoKit
import SwiftfulLoadingIndicators
import SwiftUI
import UniformTypeIdentifiers

struct MainUI: View {
    @State private var isShaking = false

    @ObservedObject var vm: MainViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            if vm.isLoading {
                LoadingIndicator(animation: .threeBallsBouncing)
            }
            VStack {
                VStack {
                    Text("Safe File")
                        .font(.largeTitle)
                    Text(!vm.inDecryptionMode ? "Encryption Mode" : "Decryption Mode")
                        .font(.title3)
                        .foregroundColor(.gray)

                    mainButton
                        .padding()
                    if vm.extremeKeyPath != nil {
                        extremeKeyButtonPath
                    }
                }

                VStack {
                    Text(vm.filePath)
                        .frame(width: 400)
                        .padding(.bottom)
                        .font(.caption)
                        .multilineTextAlignment(.center)

                    operationModes

                    if vm.fileUrl != nil {
                        withAnimation {
                            textField
                        }
                    }

                    if vm.shouldShowRealKey {
                        realKey
                    }

                    if vm.showActionButton {
                        actionButton
                    }
                }
                .disabled(vm.showStartOver)

                if vm.showStartOver {
                    startOver
                }
            }
            .animation(.spring())
            .padding(.all)
            .opacity(vm.isLoading ? 0.2 : 1)
            .disabled(vm.isLoading)
        }
        .frame(minWidth: 400, minHeight: 400)
    }

    var textField: some View {
        Group {
            if vm.operationMode == .publicKey {
                TextField("Public Key", text: $vm.encryptionKeyUrl)
                    .multilineTextAlignment(.center)
                    .frame(width: 150)
                    .disabled(vm.showStartOver)
            } else {
                TextField("Password", text: $vm.password)
                    .multilineTextAlignment(.center)
                    .frame(width: 150)
                    .disabled(vm.showStartOver)
            }
        }
    }

    var realKey: some View {
        HStack {
            if vm.inDecryptionMode {
                TextField("Decryption Key (optional)", text: $vm.realKey)
                    .disabled(vm.showStartOver)
            } else {
                Text(vm.realKey)
                    .font(.caption2)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture {
                        NSPasteboard.general.setString(vm.realKey, forType: .string)
                    }
                Spacer()
            }
        }
        .padding(.horizontal)
    }

    var operationModes: some View {
        VStack {
            Menu(vm.operationMode.name) {
                ForEach(OperationMode.allCases) { mode in
                    Button {
                        vm.operationMode = mode
                    } label: {
                        Text(mode.name)
                    }
                }
            }
            .frame(width: 150)
            if vm.operationMode == .publicKey {
                publicKeyAccessories
            }
            if vm.operationMode != .publicKey {
                Toggle("Extreme mode", isOn: Binding<Bool>(
                    get: {
                        if case let OperationMode.normal(extreme: extreme) = vm.operationMode,
                           vm.operationType == .encryption
                        {
                            return extreme
                        }
                        return false
                    },
                    set: {
                        vm.operationMode = .normal(extreme: $0)
                    }
                ))
                    .toggleStyle(.checkbox)
                    .disabled(!vm.showExtremeModeToggle)
                Text("Generates an additional file that adds an extra layer of encryption to the app  ,key file and password both required to decrypt")
                    .frame(width: 300)
                    .font(.caption)
            }
        }
    }

    var publicKeyAccessories: some View {
        VStack {
            let publicKeyMode = makeToggleBinders(.publicKey)

            if publicKeyMode.wrappedValue {
                Button("Generate Key Pair") {
                    vm.generateKeyPair()
                }
                if vm.keysReady {
                    VStack(spacing: 30) {
                        HStack {
                            KeyUI(keyType: .public, isShaking: $isShaking)
                                .onDrag {
                                    isShaking = false
                                    let key = vm.keys!.publicKey
                                    return dragBehavior(for: key, name: "publicKey")
                                }

                            KeyUI(keyType: .private, isShaking: $isShaking)
                                .onDrag {
                                    let key = vm.keys!.privateKey
                                    return dragBehavior(for: key, name: "privateKey")
                                }
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                                        self.isShaking = true
                                    }
                                }
                        }
                        VStack {
                            Image(nsImage: vm.getQRCodeDate(text: vm.keys!.privateKey.base64EncodedString())!)
                                .resizable()
                                .frame(width: 100, height: 100)
                            Text("Private Key as QR")
                                .font(.caption2)
                        }
                    }
                }
            }
        }
    }

    func dragBehavior(for key: Data, name: String) -> NSItemProvider {
        let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("safefile_keys")
        try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        let m = destinationURL.appendingPathComponent("SafeFile.\(name).txt")
        try! key.base64EncodedData().write(to: m)

        let provider = NSItemProvider(object: m as NSURL)
        provider.previewImageHandler = { (handler, _, _) -> Void in
            handler?(key as NSSecureCoding?, nil)
        }
        return provider
    }

    func makeToggleBinders(_ op: OperationMode) -> Binding<Bool> {
        Binding<Bool>(
            get: { vm.operationMode == op },
            set: { vm.operationMode = $0 ? op : .normal(extreme: false) }
        )
    }

    var actionButton: some View {
        Button {
            Task {
                await vm.inDecryptionMode ? vm.onDecrypt() : vm.onEncrypt()
            }
        } label: {
            Label(vm.inDecryptionMode ? "Decrypt" : "Encrypt", systemImage: vm.inDecryptionMode ? "lock.open" : "lock")
        }
        .padding(10)
        .background(Color.blue)
        .buttonStyle(BorderlessButtonStyle())
        .cornerRadius(10)
        .disabled(vm.showStartOver)
        .alert(vm.errorMessage, isPresented: $vm.shouldPresentError) {
            Button(role: .cancel) {} label: {
                Text("Ok")
            }
        }
    }

    var startOver: some View {
        Button {
            vm.resetUI()
        } label: {
            HStack {
                Image(systemName: "repeat")
                Text("Start Over")
            }
        }
        .padding(10)
        .background(Color.green.opacity(0.7))
        .buttonStyle(BorderlessButtonStyle())
        .cornerRadius(10)
    }

    var imageName: String {
        switch vm.operationType {
        case .encryption:
            if vm.showStartOver {
                return "lock.doc"
            } else if vm.fileUrl != nil {
                return "doc.text.image"
            }
        case .decryption:
            if vm.showStartOver {
                return "doc.text.image"
            } else if vm.fileUrl != nil {
                return "lock.doc"
            }
        }
        return "plus.circle"
    }

    var mainButton: some View {
        Image(systemName: imageName)
            .resizable()
            .imageScale(.large)
            .frame(width: vm.fileUrl != nil ? 90 : 100, height: 100)
            //            .foregroundColor(vm.fileColor)
            //            .onHover {
            //                fileColor = $0 ? .white : .blue
            //            }
            .onTapGesture {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                if panel.runModal() == .OK {
                    vm.fileUrl = panel.url
                }
            }
            .onDrop(of: ["public.url", "public.file-url"], isTargeted: nil) { items in
                guard let item = items.first,
                      let identifier = item.registeredTypeIdentifiers.first,
                      identifier == "public.url" || identifier == "public.file-url"
                else {
                    return true
                }

                if vm.showStartOver {
                    return true
                }

                print("onDrop with identifier = \(identifier)")
                item.loadItem(forTypeIdentifier: identifier, options: nil) { urlData, _ in
                    guard let urlData = urlData as? Data else {
                        return
                    }
                    let url = NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL
                    DispatchQueue.main.async {
                        vm.fileUrl = url
                    }
                }
                return true
            }
            .onDrag {
                guard let saveUrl = vm.saveUrl else { return NSItemProvider() }
                let provider = NSItemProvider(object: saveUrl as NSURL)
                provider.previewImageHandler = { (handler, _, _) -> Void in
                    let data = try? Data(contentsOf: saveUrl)
                    handler?(data as NSSecureCoding?, nil)
                }
                return provider
            }
    }

    var extremeKeyButtonPath: some View {
        Image(systemName: "key")
            .resizable()
            .imageScale(.large)
            .frame(width: 45, height: 85)
            .onDrag {
                guard let saveUrl = vm.extremeKeyPath else { return NSItemProvider() }
                let provider = NSItemProvider(object: saveUrl as NSURL)
                provider.previewImageHandler = { (handler, _, _) -> Void in
                    let data = try? Data(contentsOf: saveUrl)
                    handler?(data as NSSecureCoding?, nil)
                }
                return provider
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainUI(vm: MainViewModel(file: nil))
            .frame(width: nil, height: 400)
    }
}
