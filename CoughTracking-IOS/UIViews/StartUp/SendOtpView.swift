//
//  SendOtpView.swift
//  CoughTracking-IOS
//
//  Created by ai4lyf on 11/08/2023.
//

import SwiftUI
import OTPView

struct SendOtpView: View
{
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var networkManager: NetworkManager
    @State private var toast: FancyToast? = nil
    
    @ObservedObject var sendOtpVM = SendOtpVM()
    
    @State var email: String
    @State var fcmToken: String
    @State var loginWith: String
    
    
    
    var body: some View {
        
        ZStack {
            ScrollView(showsIndicators: false) {
                ZStack {
                    VStack(spacing: 0) {
                        
                        
                        Image("logosmall")
                            .resizable()
                            .frame(width: 120,height: 120)
                            .padding(.top, 30)
                        
                        HStack{
                            
                            Text("Please enter Code")
                                .foregroundColor(Color.black)
                                .modifier(LatoFontModifier(fontWeight: .bold, fontSize: 20))
                                .padding(.top, 24)
                                .padding(.leading,30)
                            
                            Spacer()
                            
                        }
                        Group {
                            Text("Please enter the OTP that is sent to your email address ")
                                .foregroundColor(Color.greyColor) +
                            Text("\"\(sendOtpVM.email)\"")
                                .foregroundColor(Color.appColorBlue)
                        }
                        .modifier(LatoFontModifier(fontWeight: .regular, fontSize: 16))
                        .padding(.top, 10)
                        .padding(.leading,30)
                        
                        OtpView(activeIndicatorColor: Color.appColorBlue, inactiveIndicatorColor: Color.gray,  length: 4, doSomething: { value in
                            
                            sendOtpVM.enteredOTP = Int(value) ?? 0
                            
                            if(Int(value) == sendOtpVM.mailOTP){
                                
                                sendOtpVM.isVarified = true
                                
                            }else{
                                
                                sendOtpVM.isError = true
                                sendOtpVM.errorMessage = "The entered OTP does not match. Please try again."
                                
                            }
                            
                        })
                        .padding()
                        
                        
                        HStack{
                            
                            if sendOtpVM.isTimerRunning{
                                
                                Text("Resend in")
                                    .foregroundColor(Color("blue_color"))
                                    .font(.system(size: 20))
                                
                                Text(String(format: "%02d:%02d", sendOtpVM.remainingTime / 60, sendOtpVM.remainingTime % 60))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color("blue_color"))
                                
                                Text("")
                                
                            }else{
                                
                                
                                Button {
                                    
                                    sendOtpVM.isEmailSent = false
                                    sendOtpVM.sendOtpToMail()
                                    
                                } label: {
                                    
                                    Text("Resend")
                                        .foregroundColor(Color("blue_color"))
                                        .font(.system(size: 20))
                                    
                                }
                                
                            }
                            
                        }
                        
                        Spacer()
                        
                        
                        Button {
                            
                            if(sendOtpVM.isVarified){
                                
                                MyUserDefaults.saveBool(forKey:Constants.isLoggedIn, value: true)
                                MyUserDefaults.saveBool(forKey:Constants.isBaseLineSet, value: false)
                                MyUserDefaults.saveString(forKey:Constants.email, value: sendOtpVM.email)
                                MyUserDefaults.saveInt(forKey:Constants.otp, value: sendOtpVM.mailOTP)
                            
                                sendOtpVM.goNext = true
                                
                            }else if(sendOtpVM.enteredOTP == 0){
                                
                                sendOtpVM.isError = true
                                sendOtpVM.errorMessage = "Pleae enter the OTP first!"
                                
                            }else if(sendOtpVM.enteredOTP != sendOtpVM.mailOTP){
                                
                                sendOtpVM.isError = true
                                sendOtpVM.errorMessage = "The entered OTP does not match. Please try again."
                                
                            }
                            
                            
                        } label: {
                            Image("continue_btn")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 50)
                            
                        }.padding(.horizontal)
                            .padding(.bottom, 50)
                        
                        
                        
                    }.frame(height: UIScreen.main.bounds.height-100)
                    
                    
                    
                    
                }
                
            }.navigationBarTitle("")
                .toastView(toast: $toast)
                .dismissKeyboardOnTap()
            
            
            if(sendOtpVM.isLoading){
                
                LoadingView()
                    .onAppear{
                        
                        DispatchQueue.main.asyncAfter(deadline: .now()+0.7){
                            
                            UIApplication.shared.endEditing()
                            
                        }
                        
                    }
                
            }
            
        }.environment(\.managedObjectContext,viewContext)
            .navigationDestination(isPresented: $sendOtpVM.goNext, destination: {
                
                BaselineView()
                    .environmentObject(networkManager)
                    .environment(\.managedObjectContext,viewContext)
                
            }).onReceive(sendOtpVM.$isEmailSent, perform: { i in
                
                if(i){
                    
                    toast = FancyToast(type: .success, title: "Email Sent!", message: sendOtpVM.errorMessage)
                    
                }
                
            }).onReceive(sendOtpVM.$isError, perform: { i in
                
                if(i){
                    
                    toast = FancyToast(type: .error, title: "Error occurred!", message: sendOtpVM.errorMessage)
                    
                }
                
            }).onAppear{
                
                sendOtpVM.email = email
                sendOtpVM.fcmToken = fcmToken
                sendOtpVM.loginWith = loginWith

                sendOtpVM.sendOtpToMail()
                
            }
        
    }
    
    
    
    
}


extension UIResponder {
    static var currentFirstResponder: UIResponder?
    func findFirstResponder() {
        UIResponder.currentFirstResponder = self
    }
}

extension View {
    func firstResponder(_ responder: Binding<String?>) -> some View {
        background(GeometryReader { geometry in
            Color.clear.onAppear {
                responder.wrappedValue = geometry.frame(in: .global).midX.description
                UIResponder.currentFirstResponder = nil
            }
        })
    }
}





struct SendOtpView_Previews: PreviewProvider {
    static var previews: some View {
        SendOtpView(email: "", fcmToken: "", loginWith: "")
    }
}
