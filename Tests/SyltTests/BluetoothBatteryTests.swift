import XCTest
@testable import Sylt

final class BluetoothBatteryTests: XCTestCase {
    func testNormaliseStripsSeparators() {
        XCTAssertEqual(BluetoothBattery.normalise("AA-BB-CC-DD-EE-FF"), "aabbccddeeff")
        XCTAssertEqual(BluetoothBattery.normalise("aa:bb:cc:dd:ee:ff"), BluetoothBattery.normalise("AA-BB-CC-DD-EE-FF"))
    }

    func testProfilerParsingTakesTheLowestBud() {
        let json = """
        {"SPBluetoothDataType": [{"device_connected": [
            {"AirPods Pro": {"device_batteryLevelLeft": "72%", "device_batteryLevelRight": "64%", "device_batteryLevelCase": "90%"}},
            {"Magic Mouse": {"device_batteryLevelMain": "18%"}}
        ]}]}
        """
        let data = Data(json.utf8)
        XCTAssertEqual(BluetoothBattery.parse(data, name: "AirPods Pro"), 64)
        XCTAssertEqual(BluetoothBattery.parse(data, name: "Magic Mouse"), 18)
        XCTAssertNil(BluetoothBattery.parse(data, name: "Unknown"))
    }
}
