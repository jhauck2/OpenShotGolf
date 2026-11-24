package com.godot.game;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.ParcelUuid;
import android.util.Log;
import java.util.List;
import java.util.UUID;

public class GodotBleHelper {
    private static final String TAG = "GodotBleHelper";
    private static final Handler sMainHandler = new Handler(Looper.getMainLooper());
    private static final UUID CLIENT_CONFIG_DESCRIPTOR_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");
    private static Context sContext;

    public static void setContext(Context context) {
        if (context != null) {
            sContext = context.getApplicationContext();
        }
    }

    public static Context getContext() {
        return sContext;
    }

    public interface ScanListener {
        void onDeviceDiscovered(String deviceId, String name, int rssi);
    }

    public interface GattListener {
        void onConnectionStateChange(int status, int newState);
        void onServicesDiscovered(int status);
        void onCharacteristicRead(String uuid, byte[] value, int status);
        void onCharacteristicWrite(String uuid, int status);
        void onCharacteristicChanged(String uuid, byte[] value);
        void onMtuChanged(int mtu, int status);
    }

    public static ScanCallback createScanCallback(final ScanListener listener) {
        return new ScanCallback() {
            @Override
            public void onScanResult(int callbackType, final ScanResult result) {
                if (result == null || result.getDevice() == null || listener == null) return;
                try {
                    final String deviceId = result.getDevice().getAddress();
                    String devName = result.getDevice().getName();
                    ScanRecord record = result.getScanRecord();

                    // On Android, unbonded BLE peripherals often return null from getDevice().getName().
                    // The actual advertised name is stored in the ScanRecord.
                    if ((devName == null || devName.trim().isEmpty()) && record != null) {
                        devName = record.getDeviceName();
                    }

                    // If still empty, inspect advertised service UUIDs for known launch monitors
                    if ((devName == null || devName.trim().isEmpty()) && record != null && record.getServiceUuids() != null) {
                        for (ParcelUuid parcelUuid : record.getServiceUuids()) {
                            if (parcelUuid != null) {
                                String uuidStr = parcelUuid.getUuid().toString().toLowerCase();
                                if (uuidStr.contains("6a4e2800") || uuidStr.contains("6a4e3400")) {
                                    devName = "Approach R10";
                                    break;
                                } else if (uuidStr.contains("86602100") || uuidStr.contains("86602000") || uuidStr.contains("86602101")) {
                                    devName = "Square Golf";
                                    break;
                                }
                            }
                        }
                    }

                    final String name = devName != null ? devName : "";
                    final int rssi = result.getRssi();

                    sMainHandler.post(new Runnable() {
                        @Override
                        public void run() {
                            try {
                                listener.onDeviceDiscovered(deviceId, name, rssi);
                            } catch (Throwable t) {
                                Log.e(TAG, "Error in onDeviceDiscovered callback", t);
                            }
                        }
                    });
                } catch (Throwable t) {
                    Log.e(TAG, "Error processing onScanResult", t);
                }
            }

            @Override
            public void onBatchScanResults(List<ScanResult> results) {
                if (results == null) return;
                for (ScanResult result : results) {
                    onScanResult(0, result);
                }
            }

            @Override
            public void onScanFailed(int errorCode) {
                String errorReason;
                switch (errorCode) {
                    case 1: errorReason = "SCAN_FAILED_ALREADY_STARTED"; break;
                    case 2: errorReason = "SCAN_FAILED_APPLICATION_REGISTRATION_FAILED"; break;
                    case 3: errorReason = "SCAN_FAILED_INTERNAL_ERROR"; break;
                    case 4: errorReason = "SCAN_FAILED_FEATURE_UNSUPPORTED"; break;
                    case 5: errorReason = "SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES"; break;
                    case 6: errorReason = "SCAN_FAILED_SCANNING_TOO_FREQUENTLY"; break;
                    default: errorReason = "UNKNOWN_ERROR (" + errorCode + ")"; break;
                }
                Log.w(TAG, "BLE scan failed with errorCode: " + errorCode + " (" + errorReason + ")");
            }
        };
    }

