//
//  DashboardView.swift
//  CoughTracking-IOS
//
//  Created by Ali Rizwan on 22/08/2023.
//

import SwiftUI
import CoreData


struct DashboardView: View {
    
    @FetchRequest(entity: CoughTrackingHours.entity(), sortDescriptors: []) var coughTrackingHoursFetchResult: FetchedResults<CoughTrackingHours>
    @FetchRequest(entity: Cough.entity(), sortDescriptors: []) var coughFetchResult: FetchedResults<Cough>
    
    @State var allCoughList:[Cough] = []
    
    
    @EnvironmentObject var networkManager: NetworkManager
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject var dashboardVM = DashboardVM()
    @State var showScheduleSheet = false
    @State var showMicStopSheet = false
    @State var showSyncDataSheet = false
    @State var isAnalyticsMode = false
    
    
    @State var selectedDayIndex = 0
    @GestureState var gestureOffset: CGFloat = 0
    
    @State var totalCoughCount:Int = 0
    @State var totalTrackedHours:Double = 0.0
    @State var coughsPerHour:Int = 0
    
    
    var body: some View {
        
        ZStack {
            
            
            VStack{
                
                HomeTopBar(dashboardVM: dashboardVM, showScheduleSheet:$showScheduleSheet)
                
                
                
                HStack(spacing: 0) {
                    ForEach(0..<Constants.tabList.count, id: \.self) { index in
                        Button {
                            withAnimation {
                                selectedDayIndex = index
                            }
                        } label: {
                            Text(Constants.tabList[index])
                                .foregroundColor(selectedDayIndex == index ? Color.white : Color.gray)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 18)
                        }
                    }
                }
                .background(
                    BubbleView(selectedIndex: selectedDayIndex, tabCount: Constants.tabList.count)
                )
                .padding(.vertical, 10)
                
                Group{
                    if selectedDayIndex == 0 {
                        
                        HourlyCoughsView(totalCoughCount: $totalCoughCount, totalTrackedHours: $totalTrackedHours, coughsPerHour: $coughsPerHour, allCoughList: $allCoughList)
                            .environment(\.managedObjectContext, viewContext)
                            .id(1)
                        
                    } else if selectedDayIndex == 1 {
                        
                        DailyCoughsView(totalCoughCount: $totalCoughCount, totalTrackedHours: $totalTrackedHours, coughsPerHour: $coughsPerHour, allCoughList: $allCoughList)
                            .id(2)
                        
                    } else {
                        
                        WeeklyCoughsView(totalCoughCount: $totalCoughCount, totalTrackedHours: $totalTrackedHours, coughsPerHour: $coughsPerHour)
                            .id(3)
                    }
                    
                }
                
                CustomTabView(dashboardVM: dashboardVM, showMicSheet: $showMicStopSheet)
                    .environmentObject(networkManager)
                
                
            }
            .edgesIgnoringSafeArea(.bottom)
            .background(Color.screenBG)
            .gesture(
                DragGesture()
                    .updating($gestureOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        withAnimation {
                            
                            let threshold = UIScreen.main.bounds.width / CGFloat(Constants.tabList.count + 1)
                            
                            if value.translation.width > threshold {
                                selectedDayIndex = max(0, selectedDayIndex - 1)
                            } else if -value.translation.width > threshold {
                                selectedDayIndex = min(Constants.tabList.count - 1, selectedDayIndex + 1)
                            }
                            
                        }
                    }
            )
            
            
            
            
        }.environment(\.managedObjectContext,viewContext)
            .navigationBarBackButtonHidden()
            .sheet(isPresented: $showScheduleSheet) {
                
                ScheduleMonitoringBottomSheet()
                    .presentationDetents([.medium])
                    .presentationCornerRadius(35)
                
            }.sheet(isPresented: $showMicStopSheet) {
                
                MicStopBottomSheet()
                    .presentationDetents([.height(100)])
                    .presentationCornerRadius(35)
                
            }.sheet(isPresented: $showSyncDataSheet) {
                
                SyncDataBottomSheet()
                    .presentationDetents([.height(170)])
                    .presentationCornerRadius(35)
                
            }.onAppear{
                
                calculateTotalCoughHours()
                dashboardVM.startRecording()
                
                
                
            }.onReceive(dashboardVM.$saveCough, perform:  { i in
                
                if(i){
                    
                    saveCough()
                    
                }
                
                
            }).onReceive(dashboardVM.$isRecording, perform:  { i in
                
                if(!i){
                    
                    saveTrackedHours()
                    
                }
                
                
            })
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange)) { _ in
                
                allCoughList =  Array(coughFetchResult)
                totalCoughCount = allCoughList.count
                calculateTotalCoughHours()
                
            }
    }
    
    func calculateTotalCoughHours(){
        
        totalTrackedHours = 0
        coughsPerHour = 0
        
        for trackingHours in coughTrackingHoursFetchResult {
            
            let hour = trackingHours.hoursTrack
            totalTrackedHours += hour
            
        }
        
        print("fff",totalTrackedHours,"------",coughTrackingHoursFetchResult.count)
        
        if(totalTrackedHours > 1 && coughsPerHour > 1){
            
            coughsPerHour = totalCoughCount / Int(totalTrackedHours)
            
        }else{
            
            coughsPerHour = 0
            
        }
    }
    
    func saveCough(){
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        
        let currentDate = Date()
        
        let dateString = dateFormatter.string(from: currentDate)
        
        
        dateFormatter.dateFormat = "HH:mm:ss"
        
        let timeString = dateFormatter.string(from: currentDate)
        
        
        let cough = Cough(context: viewContext)
        
        cough.id = DateUtills.getCurrentTimeInMilliseconds()
        cough.date = dateString
        cough.time = timeString
        cough.coughSegments = dashboardVM.segments
        cough.coughPower = dashboardVM.coughPower
        
        do {
            try viewContext.save()
            print("saved")
            
            dashboardVM.segments = []
            dashboardVM.coughPower = ""
            
            
        } catch {
            // Handle the error
            print("Error saving data: \(error.localizedDescription)")
        }
        
    }
    
    
    func saveTrackedHours(){
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        
        let currentDate = Date()
        
        let dateString = dateFormatter.string(from: currentDate)
        
        
        let coughTrackingHours = CoughTrackingHours(context: viewContext)
        
        
        coughTrackingHours.date = dateString
        coughTrackingHours.hoursTrack = dashboardVM.totalHoursRecordedToday
        
        do {
            
            try viewContext.save()
            print("savedTrackedHours")
            
            
            
        } catch {
            // Handle the error
            print("Error saving data: \(error.localizedDescription)")
        }
        
    }
    
    
    
}



