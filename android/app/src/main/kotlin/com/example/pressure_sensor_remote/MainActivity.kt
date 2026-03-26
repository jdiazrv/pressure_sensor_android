package com.example.pressure_sensor_remote

import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    private var multicastLock: WifiManager.MulticastLock? = null

    override fun onResume() {
        super.onResume()
        if (multicastLock == null) {
            val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
            multicastLock = wifiManager.createMulticastLock("pressure_sensor_udp").also {
                it.setReferenceCounted(false)
            }
        }
        multicastLock?.acquire()
    }

    override fun onPause() {
        super.onPause()
        multicastLock?.release()
    }
}
