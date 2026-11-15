package com.example.quran_app

import java.io.File
import java.util.Calendar
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
          "localeCode":"ar","isFriday":false,"nextPrayerIndex":2,
          "cells":[
            {"label":"الفجر","time":"٤:٥٢","minutes":292,"nextLabel":"الفجر بعد"},
            {"label":"الظهر","time":"١١:٤١","minutes":701,"nextLabel":"الظهر بعد"},
            {"label":"العصر","time":"٢:٣٩","timeFull":"٢:٣٩ م","minutes":879,"nextLabel":"العصر بعد"},
            {"label":"المغرب","time":"٤:٥٨","minutes":1018,"nextLabel":"المغرب بعد"},
            {"label":"العشاء","time":"٦:١٦","minutes":1096,"nextLabel":"العشاء بعد"}]}],
         "style":{"expanded":false,"countdown":true,"highlightDay":"#FF9A3B3B","highlightNight":"#FFE7A3A3",
          "highlightTextDay":"#FF8A3030","pillTextDay":"#FFFFFFFF","pillTextNight":"#FF121413",
          "backgroundNight":"#FF2E2A20","shape":"pill"},
         "nextTag":"التالية"}
    """.trimIndent()

    private val legacyJson = """
        {"days":[{"dateKey":"15-11-2026","hijriDateLabel":"x","weekdayLabel":"y","localeCode":"ar",
          "isFriday":false,"accentColor":"#FF2E5244","nextTag":"Next",
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
        assertEquals(StripShape.PILL, w.style.shape)
        assertEquals(false, w.style.expanded)
        assertEquals(0xFF9A3B3B.toInt(), w.style.highlightDay)
        assertEquals(0xFFE7A3A3.toInt(), w.style.highlightNight)
        assertEquals(0xFF8A3030.toInt(), w.style.highlightTextDay)
        assertEquals(0xFF121413.toInt(), w.style.pillTextNight)
        assertNull(w.style.backgroundDay)
        assertEquals(0xFF2E2A20.toInt(), w.style.backgroundNight)
        assertEquals("العصر بعد", w.days[0].cells[2].nextLabel)
        assertEquals("٢:٣٩ م", w.days[0].cells[2].timeFull)
        assertEquals("١١:٤١", w.days[0].cells[1].timeFull)
        assertEquals("التالية", w.nextTag)
    }

    @Test fun fromJson_withoutStyleUsesDefaults() {
        val w = PrayerStripWindow.fromJsonString(legacyJson)
        assertEquals(StripStyleNative(), w.style)
        assertEquals("Next", w.nextTag)
        assertEquals("", w.days[0].cells[0].nextLabel)
        assertEquals("٤:٥٢", w.days[0].cells[0].timeFull)
    }

    @Test fun fromJson_withoutAnyNextTagReadsEmpty() {
        val raw = legacyJson.replace("\"nextTag\":\"Next\",", "")
        assertEquals("", PrayerStripWindow.fromJsonString(raw).nextTag)
    }

    @Test fun parseOrNull_returnsNullForMissingOrBrokenJson() {
        assertNull(PrayerStripWindow.parseOrNull(null))
        assertNull(PrayerStripWindow.parseOrNull("{\"days\":[{\"dateKey\":1}]}"))
        assertNull(PrayerStripWindow.parseOrNull("not json"))
        assertEquals(1, PrayerStripWindow.parseOrNull(legacyJson)!!.days.size)
    }

    @Test fun defaultStyleMatchesDartDefaultsOnTheNeutralPalette() {
        val d = StripStyleNative()
        assertEquals(true, d.expanded)
        assertEquals(true, d.countdown)
        assertEquals(0xFF2E5244.toInt(), d.highlightDay)
        assertEquals(0xFF93BAA8.toInt(), d.highlightNight)
        assertEquals(0xFF2E5244.toInt(), d.highlightTextDay)
        assertEquals(0xFFFFFFFF.toInt(), d.pillTextDay)
        assertEquals(0xFF121413.toInt(), d.pillTextNight)
        assertNull(d.backgroundDay)
        assertNull(d.backgroundNight)
        assertEquals(StripShape.ROUNDED, d.shape)
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
                    "nextPrayerIndex" to 0,
                    "cells" to listOf(
                        mapOf(
                            "label" to "الفجر",
                            "time" to "٤:٥٢",
                            "timeFull" to "٤:٥٢ ص",
                            "minutes" to 292,
                            "nextLabel" to "الفجر بعد",
                        ),
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
            "nextTag" to "التالية",
        )
        val w = PrayerStripWindow.fromJsonString(PrayerStripWindow.channelArgsToJson(args)!!)
        assertEquals(StripShape.OUTLINE, w.style.shape)
        assertEquals(false, w.style.countdown)
        assertEquals(0xFF2F5F98.toInt(), w.style.highlightDay)
        assertEquals(0xFFE3ECF5.toInt(), w.style.backgroundDay)
        assertEquals(0xFF1B2735.toInt(), w.style.backgroundNight)
        assertEquals("الفجر بعد", w.days[0].cells[0].nextLabel)
        assertEquals("٤:٥٢ ص", w.days[0].cells[0].timeFull)
        assertEquals("التالية", w.nextTag)
        assertEquals(292, w.days[0].cells[0].minutes)
    }

    @Test fun channelArgs_rejectsPayloadWithoutDays() {
        assertNull(PrayerStripWindow.channelArgsToJson(mapOf("style" to mapOf<String, Any>())))
        assertNull(PrayerStripWindow.channelArgsToJson("nope"))
    }

    @Test fun nextTextUsesPillTextOnFilledShapesAndTheTextHighlightOtherwise() {
        val base = StripStyleNative(
            highlightDay = 0xFF4A7C6A.toInt(),
            highlightNight = 0xFF8FC4AE.toInt(),
            highlightTextDay = 0xFF406C5C.toInt(),
        )
        assertEquals(0xFFFFFFFF.toInt(), base.copy(shape = StripShape.ROUNDED).nextTextColor(night = false))
        assertEquals(0xFF121413.toInt(), base.copy(shape = StripShape.PILL).nextTextColor(night = true))
        assertEquals(0xFF406C5C.toInt(), base.copy(shape = StripShape.OUTLINE).nextTextColor(night = false))
        assertEquals(0xFF406C5C.toInt(), base.copy(shape = StripShape.NONE).nextTextColor(night = false))
        assertEquals(0xFF8FC4AE.toInt(), base.copy(shape = StripShape.NONE).nextTextColor(night = true))
    }

    @Test fun shapeParsesWireNamesWithARoundedDefault() {
        assertEquals(StripShape.NONE, StripShape.parse("none"))
        assertEquals(StripShape.OUTLINE, StripShape.parse("outline"))
        assertEquals(StripShape.ROUNDED, StripShape.parse("star"))
        assertEquals(StripShape.ROUNDED, StripShape.parse(null))
    }

    @Test fun cellRoleSplitsPassedNextAndUpcoming() {
        assertEquals(StripCellRole.PASSED, StripCellRole.of(0, 2))
        assertEquals(StripCellRole.NEXT, StripCellRole.of(2, 2))
        assertEquals(StripCellRole.UPCOMING, StripCellRole.of(3, 2))
        assertEquals(StripCellRole.PASSED, StripCellRole.of(4, -1))
    }

    @Test fun outlineBecomesAFlatFillWhenTheStrokeCannotBeTinted() {
        val outline = StripStyleNative(shape = StripShape.OUTLINE)
        assertEquals(false, outline.fillsCell(tintable = true))
        assertEquals(true, outline.fillsCell(tintable = false))
        assertEquals(0xFFFFFFFF.toInt(), outline.nextTextColor(night = false, tintable = false))
        assertEquals(false, StripStyleNative(shape = StripShape.NONE).fillsCell(tintable = false))
        assertEquals(true, StripStyleNative(shape = StripShape.PILL).fillsCell(tintable = true))
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

    private fun colors(dir: String): Map<String, Long> {
        val nodes = xml("src/main/res/$dir/colors.xml").getElementsByTagName("color")
        return (0 until nodes.length).associate {
            val n = nodes.item(it)
            n.attributes.getNamedItem("name").nodeValue to
                java.lang.Long.parseLong(n.textContent.trim().removePrefix("#"), 16)
        }
    }

    @Test fun passedTextIsAboutHalfOfPrimaryInDayAndNight() {
        for (dir in listOf("values", "values-night")) {
            val c = colors(dir)
            val primary = c.getValue("strip_text_primary")
            val passed = c.getValue("strip_text_passed")
            assertEquals(dir, primary and 0xFFFFFF, passed and 0xFFFFFF)
            val ratio = (passed shr 24).toDouble() / (primary shr 24)
            assertTrue("$dir ratio $ratio", ratio in 0.45..0.55)
            assertFalse(dir, c.containsKey("strip_text_dim"))
            assertFalse(dir, c.containsKey("strip_pill_text"))
        }
    }

    @Test fun cellTextFollowsTheEnabledSelector() {
        val selector = xml("src/main/res/color/strip_cell_text.xml").getElementsByTagName("item")
        val items = (0 until selector.length).map { selector.item(it).attributes }
        assertEquals("false", items[0].getNamedItem("android:state_enabled").nodeValue)
        assertEquals("@color/strip_text_passed", items[0].getNamedItem("android:color").nodeValue)
        assertEquals("@color/strip_text_primary", items[1].getNamedItem("android:color").nodeValue)
        for (name in listOf("prayer_strip_collapsed", "prayer_strip_expanded")) {
            val views = xml("src/main/res/layout/$name.xml").getElementsByTagName("TextView")
            for (i in 0 until views.length) {
                val a = views.item(i).attributes
                val id = a.getNamedItem("android:id").nodeValue
                if (id.endsWith("_label") || id.endsWith("_time")) {
                    assertEquals("$name $id", "@color/strip_cell_text", a.getNamedItem("android:textColor").nodeValue)
                }
            }
        }
    }

    private val lineEm = (1303 + 571) / 1000.0

    private fun xml(path: String) =
        DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(File(path))

    private fun dim(e: org.w3c.dom.Element, attr: String, scale: Double): Double {
        val v = e.getAttribute("android:$attr")
        return when {
            v.endsWith("sp") -> v.removeSuffix("sp").toDouble() * scale
            v.endsWith("dp") -> v.removeSuffix("dp").toDouble()
            else -> 0.0
        }
    }

    private fun children(e: org.w3c.dom.Element) =
        (0 until e.childNodes.length).map { e.childNodes.item(it) }
            .filterIsInstance<org.w3c.dom.Element>()
            .filter { it.getAttribute("android:visibility") != "gone" }

    private fun height(e: org.w3c.dom.Element, scale: Double): Double {
        val content = when (e.tagName) {
            "TextView" -> dim(e, "textSize", scale) * lineEm
            else -> children(e).map { height(it, scale) }.let { kids ->
                if (e.getAttribute("android:orientation") == "vertical") kids.sum() else kids.maxOrNull() ?: 0.0
            }
        }
        val box = maxOf(content + dim(e, "paddingTop", scale) + dim(e, "paddingBottom", scale), dim(e, "minHeight", scale))
        return box + dim(e, "layout_marginTop", scale) + dim(e, "layout_marginBottom", scale)
    }

    private fun layoutHeight(name: String, scale: Double) =
        height(xml("src/main/res/layout/$name.xml").documentElement, scale)

    @Test fun compactStripFitsTheCollapsedBudgetAt1x() {
        val h = layoutHeight("prayer_strip_collapsed", 1.0)
        assertTrue("collapsed is ${"%.1f".format(h)}dp", h <= 48.0)
    }

    @Test fun expandedStripFitsTheBudgetAt130PercentFontScale() {
        val h = layoutHeight("prayer_strip_expanded", 1.3)
        assertTrue("expanded is ${"%.1f".format(h)}dp", h <= 252.0)
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
