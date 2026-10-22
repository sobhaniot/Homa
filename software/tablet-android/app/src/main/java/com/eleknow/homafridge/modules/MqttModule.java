package com.eleknow.homafridge.modules;

import java.util.List;
import java.util.Map;

/** قرارداد مشترک هر ماژول برای تاپیک‌ها، نمایش داده و ساخت پیام MQTT. */
public interface MqttModule {
    String id();

    String title();

    String defaultRequestTopic();

    String defaultResponseTopic();

    /** بازهٔ پیش‌فرض درخواست اطلاعات از ماژول، بر حسب ثانیه. */
    default int defaultInfoIntervalSeconds() {
        return 10;
    }

    String infoRequestPayload();

    List<ModuleField> displayFields();

    ModuleMessage parseMessage(String payload) throws Exception;

    String settingsPayload(Map<String, String> settings) throws Exception;
}
