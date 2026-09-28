/*
    SequenceBuilder.ahk
    Responsibility: generate numbered names and IP ranges (pure logic, no GUI).
    Dependencies: none
*/
class SequenceBuilder {
    ; --- Public Methods ---
    BuildNumbers(template, startText, endText, stepText, padText) {
        startText := Trim(startText), endText := Trim(endText)
        stepText := Trim(stepText), padText := Trim(padText)
        if !RegExMatch(startText, "^-?\d{1,9}$")
            return this._Fail("Start must be a whole number")
        if !RegExMatch(endText, "^-?\d{1,9}$")
            return this._Fail("End must be a whole number")
        if (!RegExMatch(stepText, "^\d{1,9}$") || Integer(stepText) < 1)
            return this._Fail("Step must be 1 or more")
        if (!RegExMatch(padText, "^\d{1,2}$") || Integer(padText) > 10)
            return this._Fail("Pad must be 0-10")
        first := Integer(startText)
        last := Integer(endText)
        step := Integer(stepText)
        pad := Integer(padText)
        count := Floor(Abs(last - first) / step) + 1
        if (count > Constants.SEQ_MAX_ITEMS)
            return this._Fail("Too many items (max " Constants.SEQ_MAX_ITEMS ")")
        direction := (last >= first) ? 1 : -1
        items := []
        value := first
        loop count {
            num := (pad > 0) ? Format("{:0" pad "d}", value) : String(value)
            items.Push(InStr(template, "{n}") ? StrReplace(template, "{n}", num) : template num)
            value += direction * step
        }
        return {items: items, error: ""}
    }

    BuildIpRange(startText, endText, stepText, skipEdges) {
        a := this._IpToInt(Trim(startText))
        if (a < 0)
            return this._Fail("Start IP is not valid")
        b := this._IpToInt(Trim(endText))
        if (b < 0)
            return this._Fail("End IP is not valid")
        if (b < a)
            return this._Fail("End IP must be after start IP")
        stepText := Trim(stepText)
        if (!RegExMatch(stepText, "^\d{1,9}$") || Integer(stepText) < 1)
            return this._Fail("Step must be 1 or more")
        step := Integer(stepText)
        total := Floor((b - a) / step) + 1
        if (total > Constants.SEQ_MAX_ITEMS)                ; before looping: a /8 is 16M addresses
            return this._Fail("Too many items (max " Constants.SEQ_MAX_ITEMS ")")
        items := []
        loop total {
            n := a + (A_Index - 1) * step
            lastOctet := n & 255
            if (skipEdges && (lastOctet = 0 || lastOctet = 255))
                continue
            items.Push(this._IntToIp(n))
        }
        if !items.Length
            return this._Fail("No addresses in range")
        return {items: items, error: ""}
    }

    ; --- Private Methods ---
    _IpToInt(ip) {                                      ; -1 = invalid
        parts := StrSplit(ip, ".")
        if (parts.Length != 4)
            return -1
        value := 0
        for part in parts {
            if !RegExMatch(part, "^\d{1,3}$")           ; rejects hex, signs, spaces, empty
                return -1
            octet := Integer(part)
            if (octet > 255)
                return -1
            value := (value << 8) | octet
        }
        return value
    }

    _IntToIp(n) {
        return ((n >> 24) & 255) "." ((n >> 16) & 255) "." ((n >> 8) & 255) "." (n & 255)
    }

    _Fail(message) {
        return {items: [], error: message}
    }

    _LogError(caller, message) {
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " ERROR [" caller "]: " message "`n", A_ScriptDir "\" Constants.ERROR_LOG)
    }
}
