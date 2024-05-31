//
//  LocationManager.swift
//  swiftUI-Map
//
//  Created by zluof on 2024/5/30.
//

import Foundation
import CoreLocation
import MapKit

enum LocationError: Error {
    case locationFail
}

class LocationManager: NSObject {
    
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    
    var current: CLLocationCoordinate2D = LocationManager.defaultCoordinate
    
    var completedLocation: ((_ result: Result<CLLocationCoordinate2D,Error>)->Void)? = nil
    
    // 北京
    static let defaultCoordinate: CLLocationCoordinate2D = {
        CLLocationCoordinate2D(latitude: 39.916527, longitude: 116.397128)
    }()
    
    static let defaultCoordinateSpan: MKCoordinateSpan = {
       return MKCoordinateSpan.init(latitudeDelta: 0.1, longitudeDelta: 0.1)
    }()
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        Task{
            if CLLocationManager.locationServicesEnabled() {
                locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                locationManager.startUpdatingLocation()
            } else {
                completedLocation?(.failure(LocationError.locationFail))
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            manager.stopUpdatingLocation()
            current = LocationPoint().transformFromWGSToGCJ(wgsLoc: location.coordinate)
            completedLocation?(.success(current))
        }else{
            completedLocation?(.failure(LocationError.locationFail))
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completedLocation?(.failure(error))
    }
}

class LocationPoint {
    
    //WGS-84：是国际标准，GPS坐标（Google Earth使用、或者GPS模块）
    //GCJ-02：中国坐标偏移标准，Google Map、高德、腾讯使用
    //BD-09： 百度坐标偏移标准，Baidu Map使用
    
    let  a = 6378245.0;
    let  ee = 0.00669342162296594323;
    let  pi = 3.14159265358979324;
    let  xPi = Double.pi  * 3000.0 / 180.0;
    
    //WGS-84 --> GCJ-02
    func transformFromWGSToGCJ(wgsLoc:CLLocationCoordinate2D)->CLLocationCoordinate2D
    {
        var adjustLoc=CLLocationCoordinate2D();
        if( isLocationOutOfChina(location: wgsLoc))
        {
            adjustLoc = wgsLoc;
        }
        else
        {
            var adjustLat = transformLatWithX(x: wgsLoc.longitude - 105.0 ,y:wgsLoc.latitude - 35.0);
            var adjustLon = transformLonWithX(x: wgsLoc.longitude - 105.0 ,y:wgsLoc.latitude - 35.0);
            let radLat = wgsLoc.latitude / 180.0 * pi;
            var magic = sin(radLat);
            magic = 1 - ee * magic * magic;
            let sqrtMagic = sqrt(magic);
            adjustLat = (adjustLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi);
            adjustLon = (adjustLon * 180.0) / (a / sqrtMagic * cos(radLat) * pi);
            adjustLoc.latitude = wgsLoc.latitude + adjustLat;
            adjustLoc.longitude = wgsLoc.longitude + adjustLon;
        }
        return adjustLoc;
    }
    
