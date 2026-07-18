//
//  LazyViewModel.swift
//  FuelingUI
//

#if canImport(SwiftUI)
import Foundation
import Observation
import SwiftUI

/// Creates a view model once per view identity and injects it into content.
internal struct LazyViewModel<ViewModel: Observable, Content: View>: View {

    let viewModel: (() -> ViewModel)

    let content: ((ViewModel) -> Content)

    init(
        viewModel: @autoclosure @escaping () -> ViewModel,
        content: @escaping (ViewModel) -> Content
    ) {
        self.viewModel = viewModel
        self.content = content
    }

    @State
    private var stateWrapper = StateWrapper()

    var body: some View {
        if let viewModel = stateWrapper.viewModel {
            content(viewModel)
        } else {
            ProgressView()
                .onAppear {
                    if stateWrapper.viewModel == nil {
                        stateWrapper.viewModel = self.viewModel()
                    }
                }
        }
    }
}

private extension LazyViewModel {

    @MainActor
    @Observable
    final class StateWrapper {

        var viewModel: ViewModel?
    }
}
#endif
