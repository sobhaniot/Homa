package com.eleknow.homafridge.modules;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** تعریف مستقل ماژول یخچال؛ ماژول‌های بعدی از همین قرارداد پیروی می‌کنند. */
public final class RefrigeratorModule implements MqttModule {
    public static final String ID = "refrigerator";
    public static final String DEFAULT_REQUEST_TOPIC =
            "/eleknow.com/nahbos5672730/home/refrigerator";
    public static final String DEFAULT_RESPONSE_TOPIC =
            "/eleknow.com/nahbos5672730/home/refrigeratorResult";

    @Override
    public String id() {
        return ID;
    }

    @Override
    public String title() {
        return "نمایشگر یخچال";
    }

    @Override
    public String defaultRequestTopic() {
        return DEFAULT_REQUEST_TOPIC;
    }

    @Override
    public String defaultResponseTopic() {
        return DEFAULT_RESPONSE_TOPIC;
    }

    @Override
    public String infoRequestPayload() {
        return "{\"type\":\"Info\"}";
    }

    @Override
    public List<ModuleField> displayFields() {
        List<ModuleField> fields = new ArrayList<>();
        fields.add(new ModuleField("targetTemp", "دمای تنظیم‌شده", false));
        fields.add(new ModuleField("hysteresis", "هیسترزیس", false));
        fields.add(new ModuleField("minTemp", "حداقل دما", false));
        fields.add(new ModuleField("maxTemp", "حداکثر دما", false));
        fields.add(new ModuleField("onTime", "زمان روشن", false));
        fields.add(new ModuleField("offTime", "زمان خاموش", false));
        fields.add(new ModuleField("ip", "آدرس IP دستگاه", true));
        return fields;
    }

    @Override
    public ModuleMessage parseMessage(String payload) throws Exception {
        JSONObject json = new JSONObject(payload);
        Map<String, String> values = new LinkedHashMap<>();
        values.put("insideTemp", withUnit(json.optString("TempIn", "—"), " °C"));
        values.put("outsideTemp", withUnit(json.optString("TempOut", "—"), " °C"));
        values.put("targetTemp", withUnit(json.optString("Temp", "—"), " °C"));
        values.put("hysteresis", withUnit(json.optString("Hyster", "—"), " °C"));
        values.put("settingTemp", json.optString("Temp", ""));
        values.put("settingHysteresis", json.optString("Hyster", ""));
        values.put("minTemp", withUnit(json.optString("MinTemp", "—"), " °C"));
        values.put("maxTemp", withUnit(json.optString("MaxTemp", "—"), " °C"));
        values.put("onTime", json.optString("OnTime", "—"));
        values.put("offTime", json.optString("OffTime", "—"));
        values.put("ip", json.optString("IP", "—"));
        return new ModuleMessage(json.optString("type", ""), values);
    }

    @Override
    public String settingsPayload(Map<String, String> settings) throws Exception {
        JSONObject command = new JSONObject();
        command.put("type", "Param");
        command.put("Temp", Float.parseFloat(settings.get("Temp")));
        command.put("Hyster", Float.parseFloat(settings.get("Hyster")));
        return command.toString();
    }

    private String withUnit(String value, String unit) {
        return "—".equals(value) ? value : value + unit;
    }
}
