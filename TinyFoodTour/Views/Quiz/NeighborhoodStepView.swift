import SwiftUI

struct NeighborhoodStepView: View {
    @ObservedObject var vm: QuizViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if vm.isLoadingNeighborhoods {
                HStack(spacing: 8) {
                    ProgressView().tint(Color("Radish"))
                    Text("Finding neighborhoods near you…")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
            } else if !vm.locationDenied && !vm.neighborhoodOptions.isEmpty {
                // Neighborhood pills
                FlowLayout(spacing: 8) {
                    ForEach(vm.neighborhoodOptions, id: \.name) { option in
                        PillButton(
                            label: option.name,
                            isSelected: vm.answers.neighborhood == option.name
                        ) {
                            vm.selectNeighborhood(option.name)
                        }
                    }
                }

                divider("Or, explore another city!")
                searchBar
            } else {
                searchBar
                divider("Or, explore tours in these cities")
                curatedCities
            }
        }
    }

    private var searchBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("Enter a city or zip code", text: $vm.manualQuery)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .submitLabel(.search)
                    .onSubmit { Task { await vm.searchManual() } }

                Button {
                    Task { await vm.searchManual() }
                } label: {
                    Group {
                        if vm.isSearching {
                            ProgressView().tint(.white)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 13))
                                Text("Search")
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color("Radish"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(vm.isSearching || vm.manualQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let error = vm.manualError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
        }
    }

    private var curatedCities: some View {
        FlowLayout(spacing: 8) {
            ForEach(vm.curatedCities, id: \.self) { city in
                Button {
                    Task { await vm.searchCity(city) }
                } label: {
                    Text(city.components(separatedBy: ",").first ?? city)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func divider(_ label: String) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize()
            Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1)
        }
    }
}
