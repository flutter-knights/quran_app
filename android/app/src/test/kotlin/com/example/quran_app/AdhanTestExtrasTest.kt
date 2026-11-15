package com.example.quran_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class AdhanTestExtrasTest {

    @Test fun testAlarmExtrasAreV2AndMarkedTest() {
        val extras = AdhanScheduler.testExtras(localeCode = "ar", sound = "tone", ringInSilent = false, triggerAt = 1_000L)
        assertEquals("tone", extras["sound"])
        assertEquals(false, extras["ringInSilent"])
        assertEquals(true, extras["test"])
        assertEquals("dhuhr", extras["prayer"])
        assertFalse(extras.containsKey("key"))
    }
}
