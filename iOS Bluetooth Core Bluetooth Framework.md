# iOS Bluetooth Core Bluetooth Framework

#blog #学习/Bluetooth

本篇文章旨在记录学习在iOS中使用Core Bluetooth设备时的知识与心得。

Core Bluetooth 是Apple提供的在iOS平台和macOS平台中用来与蓝牙进行交互的框架。

实际上，蓝牙传输的底层还有很多细节规范，而Core Bluetooth是将其中的部分封装起来，供开发者能够更加简单的调用和管理。

![](iOS%20Bluetooth%20Core%20Bluetooth%20Framework/image.png)

OK，接下来我们来看一下我们的核心框架：Core Bluetooth

## Core Bluetooth

Core Bluetooth框架可以让你的iOS或Mac app与其他**Peripherals**蓝牙设备比如心率计、温度传感器、甚至其他iOS设备连接，交互数据。

整个框架是基于蓝牙4.0规范抽象出来的，也就是说，他隐藏了很多底层蓝牙的规范细节。

> 在iOS10.0之后的设备中使用蓝牙时，需要在info.plist中添加许可[NSBluetoothPeripheralUsageDescription](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/uid/TP40009251-SW20)

### Centrals & Peripherals

在蓝牙交互中，有两个关键设备概念。

- **中心设备**(Centrals)：负责扫描附近可能存在的感兴趣的周边设备；
- **周边设备**(Peripherals)：负责广播自己拥有的数据以便被中心设备搜索到；

他们两个的关系某种程度上也有点像是客户端-服务器之间的关系。

![](iOS%20Bluetooth%20Core%20Bluetooth%20Framework/image%202.png)

其中**Peripherals**一般用来提供一些信息，而**Centrals**一般使用**Peripherals**提供的信息来完成某些动作。
比如，心率传感器作为**Peripherals**来向作为**Centrals**的iPhone或Mac(App)提供心率信息，然后App来收集并友好的展示获取到的心率信息。

其中**Peripherals**会持续将一些自身的信息数据作为数据包向外广播出来，比如设备的名称或者主要的参数信息。比如一个电子温度传感器会持续向外广播当前房间的温度信息。

而**Centrals**可以扫描并收听任何感兴趣的**Peripherals**，并且在必要时还可以向其发起连接请求。

![](iOS%20Bluetooth%20Core%20Bluetooth%20Framework/image%203.png)

连接到Peripheral的方式就是开始搜索其中的数据并与之交互，所以在开始之前，连接Peripheral的数据结构可以让我们更好的理解他们是如何建立连接的。

这里又有两个比较重要的概念：

- 服务(Service)
- 特征点(Characteristic)

Peripheral可能包含一项或多项服务信息或提供有关其连接信号强度的信息。比如一个心率传感器的一个**Service**就是广播检测到的心率数据。

但是**Service**本身也可能是由多个**Characteristics**或**Service**(这里主要指对其他Service的引用)组成，**Characteristics**可能提供了更多Peripheral中的详细信息，比如刚刚提到的心率传感器中，可能不仅仅提供了心率数据这一个**Characteristics**，还可能提供了设备处于身体位置的**Characteristics**。

![](iOS%20Bluetooth%20Core%20Bluetooth%20Framework/image%204.png)

当Central和Peripheral建立连接之后，就可以获取到peripheral的全部信息(在未连接之前可能只是获取到很小的一部分)。随后，central还可以通过读取或写入服务特征的值来与peripheral设备交互。

### 当App作为Central时

