package com.eleknow.homafridge.modules;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

/** دادهٔ استانداردشدهٔ پیام ورودی؛ UI به قالب JSON هر ماژول وابسته نمی‌ماند. */
public final class ModuleMessage {
    private final String type;
    private final Map<String, String> values;

    public ModuleMessage(String type, Map<String, String> values) {
        this.type = type == null ? "" : type;
        this.values = Collections.unmodifiableMap(new LinkedHashMap<>(values));
    }

    public String type() {
        return type;
    }

    public boolean isCommandAccepted() {
        return "Success".equals(type);
    }

    public Map<String, String> values() {
        return values;
    }
}
