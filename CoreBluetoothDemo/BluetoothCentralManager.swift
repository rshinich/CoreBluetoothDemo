//
//  BluetoothCentralManager.swift
//  CoreBluetoothDemo
//
//  Created by 张忠瑞 on 2023/12/17.
//

import Foundation
import CoreBluetooth

class BluetoothCentralManager: NSObject {

    private var centralManager: CBCentralManager!

    private var discoveredPeripheral: CBPeripheral?
    private var discoveredPeripherals: [CBPeripheral] = []

    override init() {

        super.init()
        self.setupCentralManager()
    }

    private func setupCentralManager() {
        let centralManager = CBCentralManager(delegate: self, queue: nil)
        self.centralManager = centralManager
    }

    public func startScanPeripherals() {

        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }

    public func stopScanPeripherals() {

        centralManager.stopScan()
    }

    private func setPeripheralAndDiscoverServers(peripheral: CBPeripheral) {

        peripheral.delegate = self
        peripheral.discoverServices(nil)

    }

    private func discoverCharacteristics(peripheral: CBPeripheral, service: CBService) {

        peripheral.discoverCharacteristics(nil, for: service)
    }

    private func readValueForCharacteristic(peripheral: CBPeripheral, characteristic: CBCharacteristic) {

        guard characteristic.properties.contains(.read) else {
            print("Characteristic not support read value")
            return
        }

        peripheral.readValue(for: characteristic)
    }

    private func subscribingCharacteristic(peripheral: CBPeripheral, characteristic: CBCharacteristic) {

        guard characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) else {
            print("Characteristic not support subscribing")
            return
        }

        peripheral.setNotifyValue(true, for: characteristic)
    }

    private func writeWithoutResponseValueToCharacteristic(peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data) {

        guard characteristic.properties.contains(.writeWithoutResponse) else {

            print("Characteristic not support without response write")
            return
        }

        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)

    }

    private func writeWithResponseValueToCharacteristic(peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data) {

        guard characteristic.properties.contains(.write) else {

            print("Characteristic not support with response write")
            return
        }

        peripheral.writeValue(data, for: characteristic, type: .withResponse)

    }

}

extension BluetoothCentralManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print(central.state)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        print("Discovered \(peripheral.name)")
        self.discoveredPeripheral = peripheral
        self.discoveredPeripherals.append(peripheral)

        centralManager.connect(peripheral, options: nil)

    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        print("Peripheral \(peripheral.name) connected")
        self.setPeripheralAndDiscoverServers(peripheral: peripheral)
    }
}

extension BluetoothCentralManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("Discover services: \(peripheral.services)")

        for service in (peripheral.services ?? []) {
            self.discoverCharacteristics(peripheral: peripheral, service: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

        print("Discover characteristics: \(service.characteristics)")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        if let data = characteristic.value {
            // parse the data
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {

    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
    }

}