    func transformLatWithX(x:Double,y:Double)->Double
    {
        var lat = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y ;
        lat += 0.2 * sqrt(fabs(x));
        
        lat += (20.0 * sin(6.0 * x * pi)) * 2.0 / 3.0;
        lat += (20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
        lat += (20.0 * sin(y * pi)) * 2.0 / 3.0;
        lat += (40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
        lat += (160.0 * sin(y / 12.0 * pi)) * 2.0 / 3.0;
        lat += (320 * sin(y * pi / 30.0)) * 2.0 / 3.0;
        return lat;
    }
    
    func transformLonWithX(x:Double,y:Double)->Double
    {
        var lon = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y ;
        lon +=  0.1 * sqrt(fabs(x));
        lon += (20.0 * sin(6.0 * x * pi)) * 2.0 / 3.0;
        lon += (20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
        lon += (20.0 * sin(x * pi)) * 2.0 / 3.0;
        lon += (40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
        lon += (150.0 * sin(x / 12.0 * pi)) * 2.0 / 3.0;
        lon += (300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
        return lon;
    }
    
    //GCJ-02 --> BD-09
    func transformFromGCJToBaidu(p:CLLocationCoordinate2D) -> CLLocationCoordinate2D
    {
        let z = sqrt(p.longitude * p.longitude + p.latitude * p.latitude) + 0.00002 * sqrt(p.latitude * pi);
        let theta = atan2(p.latitude, p.longitude) + 0.000003 * cos(p.longitude * pi);
        var geoPoint=CLLocationCoordinate2D();
        geoPoint.latitude  = (z * sin(theta) + 0.006);
        geoPoint.longitude = (z * cos(theta) + 0.0065);
        return geoPoint;
    }

    
    //BD-09 --> GCJ-02
    func transformFromBaiduToGCJ(p:CLLocationCoordinate2D)-> CLLocationCoordinate2D
    {
        let x = p.longitude - 0.0065, y = p.latitude - 0.006;
        let z = sqrt(x * x + y * y) - 0.00002 * sin(y * xPi);
        let theta = atan2(y, x) - 0.000003 * cos(x * xPi);
        var geoPoint = CLLocationCoordinate2D();
        geoPoint.latitude  = z * sin(theta);
        geoPoint.longitude = z * cos(theta);
        return geoPoint;
    }
    
    //GCJ-02 --> WGS-84
    func transformFromGCJToWGS(p:CLLocationCoordinate2D) -> CLLocationCoordinate2D
    {
        let threshold = 0.00001;
        
        // The boundary
        var minLat = p.latitude - 0.5;
        var maxLat = p.latitude + 0.5;
        var minLng = p.longitude - 0.5;
        var maxLng = p.longitude + 0.5;
        
        var delta = 1.0;
        let maxIteration = 30;
        // Binary search
        while(true)
        {
            let leftBottom  = transformFromWGSToGCJ(wgsLoc: CLLocationCoordinate2D(latitude: minLat,longitude: minLng));
            let rightBottom = transformFromWGSToGCJ(wgsLoc: CLLocationCoordinate2D(latitude : minLat,longitude : maxLng));
            let leftUp      = transformFromWGSToGCJ(wgsLoc: CLLocationCoordinate2D(latitude : maxLat,longitude : minLng));
            let midPoint    = transformFromWGSToGCJ(wgsLoc: CLLocationCoordinate2D(latitude : ((minLat + maxLat) / 2),longitude : ((minLng + maxLng) / 2)));
            delta = fabs(midPoint.latitude - p.latitude) + fabs(midPoint.longitude - p.longitude);
            
            if(maxIteration <= 1 || delta <= threshold)
            {
                return CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2);
                
            }
            
            if(isContains(point: p, p1: leftBottom, p2: midPoint))
            {
                maxLat = (minLat + maxLat) / 2;
                maxLng = (minLng + maxLng) / 2;
            }
            else if(isContains(point: p, p1: rightBottom, p2: midPoint))
            {
                maxLat = (minLat + maxLat) / 2;
                minLng = (minLng + maxLng) / 2;
            }
            else if(isContains(point: p, p1: leftUp, p2: midPoint))
            {
                minLat = (minLat + maxLat) / 2;
                maxLng = (minLng + maxLng) / 2;
            }
            else
            {
                minLat = (minLat + maxLat) / 2;
                minLng = (minLng + maxLng) / 2;
            }
        }
        
    }
    
    //WGS-84 --> BD-09
    func transformFromWGSToBaidu(p:CLLocationCoordinate2D) -> CLLocationCoordinate2D
    {
        let gcj = transformFromWGSToGCJ(wgsLoc: p);
        let bd = transformFromGCJToBaidu(p: gcj)
        return bd;
    }
    
    //BD-09 --> WGS-84
    func transformFromBaiduToWGS(p:CLLocationCoordinate2D) -> CLLocationCoordinate2D
    {
        let gcj = transformFromBaiduToGCJ(p: p)
        let wgs = transformFromGCJToWGS(p: gcj)
        return wgs;
    }
    
    //判断点是否在p1和p2之间
    //point: 点
    //p1:    左上角
    //p2:    右下角
    func isContains(point:CLLocationCoordinate2D , p1:CLLocationCoordinate2D, p2:CLLocationCoordinate2D)->Bool
    {
        
        return (point.latitude >= min(p1.latitude, p2.latitude) && point.latitude <= max(p1.latitude, p2.latitude)) && (point.longitude >= min(p1.longitude,p2.longitude) && point.longitude <= max(p1.longitude, p2.longitude));
    }
    
    
    //是否在中国以外
    func isLocationOutOfChina(location:CLLocationCoordinate2D) -> Bool
    {
        if (location.longitude < 72.004 || location.longitude > 137.8347 || location.latitude < 0.8293 || location.latitude > 55.8271){
            return true;
        }else{
            return false;
        }
        
    }
    
    ///获取两点之间的距离
    static func distanceByPoint(lat1:Double,lat2 :Double,lng1 :Double,lng2:Double)->Double{
        let dd = Double.pi/180;
        let x1=lat1*dd;
        let x2=lat2*dd;
        let y1=lng1*dd;
        let y2=lng2*dd;
        let R = 6371004;
        
        let temp = 2 - 2 * cos(x1) * cos(x2) * cos(y1-y2) - 2 * sin(x1) * sin(x2);
        
        let distance = Double(2) * Double(R) * asin(sqrt(temp)/2);
        
        //返回 m
        return   distance;
        
    }
    
    ///获取两点之间的距离
    static  func distanceByPoint(point1:CLLocationCoordinate2D,point2:CLLocationCoordinate2D)->Double{
        return distanceByPoint(lat1: point1.latitude, lat2: point2.latitude, lng1: point1.longitude, lng2: point2.longitude);
    
    }
}
