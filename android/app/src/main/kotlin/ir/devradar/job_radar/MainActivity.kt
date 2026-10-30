package ir.devradar.job_radar

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "ir.devradar.job_radar/native_settings"
    private val networkExecutor = Executors.newCachedThreadPool()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "areNotificationsEnabled" -> {
                    val enabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
                    result.success(enabled)
                }
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent()
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            intent.action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                            intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            intent.action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                            intent.data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.localizedMessage, null)
                    }
                }
                "isBatteryOptimizationIgnored" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        val isIgnored = powerManager.isIgnoringBatteryOptimizations(packageName)
                        result.success(isIgnored)
                    } else {
                        result.success(true)
                    }
                }
                "requestIgnoreBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            // Fallback to general battery settings if direct request fails
                            try {
                                val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                startActivity(fallback)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("ERROR", e2.localizedMessage, null)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                "fetchUrlBypassVpn" -> {
                    val targetUrl = call.argument<String>("url")
                    val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
                    if (targetUrl.isNullOrBlank()) {
                        result.error("INVALID_URL", "URL is required", null)
                        return@setMethodCallHandler
                    }
                    networkExecutor.execute {
                        val html = fetchOverNonVpnNetwork(targetUrl, headers)
                        mainHandler.post {
                            result.success(html)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * ارسال درخواست مستقیم از طریق شبکه وای‌فای یا دیتای سیم‌کارت ایران (NET_CAPABILITY_NOT_VPN)
     * برای دور زدن خطای 403 فایروال آروان‌کلود جابینجا زمانی که فیلترشکن (VPN) کاربر روشن است.
     */
    private fun fetchOverNonVpnNetwork(urlStr: String, headers: Map<String, String>): String? {
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            var chosenNetwork: Network? = null

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val networks = cm.allNetworks
                for (net in networks) {
                    val caps = cm.getNetworkCapabilities(net) ?: continue
                    val isNotVpn = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                    val hasInternet = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                    val isWifiOrCell = caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ||
                            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
                    if (isNotVpn && hasInternet && isWifiOrCell) {
                        chosenNetwork = net
                        break
                    }
                }
            }

            val url = URL(urlStr)
            val connection = (chosenNetwork?.openConnection(url) ?: url.openConnection()) as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 10000
            connection.readTimeout = 10000
            connection.instanceFollowRedirects = true

            for ((k, v) in headers) {
                connection.setRequestProperty(k, v)
            }

            val code = connection.responseCode
            if (code in 200..299) {
                BufferedReader(InputStreamReader(connection.inputStream, Charsets.UTF_8)).use { reader ->
                    return reader.readText()
                }
            }
        } catch (_: Exception) {
        }
        return null
    }
}


