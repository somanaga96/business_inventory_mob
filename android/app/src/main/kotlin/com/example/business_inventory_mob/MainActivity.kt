package com.example.business_inventory_mob

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val usbChannel = "inventory/usb_thermal_printer"
    private val usbPermissionAction = "com.example.business_inventory_mob.USB_PERMISSION"
    private var pendingResult: MethodChannel.Result? = null
    private var pendingDevice: UsbDevice? = null
    private var pendingBytes: ByteArray? = null

    private val usbPermissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != usbPermissionAction) return
            val allowed = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
            if (allowed && pendingDevice != null && pendingBytes != null) {
                writeUsb(pendingDevice!!, pendingBytes!!, pendingResult!!)
            } else {
                pendingResult?.error("USB_PERMISSION_DENIED", "USB printer permission was denied", null)
            }
            pendingResult = null
            pendingDevice = null
            pendingBytes = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                usbPermissionReceiver,
                IntentFilter(usbPermissionAction),
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            registerReceiver(usbPermissionReceiver, IntentFilter(usbPermissionAction))
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, usbChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "preferredBluetooth" -> result.success(
                        getSharedPreferences("printer_settings", Context.MODE_PRIVATE)
                            .getString("preferred_bluetooth_address", null)
                    )
                    "setPreferredBluetooth" -> {
                        getSharedPreferences("printer_settings", Context.MODE_PRIVATE)
                            .edit()
                            .putString(
                                "preferred_bluetooth_address",
                                call.argument<String>("address"),
                            )
                            .apply()
                        result.success(null)
                    }
                    "clearPreferredBluetooth" -> {
                        getSharedPreferences("printer_settings", Context.MODE_PRIVATE)
                            .edit()
                            .remove("preferred_bluetooth_address")
                            .apply()
                        result.success(null)
                    }
                    "printers" -> result.success(usbManager().deviceList.values.map { device ->
                        mapOf("id" to device.deviceId, "name" to (device.productName ?: device.deviceName))
                    })
                    "print" -> {
                        val id = call.argument<Int>("id")
                        val bytes = call.argument<ByteArray>("bytes")
                        val device = usbManager().deviceList.values.firstOrNull { it.deviceId == id }
                        if (id == null || bytes == null || device == null) {
                            result.error("USB_PRINTER_NOT_FOUND", "The USB printer is no longer connected", null)
                        } else if (usbManager().hasPermission(device)) {
                            writeUsb(device, bytes, result)
                        } else {
                            pendingResult = result
                            pendingDevice = device
                            pendingBytes = bytes
                            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
                            val permissionIntent = PendingIntent.getBroadcast(this, 0, Intent(usbPermissionAction), flags)
                            usbManager().requestPermission(device, permissionIntent)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        unregisterReceiver(usbPermissionReceiver)
        super.onDestroy()
    }

    private fun usbManager() = getSystemService(Context.USB_SERVICE) as UsbManager

    private fun writeUsb(device: UsbDevice, bytes: ByteArray, result: MethodChannel.Result) {
        val usbInterface = (0 until device.interfaceCount)
            .map { device.getInterface(it) }
            .firstOrNull { usbInterface ->
                (0 until usbInterface.endpointCount).any { endpoint ->
                    val e = usbInterface.getEndpoint(endpoint)
                    e.type == UsbConstants.USB_ENDPOINT_XFER_BULK && e.direction == UsbConstants.USB_DIR_OUT
                }
            }
        if (usbInterface == null) {
            result.error("USB_ENDPOINT_NOT_FOUND", "No USB bulk output endpoint was found on this device", null)
            return
        }
        val endpoint = (0 until usbInterface.endpointCount)
            .map { usbInterface.getEndpoint(it) }
            .first { it.type == UsbConstants.USB_ENDPOINT_XFER_BULK && it.direction == UsbConstants.USB_DIR_OUT }
        val connection = usbManager().openDevice(device)
        if (connection == null || !connection.claimInterface(usbInterface, true)) {
            result.error("USB_CONNECTION_FAILED", "Could not open the USB printer", null)
            return
        }
        try {
            var offset = 0
            while (offset < bytes.size) {
                val chunk = bytes.copyOfRange(offset, minOf(offset + 4096, bytes.size))
                val sent = connection.bulkTransfer(endpoint, chunk, chunk.size, 10000)
                if (sent <= 0) throw IllegalStateException("Printer did not accept receipt data")
                offset += sent
            }
            result.success(true)
        } catch (error: Exception) {
            result.error("USB_WRITE_FAILED", error.message, null)
        } finally {
            connection.releaseInterface(usbInterface)
            connection.close()
        }
    }
}