在Core Bluetooth框架中，本地的Central端主要通过[CBCentralManager](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager)管理，主要用来发现和链接远端通过[CBPeripheral](https://developer.apple.com/documentation/corebluetooth/cbperipheral)实现的Peripheral，以及获取其发送广播消息。

![](iOS%20Bluetooth%20Core%20Bluetooth%20Framework/image%205.png)

而每个远端Peripheral设备中的Service和Characteristics则通过[CBService](https://developer.apple.com/documentation/corebluetooth/cbservice)和[CBCharacteristic](https://developer.apple.com/documentation/corebluetooth/cbcharacteristic)，其中的结构类似：
![](iOS%20Bluetooth%20Core%20Bluetooth%20Framework/image%206.png)

### 当App作为Peripheral时

同样的，在macOS10.9 和 iOS6之后，Mac和iOS设备也可以作为Peripherals，以此来提供数据给其他Central设备，比如其他Mac，iPhone或者iPad。

在Peripheral端，本地的设备使用[CBPeripheralManager](https://developer.apple.com/documentation/corebluetooth/cbperipheralmanager)，这个对象用于管理本地的Peripheral的Service和Characteristic信息，并且可以告诉远端的[CBCentral](https://developer.apple.com/documentation/corebluetooth/cbcentral)，还可以用来响应来自Central的读取和写入请求。

![](iOS%20Bluetooth%20Core%20Bluetooth%20Framework/image%207.png)

与之前的结构相同，不过处于Peripheral端时，我们的Server和Characteristic数据是可变的，所以分别使用了[CBMutableService](https://developer.apple.com/documentation/corebluetooth/cbmutableservice)和[CBMutableCharacteristic](https://developer.apple.com/documentation/corebluetooth/cbmutablecharacteristic)。

![](iOS%20Bluetooth%20Core%20Bluetooth%20Framework/image%208.png)

## 作为Central时的常见操作

作为Central设备，想要操作时，通常分为以下几个步骤。

1. 创建CBCentralManager实例。
2. 搜索感兴趣的Peripheral设备。
3. 连接发现的Peripheral设备。
4. 搜索连接到的Peripheral设备中的Services。
5. 搜索发现的Service中的Characteristics。

在这之后，就可以检索Characteristics或者向Characteristics中写入内容。

接下来，我们一步步来详解这几步操作。

首先第一步肯定是引入CoreBluetooth库。

```swift
import CoreBluetooth
```

#### 创建CBCentralManager

[CBCentralManager](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager)作为Central设备的核心对象，负责处理所有Central的事件，其中包含两个参数，`delegate`和`queue`。这里应该不用过多介绍，delegate用来注册事件回调的函数信息，而queue表示回调时的线程，传递nil则表示使用默认的主线程处理。

```swift
let centralManager = CBCentralManager(delegate: self, queue: nil)
```

在创建时，我们需要关注的是delegate中的[centralManagerDidUpdateState:](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerdelegate/1518888-centralmanagerdidupdatestate)的方法，此方法用来接收Central设备的状态。

```swift
func centralManagerDidUpdateState(_ central: CBCentralManager) {}
```

#### 搜索感兴趣的Peripheral设备

创建好CBCentralManager之后，就可以通过[scanForPeripheralsWithServices:options:](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518986-scanforperipheralswithservices)方法来搜索周围的设备。

```swift
centralManager.scanForPeripherals(withServices: nil, options: nil)
```

这里的两个参数中：
第一个参数表示传递我感兴趣的Peripheral设备的唯一ID，这个ID为蓝牙协议中的一部分，需要注意⚠️的是，这里尽量通过[CBUUID](https://developer.apple.com/documentation/corebluetooth/cbuuid)来创建一个我们的Central设备关心的Peripheral设备的UUID，而不是直接传递nil，因为直接传递nil会导致搜索到附近所有的Peripheral设备。
第二个参数表示传递一些配置内容，详见[Peripheral Scanning Options](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/peripheral_scanning_options)。

当搜索到了感兴趣的内容后，就会通过delegate回调[centralManager:didDiscoverPeripheral:advertisementData:RSSI:](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerdelegate/1518937-centralmanager)

```swift
func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
	print("Discovered \(peripheral.name)")

	// 单个设备
	self.discoveredPeripheral = peripheral
	// 多个设备
	self.discoveredPeripherals.append(peripheral)
}
```

注意的是，这里为了防止Peripheral设备被自动回收，需要对他进行强引用，若只对单个设备感兴趣，则可以直接设置给自己，若对多个设备感兴趣，可以将它加入到数组中管理。

当所有已经期望的Peripheral设备都被找到之后，为了节省电量，可以将扫描停止。

```swift
centralManager.stopScan()
```

#### 连接发现的Peripheral设备

当我们搜索到了感兴趣的Peripheral设备后，可以通过[connectPeripheral:options:](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518766-connect)方法来请求连接。

```swift
centralManager.connect(peripheral, options: nil)
```

如果连接成功，就会收到[centralManager:didConnectPeripheral:](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerdelegate/1518969-centralmanager)的回调。并且为了能够收到Peripheral的回调消息，也需要设置Peripheral的delegate

```swift
func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

	print("Peripheral \(peripheral.name) connected")
	peripheral.delegate = self
}
```

#### 搜索连接到的Peripheral设备中的Services

当Central和Peripheral建立连接后，就可以获取更多Peripheral中提供的数据，其中第一步就是发掘Peripheral中提供的Services。因为在广播阶段Peripheral向外广播的数据量是有限制的，所以可能会在连接之后发现更多Services。要发现Peripheral提供的Services可以通过~[discoverServices:](https://developer.apple.com/documentation/corebluetooth/cbperipheral/1518706-discoverservices)~方法。

```swift
peripheral.discoverServices(nil)
```

和之前的搜索Peripheral时同理，这里传递的参数为nil也表示搜索所有的Services，实际情况中，这里也应该是只传递App中感兴趣的Service的UUID。

一旦发现了Service之后，会通过CBPeripheralDelegate的回调方法[peripheral:didDiscoverServices:](https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/1518744-peripheral)。

```swift
func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
	print("Discover services: \(peripheral.services)")
}
```

#### 搜索发现的Service中的Characteristics

当找到了感兴趣的Service之后，就可以探索次Service中提供的characteristics[discoverCharacteristics:forService:](https://developer.apple.com/documentation/corebluetooth/cbperipheral/1518797-discovercharacteristics)

```swift
peripheral.discoverCharacteristics(nil, for: service)
```

再次！这里的第一个参数传递的nil也是会返回所有搜索到的characteristics，在实际App使用中，应该也是只去搜索感兴趣的characteristics对应的UUID。

一旦发现了Characteristic之后，会通过CBPeripheralDelegate的回调方法[peripheral:didDiscoverCharacteristicsForService:error:](https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/1518821-peripheral)

```swift
func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

	print("Discover characteristics: \(service.characteristics)")
}
```

#### 获取Characteristic中的数据

当我们发现了Characteristic之后，就可以获取其中的数据，包含直接读取或者订阅数据的变化。比如一个温度传感器我们可以直接读取当前的温度，也可以订阅温度的值，监听他的变化。

- 直接读取数据

直接读取数据是可以直接通过[readValueForCharacteristic:](https://developer.apple.com/documentation/corebluetooth/cbperipheral/1518759-readvalue)对Characteristic发起读取数据的请求。但是需要注意的是，并不是所有的Characteristic都支持直接读取数据，所以可以通过检查[properties](https://developer.apple.com/documentation/corebluetooth/cbcharacteristic/1519010-properties)中是否包含[CBCharacteristicPropertyRead](https://developer.apple.com/documentation/corebluetooth/cbcharacteristicproperties/cbcharacteristicpropertyread)。

```swift
guard characteristic.properties.contains(.read) else {
	print("Characteristic not support read value")
	return
}

peripheral.readValue(for: characteristic)
```

当成功的读取了数据之后，会通过CBPeripheralDelegate的回调方法[peripheral:didUpdateValueForCharacteristic:error:](https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/1518708-peripheral)

```swift
func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

	if let data = characteristic.value {
		// parse the data
	}
}
```

当向不支持直接请求数据的Characteristic读取数据时，回调中的error会显示对应的问题

- 订阅数据

订阅数据是可以通过[setNotifyValue:forCharacteristic:](https://developer.apple.com/documentation/corebluetooth/cbperipheral/1518949-setnotifyvalue)对特征数据发起订阅，同样需要注意的是，并不是所有的Characteristic都支持订阅数据，所以可以通过检查[properties](https://developer.apple.com/documentation/corebluetooth/cbcharacteristic/1519010-properties)中是否包含~[CBCharacteristicPropertyNotify](https://developer.apple.com/documentation/corebluetooth/cbcharacteristicproperties/1518976-notify)~或是~[CBCharacteristicPropertyIndicate](https://developer.apple.com/documentation/corebluetooth/cbcharacteristicproperties/1519085-indicate)~

```swift
guard characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) else {
	print("Characteristic not support subscribing")
	return
}

peripheral.setNotifyValue(true, for: characteristic)
```

当成功订阅或者取消订阅了Characteristic之后，会通过CBPeripheralDelegate的回调方法~[peripheral:didUpdateNotificationStateForCharacteristic:error:](https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/1518768-peripheral)~

```swift
func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {

}
```

数据的更新还是会通过**刚刚**的~[peripheral:didUpdateValueForCharacteristic:error:](https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/1518708-peripheral)~方法回调。

#### 向Characteristic中写入数据

当我们想要向Characteristic中写入数据时，可以通过调用~[writeValue:forCharacteristic:type:](https://developer.apple.com/documentation/corebluetooth/cbperipheral/1518747-writevalue)~，同样需要注意的是，并不是所有Characteristic都支持写入数据，所以可以通过检查[properties](https://developer.apple.com/documentation/corebluetooth/cbcharacteristic/1519010-properties)中是否包含~[CBCharacteristicPropertyWriteWithoutResponse](https://developer.apple.com/documentation/corebluetooth/cbcharacteristicproperties/cbcharacteristicpropertywritewithoutresponse)~或~[CBCharacteristicPropertyWrite](https://developer.apple.com/documentation/corebluetooth/cbcharacteristicproperties/1519089-write)~

```swift
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
```

当我们指定了写入类型是需要回复时，即~[CBCharacteristicWriteWithResponse](https://developer.apple.com/documentation/corebluetooth/cbcharacteristicwritetype/cbcharacteristicwritewithresponse)~，我们会在写入消息成功之后收到~[peripheral:didWriteValueForCharacteristic:error:](https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/1518823-peripheral)~回调。

```swift
func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {

}
```

如果是使用~[CBCharacteristicWriteWithoutResponse](https://developer.apple.com/documentation/corebluetooth/cbcharacteristicwritetype/withoutresponse)~，则不会收到任何回调消息。

## 作为Peripheral时的常见操作



## 参考文档

https://developer.apple.com/bluetooth/
[About Core Bluetooth](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/AboutCoreBluetooth/Introduction.html)