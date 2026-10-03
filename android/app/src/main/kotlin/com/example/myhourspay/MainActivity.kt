package com.example.myhourspay

import android.os.CancellationSignal
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var cancellation: CancellationSignal? = null
    private val executor = Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "myhourspay/google_identity").setMethodCallHandler { call, result ->
            if (call.method != "authenticate") { result.notImplemented(); return@setMethodCallHandler }
            if (pending != null) { result.error("google_busy", "Sign-in in progress", null); return@setMethodCallHandler }
            val client = call.argument<String>("serverClientId")
            val nonce = call.argument<String>("nonce")
            if (client.isNullOrBlank() || nonce == null || !nonce.matches(Regex("^[0-9a-f]{64}$"))) {
                result.error("google_configuration", "Invalid sign-in configuration", null); return@setMethodCallHandler
            }
            pending = result
            val signal = CancellationSignal()
            cancellation = signal
            try {
                val option = GetSignInWithGoogleOption.Builder(client).setNonce(nonce).build()
                val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
                CredentialManager.create(this).getCredentialAsync(this, request, signal, executor,
                    object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                        override fun onResult(response: GetCredentialResponse) {
                            runOnUiThread {
                                if (pending !== result) return@runOnUiThread
                                pending = null; cancellation = null
                                try {
                                    val credential = response.credential
                                    if (credential !is CustomCredential || credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                                        result.error("google_unavailable", "Unexpected credential type", null)
                                    } else {
                                        val google = GoogleIdTokenCredential.createFrom(credential.data)
                                        result.success(mapOf("idToken" to google.idToken, "name" to (google.displayName ?: "")))
                                    }
                                } catch (_: Exception) { result.error("google_unavailable", "Could not read credential", null) }
                            }
                        }
                        override fun onError(e: GetCredentialException) {
                            runOnUiThread {
                                if (pending !== result) return@runOnUiThread
                                pending = null; cancellation = null
                                result.error(if (e is GetCredentialCancellationException) "google_canceled" else "google_unavailable", "Google sign-in did not complete", null)
                            }
                        }
                    })
            } catch (_: Exception) {
                pending = null; cancellation = null
                result.error("google_unavailable", "Google sign-in did not complete", null)
            }
        }
    }
    override fun onDestroy() {
        cancellation?.cancel()
        pending?.error("google_canceled", "Sign-in closed", null)
        pending = null; cancellation = null
        executor.shutdown()
        super.onDestroy()
    }
}
