package app.shiguang.shiguang_schedule

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val channelName = "app.shiguang/calendar"
    private val permissionRequest = 5201
    private var pendingCall: MethodCall? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.shiguang/external_apps")
            .setMethodCallHandler { call, result ->
                if (call.method != "launchPackage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val packageName = call.argument<String>("package")
                val intent = packageName?.let { packageManager.getLaunchIntentForPackage(it) }
                if (intent == null) {
                    result.success(false)
                } else {
                    intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
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