struct CustomTabView:View{
    
    @EnvironmentObject var networkManager: NetworkManager
    @StateObject var dashboardVM : DashboardVM
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var showMicSheet:Bool
    
    var body: some View{
        
        VStack {
            
            Button(action: {
                
                withAnimation {
                    
                    showMicSheet.toggle()
                    
                }
                
            }, label: {
                
                VStack{
                    
                    Image("microphone")
                    
                }.frame(width: 48,height: 48)
                    .background(Color.appColorBlue)
                    .cornerRadius(24)
                
                
                
                
            }).padding(.bottom,-30)
            
            ZStack {
                
                Image("bottom_bar_bg")
                    .resizable()
                    .frame(width: UIScreen.main.bounds.width,height: 91)
                
                HStack {
                    
                    Spacer()
                    
                    NavigationLink {
                        
                        ProfileSettingsView(dashboardVM: dashboardVM)
                            .environmentObject(networkManager)
                            .environment(\.managedObjectContext, viewContext)
                        
                    } label: {
                        
                        Image("user-avatar")
                        
                    }
                    
                    Spacer()
                    
                    
                    
                    
                    Spacer()
                    
                    NavigationLink {
                        
                        UserReportView()
                        
                    } label: {
                        Image("analytics")
                    }
                    
                    Spacer()
                    
                }
            }
            
            
            
            
        }
        
        
        
        
    }
    
    
}



struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}

struct HomeTopBar: View {
    
    
    @ObservedObject  var dashboardVM:DashboardVM
    
