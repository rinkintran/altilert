//
//  ViewController.swift
//  AltiLert
//
//  Created by Lincoln Tran on 4/17/19.
//  Copyright © 2019 Tran Brothers. All rights reserved.
//

import UIKit
import CoreMotion
import CoreLocation
import UserNotifications


class ViewController: UIViewController, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {

    @IBOutlet weak var altFromGPS: UILabel!
    @IBOutlet weak var altFromBaro: UILabel!
    @IBOutlet weak var altimeterSwitch: UISwitch!
    
    let center = UNUserNotificationCenter.current()
    lazy var altimeter = CMAltimeter()
    lazy var locationManager = CLLocationManager()
    lazy var oldGPSAlt = Double(0)
    let diff = Float(1)
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        center.requestAuthorization(options: [.alert, .sound]) {
            (granted, error) in
            if !granted {
                print("Something went wrong")
            }
        }
        locationManager.delegate = self
        center.delegate = self
        locationManager.requestAlwaysAuthorization()
        altimeterSwitch.setOn(false, animated: false)
        stopUpdate()
        
    }
    
    func updateBaroAlt() {
        var notNotified = true
        
        if CMAltimeter.isRelativeAltitudeAvailable() == true {
            altimeter.startRelativeAltitudeUpdates(to: OperationQueue.main, withHandler: { (altitudeData:CMAltitudeData?, error:Error?) in
                
                if (error != nil) {
                    let alertView = UIAlertView(title: "Error", message: error!.localizedDescription, delegate: nil, cancelButtonTitle: "OK")
                    alertView.show()
                } else {
                    let altitude = altitudeData!.relativeAltitude.floatValue
//                    print("updating baro alt")
                    self.altFromBaro.text = String(format: "%.03f", altitude)
                    if ((abs(altitude) > self.diff) && notNotified) {
                        let content = UNMutableNotificationContent()
                        content.title = "Alert"
                        content.body = "You have changed \(altitude) meters based on barometer readings."
                        content.sound = UNNotificationSound.default
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                        let request = UNNotificationRequest(identifier: "Altitude Changed", content: content, trigger: trigger)
                        self.center.add(request, withCompletionHandler: { (error) in
                            if (error != nil) {
                                print(error)
                            }
                        })
                        print("you changed too much")
                        notNotified = false
                    }
                }
            })
        } else {
            let alertView = UIAlertView(title: "Error", message: "Barometer not available on this device.", delegate: nil, cancelButtonTitle: "OK")
            alertView.show()
        }
    }
    
    func startGPS() {
        let authorizationStatus = CLLocationManager.authorizationStatus()
        if authorizationStatus != .authorizedWhenInUse && authorizationStatus != .authorizedAlways {
            // User has not authorized access to location information.
            print("no authorization")
            return
        }
        // Do not start services that aren't available.
        if !CLLocationManager.locationServicesEnabled() {
            // Location services is not available.
            print("no location service available")
            return
        }
        
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100.0  // In meters.
        locationManager.startUpdatingLocation()
        print("started location updates")
    }
    
    //Here you decide whether to silently handle the notification or still alert the user.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        //Write you app specific code here
        completionHandler([.alert, .sound]) //execute the provided completion handler block with the delivery option (if any) that you want the system to use. If you do not specify any options, the system silences the notification.
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let gpsAltitude = locations.last!.altitude
        print("we got a GPS update!")
        print("\(gpsAltitude)")
        self.altFromGPS.text = String(format: "%.03f", gpsAltitude)
        
        if (abs(gpsAltitude - oldGPSAlt) > Double(diff) && oldGPSAlt != 0.0) {
            let content = UNMutableNotificationContent()
            content.title = "Alert"
            content.body = "You have changed \(oldGPSAlt - gpsAltitude) meters based on GPS readings."
            content.sound = UNNotificationSound.default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: "Altitude Changed", content: content, trigger: trigger)
            self.center.add(request, withCompletionHandler: { (error) in
                if (error != nil) {
                    print(error)
                }
            })
        }
        
        oldGPSAlt = gpsAltitude
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError, error.code == .denied {
            // Location updates are not authorized.
            manager.stopUpdatingLocation()
            print("stop updating location")
            return
        }
        // Notify the user of any errors.
        print("location error")
        print(error)
    }
    
    func stopUpdate() {
        altFromBaro.text = "-"
        altFromGPS.text = "-"
        
        self.altimeter.stopRelativeAltitudeUpdates()
        self.locationManager.stopUpdatingLocation()
    }
    
    @IBAction func switchDidChange(_ altimeterSwitch: UISwitch) {
        if altimeterSwitch.isOn {
            updateBaroAlt()
            startGPS()
        } else {
            stopUpdate()
        }
    }

}

