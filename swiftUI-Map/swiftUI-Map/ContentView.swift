//
//  ContentView.swift
//  swiftUI-Map
//
//  Created by zluof on 2024/5/30.
//

import SwiftUI
import MapKit

@Observable
class MapService {
    var currentPosition = MapCameraPosition.userLocation(followsHeading: true, fallback: MapCameraPosition.region(MKCoordinateRegion.init(center: LocationManager.defaultCoordinate, span: LocationManager.defaultCoordinateSpan)))
    
    var isGeoCoding = false
    
    var address: String? = nil
    
    var currentLocation = LocationManager.defaultCoordinate
    
    
    func reverGeoCode() {
        self.isGeoCoding = true
        let center = self.currentLocation
        let latitude = center.latitude
        let longitude = center.longitude
        let geoCoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        geoCoder.reverseGeocodeLocation(location) { (placeMarks, error) in
            self.isGeoCoding = false
            if error != nil {
                self.address = error?.localizedDescription
            }else{
                if let placeMarks, let first = placeMarks.map({$0.description.components(separatedBy: "@").first}).first(where: {$0 != nil}) {
                    self.address = first
                }
            }
        }
    }
}

struct ContentView: View {
    
    @State private var service = MapService()
    
    var body: some View {
        ZStack(alignment:.center){
            Map(position: $service.currentPosition,interactionModes: .all)
                .onMapCameraChange({ result in
                    print("\(result.region.center)")
                    service.currentLocation = result.region.center
                    service.reverGeoCode()
                })
            Image(systemName: "mappin")
                .font(.largeTitle)
                .foregroundStyle(.blue)
                .offset(y: -16)
            bottomView
        }
    }
    
    @ViewBuilder
    var bottomView: some View {
        VStack {
            Spacer()
            VStack {
                HStack{
                    Text("当前位置：")
                        .font(.headline)
                        .foregroundColor(.black)
                    Spacer()
                }
                HStack{
                    if service.isGeoCoding {
                        HStack(alignment:.center){
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Spacer()
                        }
                    }else{
                        Text("\(service.address ?? "null")")
                            .font(.body)
                            .foregroundColor(.black)
                            .padding([.bottom,.top,],10)
                    }
                    
                    Spacer(minLength: 10)
                }
            }
            .padding(10)
            .background(.bar)
            .cornerRadius(10)
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