    @Binding var showScheduleSheet:Bool
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        HStack{
            
            Button {
                
                showScheduleSheet = true
                
            } label: {
                
                Image("calendar")
                
            }
            
            
            Button {
                
                
            } label: {
                
                Image("reload")
                
            }.padding(.leading)
            
            
            Spacer()
            
            Text("Coughs")
                .foregroundColor(Color.appColorBlue)
                .modifier(LatoFontModifier(fontWeight: .bold, fontSize: 20))
                .padding(.leading,-16)
            
            Spacer()
            
            NavigationLink {
                
                NotesView()
                    .environment(\.managedObjectContext, viewContext)
                    .onAppear{
                        dashboardVM.stopRecording()
                    }
                
            } label: {
                
                HStack{
                    
                    Image("list")
                        .resizable()
                        .frame(width: 16,height: 16)
                        .padding(.leading,3)
                    
                    
                    HStack{
                        
                        Image("analytics")
                            .resizable()
                            .frame(width: 16,height: 16)
                        
                    }.frame(width: 27,height: 27)
                        .background(Color.white)
                        .cornerRadius(24)
                    
                }
                .frame(width: 60,height: 33)
                .background(Color.appColorBlue)
                .cornerRadius(50)
                
                
            }
            
            
            
            
        }.padding(.horizontal)
    }
}


struct ScheduleMonitoringBottomSheet:View{
    
    @State var currentHourFormatted = ""
    @State var currentHour: Int = Calendar.current.component(.hour, from: Date())
    @State var currentMinute: Int = Calendar.current.component(.minute, from: Date())
    
    
    @State var fromSelectedHour = 0
    @State var fromSelectedMin = 0
    @State var fromSelectedAM = 0
    
    
    @State var toSelectedHour = 0
    @State var toSelectedMin = 0
    @State var toSelectedAM = 0
    
    
    @State var isDayOn = false
    @State var isNightOn = false
    
    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh"
        return formatter
    }
    
    var amPmFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter
    }
    
    var body: some View{
        
        VStack{
            
            Color.black
                .frame(width: 40,height: 3)
                .cornerRadius(2)
            
            
            HStack{
                
                Spacer()
                
                Text("Schedule Cough Monitoring")
                    .modifier(LatoFontModifier(fontWeight: .bold, fontSize: 20))
                
                
                Spacer()
                
                Button {
                    
                    
                    
                } label: {
                    
                    Text("Save")
                        .modifier(LatoFontModifier(fontWeight: .bold, fontSize: 16))
                    
                    
                }.padding(.trailing)
                
                
                
                
                
            }
            
            HStack{
                
                Picker("", selection: $fromSelectedHour) {
                    
                    ForEach(1..<13){ i in
                        
                        
                        Text(String(format: "%0\(2)d", i))
                            .modifier(LatoFontModifier(fontWeight: .bold, fontSize:16))
                        
                        
                        
                    }
                    
                }.pickerStyle(.wheel)
                    .frame(height: 100)
                    .onAppear{
                        
                        currentHourFormatted = timeFormatter.string(from: Date())
                        fromSelectedHour = Int(currentHourFormatted) ?? 1
                        fromSelectedHour-=1
                    }
                
                
                Text(":")
                    .foregroundColor(.black)
                    .modifier(LatoFontModifier(fontWeight: .medium, fontSize: 16))
                
                Picker("", selection: $fromSelectedMin) {
                    
                    ForEach(1..<60){ i in
                        
                        Text(String(format: "%0\(2)d", i))
                            .modifier(LatoFontModifier(fontWeight: .bold, fontSize:16))
                        
                        
                    }
                    
                }.pickerStyle(.wheel)
                    .frame(height: 100)
                    .onAppear{
                        
                        fromSelectedMin = currentMinute
                        
                    }
                
                Picker("", selection: $fromSelectedAM) {
                    
                    ForEach(0..<2){ i in
                        
                        Text(String(i == 0 ? "AM" : "PM" ))
                            .modifier(LatoFontModifier(fontWeight: .bold, fontSize:16))
                        
                        
                    }
                    
                }.pickerStyle(.wheel)
                    .frame(height: 100)
                    .onAppear{
                        
                        currentHourFormatted = amPmFormatter.string(from: Date())
                        fromSelectedAM = currentHourFormatted == "AM" ? 0 : 1
                        
                    }
                
                
            }.padding(.top)
            
            Text("to")
                .foregroundColor(.black)
                .modifier(LatoFontModifier(fontWeight: .medium, fontSize: 16))
            
            HStack{
                
                Picker("", selection: $toSelectedHour) {
                    
                    ForEach(1..<13){ i in
                        
                        Text(String(format: "%0\(2)d", i))
                            .modifier(LatoFontModifier(fontWeight: .bold, fontSize:16))
                        
                        
                    }
                    
                }.pickerStyle(.wheel)
                    .frame(height: 100)
                    .onAppear{
                        
                        currentHourFormatted = timeFormatter.string(from: Date())
                        toSelectedHour = Int(currentHourFormatted) ?? 1
                        toSelectedHour-=1
                        
                    }
                
                
                Text(":")
                    .foregroundColor(.black)
                    .modifier(LatoFontModifier(fontWeight: .medium, fontSize: 16))
                
                Picker("", selection: $toSelectedMin) {
                    
                    ForEach(1..<60){ i in
                        
                        Text(String(format: "%0\(2)d", i))
                            .modifier(LatoFontModifier(fontWeight: .bold, fontSize:16))
                        
                        
                    }
                    
                }.pickerStyle(.wheel)
                    .frame(height: 100)
                    .onAppear{
                        
                        toSelectedMin = currentMinute
                        
                    }
                
                Picker("", selection: $toSelectedAM) {
                    
                    ForEach(0..<2){ i in
                        
                        Text(String(i == 0 ? "AM" : "PM" ))
                            .modifier(LatoFontModifier(fontWeight: .bold, fontSize:16))
                        
                        
                    }
                    
                }.pickerStyle(.wheel)
                    .frame(height: 100)
                    .onAppear{
                        
                        currentHourFormatted = amPmFormatter.string(from: Date())
                        toSelectedAM = currentHourFormatted == "AM" ? 0 : 1
                        
                    }
                
                
                
            }
            
            
            Spacer()
            
            
            Toggle(isOn: $isDayOn) {
                
                Text("Day")
                    .foregroundColor(.black)
                    .modifier(LatoFontModifier(fontWeight: .bold, fontSize: 18))
                
            }.padding(.horizontal)
                .backgroundStyle(Color.appColorBlue)
            
            
            
            Toggle(isOn: $isNightOn) {
                
                Text("Night")
                    .foregroundColor(.black)
                    .modifier(LatoFontModifier(fontWeight: .bold, fontSize: 18))
                
            }.padding(.horizontal)
            
            
            Spacer()
            
        }.padding(.top)
            .padding(.horizontal)
            .background(Color.screenBG)
        
        
        
        
    }
    
    
}