    public static BluetoothGattCallback createGattCallback(final GattListener listener) {
        return new BluetoothGattCallback() {
            @Override
            public void onConnectionStateChange(BluetoothGatt gatt, final int status, final int newState) {
                if (status == BluetoothGatt.GATT_SUCCESS && newState == 2 /* STATE_CONNECTED */) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        try {
                            Log.d(TAG, "Connected to GATT server. Proactively requesting MTU 512...");
                            gatt.requestMtu(512);
                        } catch (Throwable t) {
                            Log.w(TAG, "Could not proactively request MTU", t);
                        }
                    }
                }
                if (listener == null) return;
                sMainHandler.post(new Runnable() {
                    @Override
                    public void run() {
                        try {
                            listener.onConnectionStateChange(status, newState);
                        } catch (Throwable t) {
                            Log.e(TAG, "Error in onConnectionStateChange callback", t);
                        }
                    }
                });
            }

            @Override
            public void onServicesDiscovered(BluetoothGatt gatt, final int status) {
                if (listener == null) return;
                sMainHandler.post(new Runnable() {
                    @Override
                    public void run() {
                        try {
                            listener.onServicesDiscovered(status);
                        } catch (Throwable t) {
                            Log.e(TAG, "Error in onServicesDiscovered callback", t);
                        }
                    }
                });
            }

