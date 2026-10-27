package com.example.myproject.widgets

/** Local, exact decimal editing. No financial writes or tap debounce. */
object QuickSaveInput {
    fun edit(input: String, control: String, decimals: Int): String {
        if (control == "clear") return ""
        if (control == "back") return input.dropLast(1)
        val digit = control.removePrefix("digit:")
        if (digit == ".") return if (decimals > 0 && '.' !in input) input.ifEmpty { "0" } + "." else input
        if (digit.length != 1 || digit[0] !in '0'..'9') return input
        if (input.length >= 18 || ('.' in input && input.substringAfter('.').length >= decimals)) return input
        return if (input == "0") digit else input + digit
    }
    fun review(input: String, decimals: Int, shared: Boolean = false): String? {
        val value = input.removeSuffix(".")
        if (!value.matches(Regex("\\d+(\\.\\d{1,${decimals.coerceAtLeast(1)}})?"))) return null
        if (decimals == 0 && '.' in value) return null
        val amount = value.toBigDecimalOrNull() ?: return null
        val maximum = if (shared) "1000000000" else "1000000000000"
        return value.takeIf { amount.signum() > 0 && amount <= maximum.toBigDecimal() }
    }
}
