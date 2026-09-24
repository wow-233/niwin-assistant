package app.shiguang.shiguang_schedule

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.ContentValues
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val channelName = "app.shiguang/calendar"
    private val permissionRequest = 5201
    private val bluetoothPermissionRequest = 5202
    private var pendingCall: MethodCall? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBluetoothResult: MethodChannel.Result? = null
    private val handler = Handler(Looper.getMainLooper())
    private var bluetoothScanCallback: ScanCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.shiguang/quzhi")
            .setMethodCallHandler { call, result ->
                if (call.method != "scanNearby") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val permissions = bluetoothPermissions()
                if (permissions.all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }) {
                    startBluetoothScan(result)
                } else {
                    pendingBluetoothResult = result
                    requestPermissions(permissions, bluetoothPermissionRequest)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "replaceCourseEvents") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED &&
                    checkSelfPermission(Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED) {
                    writeEvents(call, result)
                } else {
                    pendingCall = call
                    pendingResult = result
                    requestPermissions(
                        arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR),
                        permissionRequest,
                    )
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == bluetoothPermissionRequest) {
            val result = pendingBluetoothResult
            pendingBluetoothResult = null
            if (result != null) {
                if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                    startBluetoothScan(result)
                } else {
                    result.error("bluetooth_permission_denied", "未获得附近设备权限", null)
                }
            }
            return
        }
        if (requestCode != permissionRequest) return
        val call = pendingCall
        val result = pendingResult
        pendingCall = null
        pendingResult = null
        if (call == null || result == null) return
        if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            writeEvents(call, result)
        } else {
            result.error("calendar_permission_denied", "未获得日历读写权限", null)
        }
    }

    private fun bluetoothPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    @SuppressLint("MissingPermission")
    private fun startBluetoothScan(result: MethodChannel.Result) {
        if (bluetoothScanCallback != null) {
            result.error("scan_in_progress", "附近设备扫描正在进行", null)
            return
        }
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("bluetooth_unavailable", "当前设备不支持蓝牙", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("bluetooth_disabled", "请先开启系统蓝牙", null)
            return
        }
        val scanner = adapter.bluetoothLeScanner
        if (scanner == null) {
            result.error("scanner_unavailable", "无法启动蓝牙扫描", null)
            return
        }
        val devices = linkedMapOf<String, Map<String, Any>>()
        var completed = false
        fun finish(errorCode: Int? = null) {
            if (completed) return
            completed = true
            bluetoothScanCallback?.let { runCatching { scanner.stopScan(it) } }
            bluetoothScanCallback = null
            if (errorCode == null) {
                result.success(devices.values.toList())
            } else {
                result.error("bluetooth_scan_failed", "蓝牙扫描失败（$errorCode）", null)
            }
        }
        val callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, scanResult: ScanResult) {
                val name = scanResult.scanRecord?.deviceName
                    ?: runCatching { scanResult.device.name }.getOrNull()
                    ?: return
                if (!name.startsWith("KLCXKJ") || scanResult.rssi < -90) return
                val address = runCatching { scanResult.device.address }.getOrNull() ?: return
                val normalized = if (address.uppercase().startsWith("C0")) {
                    "00${address.drop(2)}"
                } else {
                    address.uppercase()
                }
                val advertised = name.substringAfterLast(',', "").trim().uppercase()
                val snCode = if (advertised.length == 12 && advertised.all { it.isDigit() || it in 'A'..'F' }) {
                    advertised
                } else {
                    normalized.replace(":", "")
                }
                val previousRssi = devices[normalized]?.get("rssi") as? Int
                if (previousRssi != null && previousRssi >= scanResult.rssi) return
                devices[normalized] = mapOf(
                    "name" to name,
                    "address" to normalized,
                    "snCode" to snCode,
                    "rssi" to scanResult.rssi,
                )
            }

            override fun onScanFailed(errorCode: Int) {
                finish(errorCode)
            }
        }
        bluetoothScanCallback = callback
        try {
            scanner.startScan(
                null,
                ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),
                callback,
            )
            handler.postDelayed({ finish() }, 12_000L)
        } catch (error: Exception) {
            bluetoothScanCallback = null
            result.error("bluetooth_scan_failed", error.message ?: "蓝牙扫描启动失败", null)
        }
    }

    private fun writeEvents(call: MethodCall, result: MethodChannel.Result) {
        Thread {
          try {
            val calendar = findWritableCalendar()
                ?: throw IllegalStateException("设备中没有可写的系统日历")
            val calendarId = calendar.first
            val calendarName = calendar.second
            contentResolver.delete(
                CalendarContract.Events.CONTENT_URI,
                "${CalendarContract.Events.CALENDAR_ID}=? AND ${CalendarContract.Events.DESCRIPTION} LIKE ?",
                arrayOf(calendarId.toString(), "[泥win助手:%"),
            )
            @Suppress("UNCHECKED_CAST")
            val events = call.argument<List<Map<String, Any?>>>("events") ?: emptyList()
            var count = 0
            for (event in events) {
                val values = ContentValues().apply {
                    put(CalendarContract.Events.CALENDAR_ID, calendarId)
                    put(CalendarContract.Events.TITLE, event["title"]?.toString() ?: "课程")
                    put(CalendarContract.Events.EVENT_LOCATION, event["location"]?.toString() ?: "")
                    put(CalendarContract.Events.DESCRIPTION, event["description"]?.toString() ?: "[泥win助手]")
                    put(CalendarContract.Events.DTSTART, (event["start"] as Number).toLong())
                    put(CalendarContract.Events.DTEND, (event["end"] as Number).toLong())
                    put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
                }
                val uri = contentResolver.insert(CalendarContract.Events.CONTENT_URI, values) ?: continue
                val eventId = uri.lastPathSegment?.toLongOrNull() ?: continue
                val minutes = (event["reminderMinutes"] as? Number)?.toInt() ?: 15
                contentResolver.insert(
                    CalendarContract.Reminders.CONTENT_URI,
                    ContentValues().apply {
                        put(CalendarContract.Reminders.EVENT_ID, eventId)
                        put(CalendarContract.Reminders.MINUTES, minutes)
                        put(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_ALERT)
                    },
                )
                count++
            }
            runOnUiThread {
                result.success(mapOf("count" to count, "calendarName" to calendarName))
            }
          } catch (error: Exception) {
            runOnUiThread {
                result.error("calendar_write_failed", error.message ?: "写入日历失败", null)
            }
          }
        }.start()
    }

    private fun findWritableCalendar(): Pair<Long, String>? {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.IS_PRIMARY,
        )
        val selection = "${CalendarContract.Calendars.VISIBLE}=1 AND " +
            "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL}>=?"
        contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            arrayOf(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString()),
            "${CalendarContract.Calendars.IS_PRIMARY} DESC",
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return Pair(cursor.getLong(0), cursor.getString(1) ?: "系统日历")
            }
        }
        return null
    }
}