            // Legacy callback for Android < 13
            @Override
            public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, final int status) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    // Handled by the 4-argument overload below on Android 13+
                    return;
                }
                if (listener == null || characteristic == null) return;
                try {
                    final String uuid = characteristic.getUuid().toString();
                    byte[] rawVal = characteristic.getValue();
                    final byte[] value = (rawVal != null) ? rawVal : new byte[0];

                    sMainHandler.post(new Runnable() {
                        @Override
                        public void run() {
                            try {
                                listener.onCharacteristicRead(uuid, value, status);
                            } catch (Throwable t) {
                                Log.e(TAG, "Error in legacy onCharacteristicRead callback", t);
                            }
                        }
                    });
                } catch (Throwable t) {
                    Log.e(TAG, "Error processing legacy onCharacteristicRead", t);
                }
            }

            // Android 13+ (API 33+) callback
            @Override
            public void onCharacteristicRead(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, final byte[] value, final int status) {
                if (listener == null || characteristic == null) return;
                try {
                    final String uuid = characteristic.getUuid().toString();
                    final byte[] finalVal = (value != null) ? value : new byte[0];

                    sMainHandler.post(new Runnable() {
                        @Override
                        public void run() {
                            try {
                                listener.onCharacteristicRead(uuid, finalVal, status);
                            } catch (Throwable t) {
                                Log.e(TAG, "Error in onCharacteristicRead (API 33+) callback", t);
                            }
                        }
                    });
                } catch (Throwable t) {
                    Log.e(TAG, "Error processing onCharacteristicRead (API 33+)", t);
                }
            }

            @Override
            public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, final int status) {
                if (listener == null || characteristic == null) return;
                try {
                    final String uuid = characteristic.getUuid().toString();
                    sMainHandler.post(new Runnable() {
                        @Override
                        public void run() {
                            try {
                                listener.onCharacteristicWrite(uuid, status);
                            } catch (Throwable t) {
                                Log.e(TAG, "Error in onCharacteristicWrite callback", t);
                            }
                        }
                    });
                } catch (Throwable t) {
                    Log.e(TAG, "Error processing onCharacteristicWrite", t);
                }
            }

            // Legacy callback for Android < 13
            @Override
            public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    // Handled by the 3-argument overload below on Android 13+
                    return;
                }
                if (listener == null || characteristic == null) return;
                try {
                    final String uuid = characteristic.getUuid().toString();
                    byte[] rawVal = characteristic.getValue();
                    final byte[] value = (rawVal != null) ? rawVal : new byte[0];

                    sMainHandler.post(new Runnable() {
                        @Override
                        public void run() {
                            try {
                                listener.onCharacteristicChanged(uuid, value);
                            } catch (Throwable t) {
                                Log.e(TAG, "Error in legacy onCharacteristicChanged callback", t);
                            }
                        }
                    });
                } catch (Throwable t) {
                    Log.e(TAG, "Error processing legacy onCharacteristicChanged", t);
                }
            }

            // Android 13+ (API 33+) callback
            @Override
            public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, final byte[] value) {
                if (listener == null || characteristic == null) return;
                try {
                    final String uuid = characteristic.getUuid().toString();
                    final byte[] finalVal = (value != null) ? value : new byte[0];

                    sMainHandler.post(new Runnable() {
                        @Override
                        public void run() {
                            try {
                                listener.onCharacteristicChanged(uuid, finalVal);
                            } catch (Throwable t) {
                                Log.e(TAG, "Error in onCharacteristicChanged (API 33+) callback", t);
                            }
                        }
                    });
                } catch (Throwable t) {
                    Log.e(TAG, "Error processing onCharacteristicChanged (API 33+)", t);
                }
            }

            @Override
            public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.d(TAG, "Descriptor write success: " + (descriptor != null ? descriptor.getUuid() : "null"));
                } else {
                    Log.w(TAG, "Descriptor write failed with status: " + status);
                }
            }

            @Override
            public void onMtuChanged(BluetoothGatt gatt, final int mtu, final int status) {
                Log.d(TAG, "onMtuChanged: mtu=" + mtu + ", status=" + status);
                if (listener == null) return;
                sMainHandler.post(new Runnable() {
                    @Override
                    public void run() {
                        try {
                            listener.onMtuChanged(mtu, status);
                        } catch (Throwable t) {
                            Log.e(TAG, "Error in onMtuChanged callback", t);
                        }
                    }
                });
            }
        };
    }

    public static boolean requestMtu(BluetoothGatt gatt, int mtu) {
        if (gatt == null) return false;
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                Log.d(TAG, "Requesting MTU: " + mtu);
                return gatt.requestMtu(mtu);
            }
        } catch (Throwable t) {
            Log.e(TAG, "Exception during requestMtu", t);
        }
        return false;
    }

    public static BluetoothGatt connectGatt(BluetoothDevice device, Context context, BluetoothGattCallback callback) {
        if (context == null) {
            context = sContext;
        }
        if (device == null || context == null || callback == null) {
            Log.e(TAG, "connectGatt called with null parameter(s): device=" + device + ", context=" + context + ", callback=" + callback);
            return null;
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                return device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE);
            } else {
                return device.connectGatt(context, false, callback);
            }
        } catch (Throwable t) {
            Log.e(TAG, "Exception during connectGatt", t);
            return null;
        }
    }

    public static boolean discoverServices(BluetoothGatt gatt) {
        if (gatt == null) return false;
        try {
            return gatt.discoverServices();
        } catch (Throwable t) {
            Log.e(TAG, "Exception during discoverServices", t);
            return false;
        }
    }

    public static String getDiscoveredCharacteristicsSummary(BluetoothGatt gatt) {
        if (gatt == null) return "";
        StringBuilder sb = new StringBuilder();
        try {
            List<BluetoothGattService> services = gatt.getServices();
            if (services == null) return "";
            for (BluetoothGattService service : services) {
                if (service == null || service.getUuid() == null) continue;
                String serviceUuid = service.getUuid().toString();
                List<BluetoothGattCharacteristic> chars = service.getCharacteristics();
                if (chars == null) continue;
                for (BluetoothGattCharacteristic ch : chars) {
                    if (ch == null || ch.getUuid() == null) continue;
                    sb.append(serviceUuid)
                      .append('|')
                      .append(ch.getUuid().toString())
                      .append('|')
                      .append(ch.getProperties())
                      .append('\n');
                }
            }
        } catch (Throwable t) {
            Log.e(TAG, "Exception during getDiscoveredCharacteristicsSummary", t);
        }
        return sb.toString();
    }

    public static BluetoothGattCharacteristic findCharacteristic(BluetoothGatt gatt, String uuidStr) {
        if (gatt == null || uuidStr == null) return null;
        try {
            UUID targetUuid = UUID.fromString(uuidStr);
            List<BluetoothGattService> services = gatt.getServices();
            if (services == null) return null;
            for (BluetoothGattService service : services) {
                if (service == null) continue;
                BluetoothGattCharacteristic ch = service.getCharacteristic(targetUuid);
                if (ch != null) {
                    return ch;
                }
            }
        } catch (Throwable t) {
            Log.e(TAG, "Exception during findCharacteristic: " + uuidStr, t);
        }
        return null;
    }

    public static boolean readCharacteristic(BluetoothGatt gatt, String uuidStr) {
        if (gatt == null || uuidStr == null) return false;
        try {
            BluetoothGattCharacteristic ch = findCharacteristic(gatt, uuidStr);
            if (ch == null) {
                Log.e(TAG, "readCharacteristic: characteristic not found: " + uuidStr);
                return false;
            }
            return gatt.readCharacteristic(ch);
        } catch (Throwable t) {
            Log.e(TAG, "Exception during readCharacteristic: " + uuidStr, t);
            return false;
        }
    }

    public static boolean writeCharacteristic(BluetoothGatt gatt, String uuidStr, byte[] data, int writeType) {
        if (gatt == null || uuidStr == null || data == null) return false;
        try {
            BluetoothGattCharacteristic ch = findCharacteristic(gatt, uuidStr);
            if (ch == null) {
                Log.e(TAG, "writeCharacteristic: characteristic not found: " + uuidStr);
                return false;
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                int res = gatt.writeCharacteristic(ch, data, writeType);
                return res == BluetoothGatt.GATT_SUCCESS;
            } else {
                ch.setValue(data);
                ch.setWriteType(writeType);
                return gatt.writeCharacteristic(ch);
            }
        } catch (Throwable t) {
            Log.e(TAG, "Exception during writeCharacteristic: " + uuidStr, t);
            return false;
        }
    }

    public static boolean subscribeCharacteristic(BluetoothGatt gatt, String uuidStr) {
        if (gatt == null || uuidStr == null) return false;
        try {
            BluetoothGattCharacteristic ch = findCharacteristic(gatt, uuidStr);
            if (ch == null) {
                Log.e(TAG, "subscribeCharacteristic: characteristic not found: " + uuidStr);
                return false;
            }
            boolean success = gatt.setCharacteristicNotification(ch, true);
            if (!success) {
                Log.w(TAG, "setCharacteristicNotification returned false for: " + uuidStr);
            }

            BluetoothGattDescriptor descriptor = ch.getDescriptor(CLIENT_CONFIG_DESCRIPTOR_UUID);
            if (descriptor != null) {
                byte[] enableVal = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    int res = gatt.writeDescriptor(descriptor, enableVal);
                    return res == BluetoothGatt.GATT_SUCCESS;
                } else {
                    descriptor.setValue(enableVal);
                    return gatt.writeDescriptor(descriptor);
                }
            } else {
                Log.w(TAG, "subscribeCharacteristic: CCCD not found on characteristic: " + uuidStr);
                return success;
            }
        } catch (Throwable t) {
            Log.e(TAG, "Exception during subscribeCharacteristic: " + uuidStr, t);
            return false;
        }
    }

    public static void disconnectGatt(BluetoothGatt gatt) {
        if (gatt == null) return;
        try {
            gatt.disconnect();
        } catch (Throwable t) {
            Log.w(TAG, "Exception during gatt.disconnect", t);
        }
        try {
            gatt.close();
        } catch (Throwable t) {
            Log.w(TAG, "Exception during gatt.close", t);
        }
    }
}
