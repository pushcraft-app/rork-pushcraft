package com.rork.pushcraftandroid.data

import com.rork.pushcraftandroid.Config
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.exceptions.HttpRequestException
import io.github.jan.supabase.exceptions.RestException
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.storage.Storage
import io.ktor.client.plugins.HttpRequestTimeoutException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import java.io.IOException

/** The app's single Supabase client plus shared decoding and error helpers. */
object Backend {
    val client: SupabaseClient by lazy {
        createSupabaseClient(
            supabaseUrl = Config.EXPO_PUBLIC_SUPABASE_URL,
            supabaseKey = Config.EXPO_PUBLIC_SUPABASE_ANON_KEY
        ) {
            install(Auth) {
                scheme = "pushcraft"
                host = "auth-callback"
            }
            install(Postgrest)
            install(Storage)
            install(Realtime)
            install(Functions)
        }
    }

    val json = Json {
        ignoreUnknownKeys = true
        explicitNulls = false
        coerceInputValues = true
    }

    const val appVersion = "1.0.0"

    /** Calls a database function and returns the raw JSON body. */
    suspend fun rpc(function: String, params: JsonObject? = null): String {
        val result = if (params == null) {
            client.postgrest.rpc(function)
        } else {
            client.postgrest.rpc(function, params)
        }
        return result.data
    }

    suspend inline fun <reified T> rpcDecode(function: String, params: JsonObject? = null): T =
        json.decodeFromString(rpc(function, params))
}

/** Classifies backend errors into offline vs. server-reported codes. */
object BackendFailure {
    /** True when the error message contains the given `RAISE EXCEPTION` code. */
    fun hasCode(error: Throwable, code: String): Boolean {
        val rest = error as? RestException
        return rest?.error?.contains(code) == true || error.message?.contains(code) == true
    }

    fun isOffline(error: Throwable): Boolean {
        var current: Throwable? = error
        while (current != null) {
            if (current is HttpRequestException || current is IOException || current is HttpRequestTimeoutException) return true
            current = current.cause
        }
        return false
    }
}
