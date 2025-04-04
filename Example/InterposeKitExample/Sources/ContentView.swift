import SwiftUI

struct ContentView: View {
    
    // ============================================================================ //
    // MARK: Configuration
    // ============================================================================ //
    
    let onHookToggled: (HookExample, Bool) -> Void
    let onWindowTitleChanged: (String) -> Void

    // ============================================================================ //
    // MARK: State
    // ============================================================================ //
    
    @State
    private var hookStates = Dictionary(
        uniqueKeysWithValues: HookExample.allCases.map { ($0, false) }
    )
    
    @State
    private var windowTitle = "InterposeKit Example"
    
    // ============================================================================ //
    // MARK: View Body
    // ============================================================================ //
    
    var body: some View {
        VStack {
            Form {
                Section("Hooks") {
                    ForEach(HookExample.allCases, id: \.self) { example in
                        let isOn = Binding(
                            get: { self.hookStates[example] ?? false },
                            set: { newValue in
                                self.hookStates[example] = newValue
                                self.onHookToggled(example, newValue)
                            }
                        )
                        
                        LabeledContent {
                            Toggle("", isOn: isOn)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .padding(.leading, 20)
                        } label: {
                            Group {
                                Text(example.selector)
                                    .monospaced()
                                
                                Text(example.description)
                                    .font(.subheadline)
                            }
                            .opacity(example == .NSColor_controlAccentColor ? 0.5 : 1)
                        }
                        .disabled(example == .NSColor_controlAccentColor)
                    }
                }
            }
            .formStyle(.grouped)
            
            LabeledContent("Window Title:") {
                TextField("", text: self.$windowTitle)
                    .onSubmit {
                        self.onWindowTitleChanged(self.windowTitle)
                    }
                
                Button {
                    self.onWindowTitleChanged(self.windowTitle)
                } label: {
                    Text("Set").padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .fixedSize()
        .onAppear {
            self.onWindowTitleChanged(self.windowTitle)
        }
    }
    
}
