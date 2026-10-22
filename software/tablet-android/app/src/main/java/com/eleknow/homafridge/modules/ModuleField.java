package com.eleknow.homafridge.modules;

/** مشخصات یک خانهٔ اطلاعاتی که کارت عمومی ماژول نمایش می‌دهد. */
public final class ModuleField {
    public final String key;
    public final String label;
    public final boolean fullWidth;

    public ModuleField(String key, String label, boolean fullWidth) {
        this.key = key;
        this.label = label;
        this.fullWidth = fullWidth;
    }
}
