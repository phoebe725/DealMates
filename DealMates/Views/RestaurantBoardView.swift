import SwiftUI
import Combine

struct RestaurantBoardView: View {
    let restaurant: Restaurant
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var vm: PlanViewModel
    @State private var showCreatePlan = false
    @State private var selectedPlan: Plan?

    init(restaurant: Restaurant) {
        self.restaurant = restaurant
        _vm = StateObject(wrappedValue: PlanViewModel(restaurantId: restaurant.id))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if vm.isLoading && vm.plans.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.plans.isEmpty {
                    emptyBoard
                } else {
                    planList
                }
            }

            // Floating + button
            createButton
        }
        .navigationTitle(restaurant.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showCreatePlan) {
            CreatePlanView(restaurant: restaurant, planVM: vm)
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedPlan != nil },
            set: { if !$0 { selectedPlan = nil } }
        )) {
            if let plan = selectedPlan {
                PlanDetailView(plan: plan, planVM: vm)
                    .id(plan.id)
            }
        }
        .onAppear  { vm.startListening() }
        .onDisappear { vm.stopListening() }
        .alert("Error", isPresented: Binding(
            get:  { vm.errorMessage != nil },
            set:  { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Plan list

    private var planList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vm.plans) { plan in
                    PlanCardView(
                        plan: plan,
                        currentUID: authViewModel.uid,
                        onJoin:  { Task { await vm.join(plan: plan, userId: authViewModel.uid, userName: authViewModel.displayName) } },
                        onLeave: { Task { await vm.leave(plan: plan, userId: authViewModel.uid, userName: authViewModel.displayName) } },
                        onOpen:  { selectedPlan = plan }
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 10)
            .padding(.bottom, 80) // room for FAB
        }
    }

    // MARK: - Empty state

    private var emptyBoard: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.orange.opacity(0.6))
            Text("No active plans")
                .font(.headline)
            Text("Be the first to create a dining plan\nfor \(restaurant.name)!")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - FAB

    private var createButton: some View {
        Button {
            showCreatePlan = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.orange)
                .clipShape(Circle())
                .shadow(color: .orange.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 24)
        .padding(.bottom, 28)
    }
}