struct MicStopBottomSheet:View{
    
    
    var body: some View{
        
        VStack{
            
            Color.black
                .frame(width: 40,height: 3)
                .cornerRadius(2)
            
            
            Button {
                
                
            } label: {
                
                
                Text("Stop")
                    .foregroundColor(Color.red)
                    .modifier(LatoFontModifier(fontWeight: .bold, fontSize: 16))
                
                
            }.frame(width: UIScreen.main.bounds.width-60,height: 42)
                .background(Color.lightBlue)
                .cornerRadius(40)
                .padding(.horizontal)
                .padding(.top,20)
            
            
            Spacer()
            
        }.padding(.top)
            .padding(.horizontal)
            .background(Color.screenBG)
        
        
    }
    
    
}



struct SyncDataBottomSheet:View{
    
    
    @State var isCoughOn = false
    @State var isStatisticsOn = false
    
    var body: some View{
        
        VStack{
            
            Color.black
                .frame(width: 40,height: 3)
                .cornerRadius(2)
            
            
            Toggle(isOn: $isCoughOn) {
                
                Text("Coughs")
                    .foregroundColor(.black)
                    .modifier(LatoFontModifier(fontWeight: .bold, fontSize: 18))
                
            }.padding(.horizontal)
                .backgroundStyle(Color.appColorBlue)
            
            
            
            Toggle(isOn: $isStatisticsOn) {
                
                Text("Statistics")
                    .foregroundColor(.black)
                    .modifier(LatoFontModifier(fontWeight: .bold, fontSize: 18))
                
            }.padding(.horizontal)
            
            
            NavigationLink {
                
                BecomeVolunteerView()
                
            } label: {
                
                
                Text("Start")
                    .font(.system(size: 16))
                    .foregroundColor(Color.white)
                
                
            }.frame(width: UIScreen.main.bounds.width-60,height: 42)
                .background(Color.appColorBlue)
                .cornerRadius(40)
                .padding(.vertical)
            
        }.padding(.top)
            .padding(.horizontal)
            .background(Color.screenBG)
        
        
    }
    
    
}
