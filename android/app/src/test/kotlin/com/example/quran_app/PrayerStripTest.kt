package com.example.quran_app

import java.io.File
import java.util.Calendar
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PrayerStripTest {

    private val minutes = listOf(292, 701, 879, 1018, 1096)

    private fun dayOf(key: String) = PrayerStripDay(
        dateKey = key,
        cells = minutes.mapIndexed { i, m -> PrayerCellNative("p$i", "t$i", m) },
        hijriDateLabel = "",
        weekdayLabel = "",
        localeCode = "ar",
        isFriday = false,
    )

    private fun windowOf(vararg keys: String) = PrayerStripWindow(keys.map { dayOf(it) })

    private val window = windowOf("15-11-2026", "16-11-2026")

    private val json = """
        {"days":[{"dateKey":"15-11-2026","hijriDateLabel":"٢٤ جمادى الأولى","weekdayLabel":"الأحد",
          "localeCode":"ar","isFriday":false,"nextTag":"التالية","nextPrayerIndex":2,
          "cells":[
            {"label":"الفجر","time":"٤:٥٢","minutes":292,"nextLabel":"الفجر بعد"},
            {"label":"الظهر","time":"١١:٤١","minutes":701,"nextLabel":"الظهر بعد"},
            {"label":"العصر","time":"٢:٣٩","minutes":879,"nextLabel":"العصر بعد"},
            {"label":"المغرب","time":"٤:٥٨","minutes":1018,"nextLabel":"المغرب بعد"},
            {"label":"العشاء","time":"٦:١٦","minutes":1096,"nextLabel":"العشاء بعد"}]}],
         "style":{"expanded":false,"countdown":true,"highlightDay":"#FF9A3B3B","highlightNight":"#FFE7A3A3",
          "pillTextDay":"#FFFFFFFF","pillTextNight":"#FF121413","backgroundNight":"#FF2E2A20","shape":"pill"}}
    """.trimIndent()

    private val legacyJson = """
        {"days":[{"dateKey":"15-11-2026","hijriDateLabel":"x","weekdayLabel":"y","localeCode":"ar",
          "isFriday":false,"accentColor":"#FF2E5244",
          "cells":[{"label":"الفجر","time":"٤:٥٢","minutes":292}]}]}
    """.trimIndent()

    @Test fun pickDay_beforeIshaHighlightsTodaysNext() {
        val (day, idx) = PrayerStripController.pickDay(window, "15-11-2026", "16-11-2026", 14 * 60)!!
        assertEquals("15-11-2026", day.dateKey)
        assertEquals(2, idx)
    }

    @Test fun pickDay_atPrayerMinuteMovesToTheNextPrayer() {
        val (_, idx) = PrayerStripController.pickDay(window, "15-11-2026", "16-11-2026", 879)!!
        assertEquals(3, idx)
    }

    @Test fun pickDay_beforeFajrHighlightsFajr() {
        val (day, idx) = PrayerStripController.pickDay(window, "15-11-2026", "16-11-2026", 30)!!
        assertEquals("15-11-2026", day.dateKey)
        assertEquals(0, idx)
    }

    @Test fun pickDay_afterIshaShowsTomorrowWithFajr() {
        val (day, idx) = PrayerStripController.pickDay(window, "15-11-2026", "16-11-2026", 20 * 60)!!
        assertEquals("16-11-2026", day.dateKey)
        assertEquals(0, idx)
    }

    @Test fun pickDay_afterIshaWithoutTomorrowHighlightsNothing() {
        val (day, idx) = PrayerStripController.pickDay(windowOf("15-11-2026"), "15-11-2026", "16-11-2026", 20 * 60)!!
        assertEquals("15-11-2026", day.dateKey)
        assertEquals(-1, idx)
    }

    @Test fun pickDay_noTodayReturnsNull() {
        assertNull(PrayerStripController.pickDay(windowOf("10-11-2026"), "15-11-2026", "16-11-2026", 600))
    }

    @Test fun prayerAtMillis_usesTheShownDaysDate() {
        val at = Calendar.getInstance().apply { timeInMillis = PrayerStripController.prayerAtMillis("16-11-2026", 292)!! }
        assertEquals(2026, at.get(Calendar.YEAR))
        assertEquals(Calendar.NOVEMBER, at.get(Calendar.MONTH))
        assertEquals(16, at.get(Calendar.DAY_OF_MONTH))
        assertEquals(4, at.get(Calendar.HOUR_OF_DAY))
        assertEquals(52, at.get(Calendar.MINUTE))
        assertEquals(0, at.get(Calendar.SECOND))
        assertNull(PrayerStripController.prayerAtMillis("bad", 292))
    }

    @Test fun fromJson_readsStyleAndLabels() {
        val w = PrayerStripWindow.fromJsonString(json)
        assertEquals("pill", w.style.shape)
        assertEquals(false, w.style.expanded)
        assertEquals(0xFF9A3B3B.toInt(), w.style.highlightDay)
        assertEquals(0xFFE7A3A3.toInt(), w.style.highlightNight)
        assertEquals(0xFF121413.toInt(), w.style.pillTextNight)
        assertNull(w.style.backgroundDay)
        assertEquals(0xFF2E2A20.toInt(), w.style.backgroundNight)
        assertEquals("العصر بعد", w.days[0].cells[2].nextLabel)
        assertEquals("التالية", w.days[0].nextTag)
    }

    @Test fun fromJson_withoutStyleUsesDefaults() {
        val w = PrayerStripWindow.fromJsonString(legacyJson)
        assertEquals(StripStyleNative(), w.style)
        assertEquals("", w.days[0].nextTag)
        assertEquals("", w.days[0].cells[0].nextLabel)
    }

    @Test fun defaultStyleMatchesDartDefaultsOnTheNeutralPalette() {
        val d = StripStyleNative()
        assertEquals(true, d.expanded)
        assertEquals(true, d.countdown)
        assertEquals(0xFF2E5244.toInt(), d.highlightDay)
        assertEquals(0xFF93BAA8.toInt(), d.highlightNight)
        assertEquals(0xFFFFFFFF.toInt(), d.pillTextDay)
        assertEquals(0xFF121413.toInt(), d.pillTextNight)
        assertNull(d.backgroundDay)
        assertNull(d.backgroundNight)
        assertEquals("rounded", d.shape)
    }

    @Test fun fromJson_badColourOrShapeFallsBackToDefaults() {
        val raw = legacyJson.replace(
            "\"accentColor\":\"#FF2E5244\",",
            "",
        ).replace(
            "]}]}",
            "]}],\"style\":{\"highlightDay\":\"#zz\",\"highlightNight\":\"#123\",\"backgroundDay\":\"nope\",\"shape\":\"star\"}}",
        )
        val s = PrayerStripWindow.fromJsonString(raw).style
        assertEquals(StripStyleNative(), s)
    }

    @Test fun channelArgs_roundTripKeepsStyleAndLabels() {
        val args = mapOf(
            "days" to listOf(
                mapOf(
                    "dateKey" to "15-11-2026",
                    "hijriDateLabel" to "h",
                    "weekdayLabel" to "w",
                    "localeCode" to "ar",
                    "isFriday" to false,
                    "nextTag" to "التالية",
                    "nextPrayerIndex" to 0,
                    "cells" to listOf(
                        mapOf("label" to "الفجر", "time" to "٤:٥٢", "minutes" to 292, "nextLabel" to "الفجر بعد"),
                    ),
                ),
            ),
            "style" to mapOf(
                "expanded" to true,
                "countdown" to false,
                "highlightDay" to "#FF2F5F98",
                "highlightNight" to "#FF8EBBE3",
                "pillTextDay" to "#FFFFFFFF",
                "pillTextNight" to "#FF121413",
                "backgroundDay" to "#FFE3ECF5",
                "backgroundNight" to "#FF1B2735",
                "shape" to "outline",
            ),
        )
        val w = PrayerStripWindow.fromJsonString(PrayerStripWindow.channelArgsToJson(args)!!)
        assertEquals("outline", w.style.shape)
        assertEquals(false, w.style.countdown)
        assertEquals(0xFF2F5F98.toInt(), w.style.highlightDay)
        assertEquals(0xFFE3ECF5.toInt(), w.style.backgroundDay)
        assertEquals(0xFF1B2735.toInt(), w.style.backgroundNight)
        assertEquals("الفجر بعد", w.days[0].cells[0].nextLabel)
        assertEquals("التالية", w.days[0].nextTag)
        assertEquals(292, w.days[0].cells[0].minutes)
    }

    @Test fun channelArgs_rejectsPayloadWithoutDays() {
        assertNull(PrayerStripWindow.channelArgsToJson(mapOf("style" to mapOf<String, Any>())))
        assertNull(PrayerStripWindow.channelArgsToJson("nope"))
    }

    @Test fun nextTextUsesPillTextOnFilledShapesAndHighlightOtherwise() {
        val base = StripStyleNative(highlightDay = 0xFF2F5F98.toInt(), highlightNight = 0xFF8EBBE3.toInt())
        assertEquals(0xFFFFFFFF.toInt(), base.copy(shape = "rounded").nextTextColor(night = false))
        assertEquals(0xFF121413.toInt(), base.copy(shape = "pill").nextTextColor(night = true))
        assertEquals(0xFF2F5F98.toInt(), base.copy(shape = "outline").nextTextColor(night = false))
        assertEquals(0xFF8EBBE3.toInt(), base.copy(shape = "none").nextTextColor(night = true))
    }

    @Test fun outlineBecomesAFlatFillWhenTheStrokeCannotBeTinted() {
        val outline = StripStyleNative(shape = "outline")
        assertEquals(false, outline.fillsCell(tintable = true))
        assertEquals(true, outline.fillsCell(tintable = false))
        assertEquals(0xFFFFFFFF.toInt(), outline.nextTextColor(night = false, tintable = false))
        assertEquals(false, StripStyleNative(shape = "none").fillsCell(tintable = false))
        assertEquals(true, StripStyleNative(shape = "pill").fillsCell(tintable = true))
    }

    @Test fun highlightAndBackgroundFollowDayOrNight() {
        val s = StripStyleNative(backgroundDay = 0xFFE3EFEA.toInt(), backgroundNight = 0xFF16302A.toInt())
        assertEquals(0xFF2E5244.toInt(), s.highlight(night = false))
        assertEquals(0xFF93BAA8.toInt(), s.highlight(night = true))
        assertEquals(0xFFE3EFEA.toInt(), s.background(night = false))
        assertEquals(0xFF16302A.toInt(), s.background(night = true))
    }

    @Test fun mutedTextDarkensOnADayFillOnly() {
        val muted = 0x8A000000.toInt()
        val filled = StripStyleNative(backgroundDay = 0xFFE3EFEA.toInt(), backgroundNight = 0xFF16302A.toInt())
        assertEquals(0xA8000000.toInt(), filled.mutedText(night = false, default = muted))
        assertEquals(muted, filled.mutedText(night = true, default = muted))
        assertEquals(muted, StripStyleNative().mutedText(night = false, default = muted))
    }

    @Test fun passedTextKeeps60PercentOfItsAlpha() {
        assertEquals(0x99FFFFFF.toInt(), StripStyleNative.passed(0xFFFFFFFF.toInt()))
        assertEquals(0x85000000.toInt(), StripStyleNative.passed(0xDE000000.toInt()))
    }

    @Test fun stripLayoutsUseOnlyRemoteViewsSafeViews() {
        val allowed = setOf("LinearLayout", "TextView")
        for (name in listOf("prayer_strip_collapsed", "prayer_strip_expanded")) {
            val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder()
                .parse(File("src/main/res/layout/$name.xml"))
            val nodes = doc.getElementsByTagName("*")
            val tags = (0 until nodes.length).map { nodes.item(it).nodeName }.toSet()
            assertTrue("$name uses ${tags - allowed}", allowed.containsAll(tags))
        }
    }
}
