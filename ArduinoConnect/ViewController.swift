//
//  ViewController.swift
//  ArduinoConnect
//
//  Created by Christopher Walter on 7/26/18.
//  Copyright © 2018 AssistStat. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // ble variables
    var connectedPeripheral:CBPeripheral?
    var centralManager:CBCentralManager!
    var peripherals: [CBPeripheral] = []
    var peripheralServices:[CBService] = []
    var serviceCharacteristics:[[CBCharacteristic]] = [[]]
    var RSSIs = [NSNumber]()
    
    // services and characteristics
    var serviceUUID:CBUUID? = CBUUID(string: "19B10010-E8F2-537E-4F6C-D104768A1214")
    let txUUID:CBUUID? = CBUUID(string: "19B10011-E8F2-537E-4F6C-D104768A1214")
    let rxUUID:CBUUID? = CBUUID(string: "19B10012-E8F2-537E-4F6C-D104768A1214")
    
    // operational variables
    var bleScanTimer = Timer()// for timing out if device not found
    var txValue:Int!
    var rxValue:Double!
    
    @IBOutlet weak var bleTextView: UITextView!
    @IBOutlet weak var ultrasonicLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)// create central manager instance
        
        // set display textView properties
        bleTextView.text = ""
        bleTextView.layer.borderColor = UIColor.brown.cgColor// UIColor(red: 153, green: 102, blue: 51, alpha: 1).cgColor
        bleTextView.layer.borderWidth = 3
    }
    
    // ************************************* DELEGATE Functions ***********************************************
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            // start scanning bluetooth is on
            bleTextView.text = "Bluetooth Enabled\n"
            scanPeripherals()
        }
        else {
            //Let user know bluetooth is off
            bleTextView.text = bleTextView.text + "Bluetooth Disabled - Make sure your Bluetooth is turned on\n"
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // add peripherals to array
        self.peripherals.append(peripheral)
        self.RSSIs.append(RSSI)// store signal strength
        
        // display discovery
        bleTextView.text = bleTextView.text + "Pheripheral: \(String(describing: peripheral.name)) found.\nSignal Strength: \(RSSI)\n"
        bleTextView.text = bleTextView.text + "Advertisement Data:\n\t \(advertisementData)\n\n"
        
        // allowing connection since we are only looking for the Arduino101
        bleTextView.text = bleTextView.text + "**********************************\n" + "Connecting...\n"
        centralManager?.connect(peripheral, options: nil)
        //        if peripheral.name == "ARDUINO 101-3DDE"{// just connect to arduino 101
        //            connectedPeripheral = peripheral
        //            bleTextView.text = bleTextView.text + "**********************************\n" + "Connecting...\n"
        //            centralManager?.connect(connectedPeripheral!, options: nil)
        //        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        bleTextView.text = bleTextView.text + "Connection Failed\n"
    }
    
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Expose peripheral to class
        connectedPeripheral = peripheral
        
        // Display connection
        bleTextView.text = bleTextView.text + "Connection complete\n" + "*****************************\n"
        bleTextView.text = bleTextView.text + "Peripheral info: \(String(describing: connectedPeripheral))\n"
        
        //Stop Scan- We don't need to scan once we've connected to a peripheral.
        stopScan()
        
        //Set delegate so methods can be overwritten
        peripheral.delegate = self
        
        //Now look for services
        //peripheral.discoverServices([uuid!])//only the ones of interest
        peripheral.discoverServices(nil)// nil = all services
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("*******************************************************")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            return
        }
        print("Discovered Services: \(services)\n")
        
        // Add services to array and discover all characteristics offered by the service
        for service in services {
            peripheralServices.append(service)
            peripheral.discoverCharacteristics(nil, for: service)// nil = all characteristics
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        bleTextView.text = bleTextView.text + "*****************************************************\n"
        
        if ((error) != nil) {
            print("Error discovering Characteristics: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        serviceCharacteristics.append(characteristics);// add characteristics to array
        
        bleTextView.text = bleTextView.text + "Found \(characteristics.count) characteristics\n"
        
        // set notifications for the appropriate characteristic and find each descriptor
        for characteristic in characteristics {
            bleTextView.text = bleTextView.text + "Characteristic Description: \(characteristic)\n"
            
            if characteristic.uuid.isEqual(rxUUID)  {
                peripheral.setNotifyValue(true, for: characteristic)// set notification
                bleTextView.text = bleTextView.text + "Setting Notify Value\n"
            }
            else {bleTextView.text = bleTextView.text + "No Notify Set\n"}
            //peripheral.discoverDescriptors(for: characteristic)// descriptor not yet implemented on Arduino 101
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // get distance to object and display it
        rxValue = Double(characteristic.value![0])
        ultrasonicLabel.text = "DISTANCE TO OBJECT:  \(rxValue!) inches"
    }
    
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let peripheralName = peripheral.name {
            bleTextView.text = "Peripheral \(peripheralName) got disconnected"
        }
        else {
            bleTextView.text = "Peripheral successfully disconnected"
        }
    }
    // ************************************* END DELEGATE Functions ***********************************************
    
    @IBAction func scanPressed(){
        bleTextView.text = ""
        scanPeripherals()
    }
    
    func scanPeripherals() {
        bleTextView.text = bleTextView.text + "**********************************\n" + "Now Scanning for Arduino 101 Peripheral...\n\n"
        self.bleScanTimer.invalidate()
//        centralManager?.scanForPeripherals(withServices: [serviceUUID!], options: nil)// only devices of interest
        centralManager?.scanForPeripherals(withServices: nil, options: nil)// all devices
        //centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])// all devices no duplicates
        Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(self.stopScan), userInfo: nil, repeats: false)
    }
    
    @IBAction func disconnectPressed(_ sender: UIButton) {
        if connectedPeripheral != nil {
            centralManager?.cancelPeripheralConnection(connectedPeripheral!)
        }
    }
    
    @objc func stopScan(){
        if (self.centralManager?.isScanning)! {
            self.centralManager?.stopScan()
            bleTextView.text = bleTextView.text + "Scan Stopped\n" + "Arduino 101 not Found!\n"
        }
    }
    
    @IBAction func switchPressed(_ sender: UISwitch) {
        if (sender.isOn == true) {
            txValue = 2;
        }
        else {
            txValue = 3;
        }
        tx2Arduino(value: txValue);
    }
    
    @IBAction func startUltrasonic(_ sender:UIButton) {
        txValue = 0;
        tx2Arduino(value: txValue);
    }
    @IBAction func stopUltrasonic() {
        txValue = 1;
        tx2Arduino(value: txValue);
    }
    
    func tx2Arduino(value:Int ) {
        var tmpVal = value;
        let data = Data(bytes:&tmpVal,count:MemoryLayout<Int>.size)
        for i1 in 0..<serviceCharacteristics.count {
            for i2 in 0..<serviceCharacteristics[i1].count {
                
                if (serviceCharacteristics[i1][i2].uuid.isEqual(txUUID)) {// transmit to the selected characteristic
                    connectedPeripheral?.writeValue(data, for: serviceCharacteristics[i1][i2], type: CBCharacteristicWriteType.withResponse)
                }
                
            }
        }
    }
}

