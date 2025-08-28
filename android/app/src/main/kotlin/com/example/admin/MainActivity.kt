package com.example.admin

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "quality"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getKpis30d" -> {
                            // TODO: trocar por sua fonte real (MySQL/Python/etc.)
                            val json = mapOf(
                                "total_itens" to 100,
                                "qtd_aprovadas" to 82,
                                "qtd_alertas" to 9,
                                "qtd_reprovadas" to 9
                            )
                            result.success(json)
                        }
                        "getTopFalhasPorTitulo30d" -> {
                            val items = listOf(
                                mapOf("titulo" to "Diâmetro", "total_itens" to 40, "reprovadas" to 7, "pct_reprovadas" to 17.5),
                                mapOf("titulo" to "Rugosidade (Ra)", "total_itens" to 12, "reprovadas" to 1, "pct_reprovadas" to 8.3)
                            )
                            result.success(mapOf("items" to items))
                        }
                        "getTopFalhasPorInstrumento30d" -> {
                            val items = listOf(
                                mapOf("instrumento" to "MICRÔMETRO", "total_itens" to 30, "reprovadas" to 6, "pct_reprovadas" to 20.0),
                                mapOf("instrumento" to "RUGOSÍMETRO", "total_itens" to 18, "reprovadas" to 2, "pct_reprovadas" to 11.1)
                            )
                            result.success(mapOf("items" to items))
                        }
                        "getRecentOs" -> {
                            val limit = (call.argument<Int>("limit") ?: 10)
                            val items = listOf(
                                mapOf("os" to "373","descricao" to "PINO ISO 2341","cliente" to "M.B.Br","atualizado_em" to "2025-08-28T12:00:00Z"),
                                mapOf("os" to "3596","descricao" to "BANJO E10-S","cliente" to "M.B.Br","atualizado_em" to "2025-08-28T10:10:00Z")
                            ).take(limit)
                            result.success(mapOf("items" to items))
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("ERR", e.message, null)
                }
            }
    }
}