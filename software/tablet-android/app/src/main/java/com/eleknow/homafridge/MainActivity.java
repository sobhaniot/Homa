package com.eleknow.homafridge;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.SharedPreferences;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.util.Log;
import android.view.Gravity;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import org.json.JSONException;
import org.json.JSONObject;
import com.eleknow.homafridge.modules.ModuleMessage;
import com.eleknow.homafridge.modules.MqttModule;
import com.eleknow.homafridge.modules.RefrigeratorModule;
import org.json.JSONArray;
import java.net.HttpURLConnection;
import java.net.URL;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import com.eleknow.homafridge.ui.ModuleTileView;

import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

public class MainActivity extends Activity {
    private static final String DEFAULT_HOST = "192.168.1.55";
    private static final int DEFAULT_PORT = 8080;
    // این دو تاپیک فقط برای همگام‌سازی بایگانی تبلت و ویندوز هستند؛
    // تاپیک‌ها و پیام‌های فریم‌ور یخچال تغییر نمی‌کنند.
    private static final String HISTORY_REQUEST_TOPIC =
            "/eleknow.com/nahbos5672730/home/history/request";
    private static final String HISTORY_RESPONSE_TOPIC =
            "/eleknow.com/nahbos5672730/home/history/response";
    private static final int HISTORY_PAGE_SIZE = 100;
    private final MqttModule module = new RefrigeratorModule();

    private final Handler handler = new Handler();
    private String brokerHost;
    private int brokerPort;
    private String brokerClientId;
    private String requestTopic;
    private String responseTopic;
    // بازهٔ درخواست اطلاعات برای هر ماژول جداگانه ذخیره می‌شود.
    private int infoIntervalSeconds;
    private TextView brokerSummaryView;
    private TextView statusView;
    private TextView insideTempView;
    private TextView outsideTempView;
    private ModuleTileView moduleTile;
    private TextView rawMessageView;
    private TextView localCountView;
    private Button connectButton;
    private final ExecutorService serverExecutor = Executors.newSingleThreadExecutor();
    private boolean serverEnabled;
    private int serverGeneration;
    private JSONObject remoteFridge;
    
    private boolean connected;
    private float fridgeTemp = 9.0f;
    private float fridgeHysteresis = 1.0f;
    private boolean hasSavedFridgeSettings;
    private boolean fridgeSettingsPending;
    private long localRecordCount;
    private long lastCountLabelUpdateMs;

    private final Runnable requestLoop = new Runnable() {
        @Override
        public void run() {
            if (serverEnabled) refreshFromServer();
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // نام Activity قدیمی برای میان‌برهای نصب‌شده حفظ می‌شود؛ نمایش جدید عمومی است.
        if (useServerDefinitions()) {
            startActivity(new android.content.Intent(this, ServerDashboardActivity.class));
            finish();
            return;
        }
        // هنگام نمایش داشبورد، صفحه روشن می‌ماند تا تبلت نقش مانیتور را داشته باشد.
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        if (Build.VERSION.SDK_INT >= 21) {
            getWindow().setStatusBarColor(Color.rgb(13, 28, 42));
            getWindow().setNavigationBarColor(Color.rgb(13, 28, 42));
        }
        
        
        loadSettings();
        createScreen();
        connect();
    }

    private boolean useServerDefinitions() { return true; }

    private void loadSettings() {
        SharedPreferences preferences = getSharedPreferences("homa_mqtt", MODE_PRIVATE);
        brokerHost = preferences.getString("server_host", DEFAULT_HOST);
        brokerPort = preferences.getInt("server_port", DEFAULT_PORT);
        brokerClientId = preferences.getString("client_id", "homa-fridge-tablet");
        requestTopic = preferences.getString(module.id() + ".request_topic",
                preferences.getString("request_topic", module.defaultRequestTopic()));
        responseTopic = preferences.getString(module.id() + ".response_topic",
                preferences.getString("response_topic", module.defaultResponseTopic()));
        infoIntervalSeconds = preferences.getInt(module.id() + ".info_interval_seconds",
                module.defaultInfoIntervalSeconds());
        fridgeTemp = preferences.getFloat(module.id() + ".target_temperature",
                preferences.getFloat("fridge_temp", 9.0f));
        fridgeHysteresis = preferences.getFloat(module.id() + ".hysteresis",
                preferences.getFloat("fridge_hysteresis", 1.0f));
        hasSavedFridgeSettings = preferences.getBoolean(module.id() + ".has_saved_settings",
                preferences.getBoolean("has_saved_fridge_settings", false));
        fridgeSettingsPending = preferences.getBoolean(module.id() + ".settings_pending",
                preferences.getBoolean("fridge_settings_pending", false));
    }

    private void createScreen() {
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setBackground(new GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                new int[]{Color.rgb(15, 30, 46), Color.rgb(19, 46, 57), Color.rgb(15, 22, 33)}));

        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(18), dp(22), dp(18), dp(28));
        page.setLayoutDirection(LinearLayout.LAYOUT_DIRECTION_RTL);
        scroll.addView(page);

        TextView eyebrow = text("خانهٔ هوشمند", 16, Color.rgb(166, 190, 205), false);
        page.addView(eyebrow);
        LinearLayout connectionCard = card();
        addSectionTitle(connectionCard, "وضعیت اتصال رزبری");
        brokerSummaryView = text(brokerHost + ":" + brokerPort, 17,
                Color.rgb(191, 207, 219), false);
        brokerSummaryView.setTextDirection(TextView.TEXT_DIRECTION_LTR);
        brokerSummaryView.setGravity(Gravity.LEFT);
        connectionCard.addView(brokerSummaryView, spaced());
        statusView = text("در حال آماده‌سازی اتصال…", 17,
                Color.rgb(255, 211, 137), false);
        connectionCard.addView(statusView, spaced());
        connectButton = new Button(this);
        connectButton.setText("قطع اتصال");
        connectButton.setTextSize(18);
        connectButton.setTextColor(Color.rgb(8, 30, 35));
        connectButton.setBackground(round(Color.rgb(26, 195, 174), dp(13), 0x00333333));
        connectButton.setOnClickListener(v -> {
            if (connected) disconnect(true);
            else connect();
        });
        LinearLayout.LayoutParams buttonParams = spaced();
        buttonParams.height = dp(52);
        connectionCard.addView(connectButton, buttonParams);

        moduleTile = new ModuleTileView(this, module, this::showFridgeSettings);
        LinearLayout temperatures = new LinearLayout(this);
        temperatures.setOrientation(LinearLayout.HORIZONTAL);
        temperatures.setLayoutDirection(LinearLayout.LAYOUT_DIRECTION_LTR);
        insideTempView = metric(temperatures, "دمای داخل", "—", Color.rgb(96, 224, 205));
        outsideTempView = metric(temperatures, "دمای بیرون", "—", Color.rgb(255, 201, 123));
        moduleTile.addCustomContent(temperatures);

        LinearLayout messageCard = card();
        addSectionTitle(messageCard, "آخرین پیام دریافت‌شده");
        rawMessageView = text("هنوز پیامی دریافت نشده است", 15, Color.rgb(211, 224, 233), false);
        rawMessageView.setTextIsSelectable(true);
        rawMessageView.setTextDirection(TextView.TEXT_DIRECTION_LTR);
        rawMessageView.setGravity(Gravity.LEFT);
        rawMessageView.setTypeface(Typeface.MONOSPACE);
        messageCard.addView(rawMessageView, spaced());
        localCountView = text("ذخیرهٔ محلی: ۰ رکورد", 15,
                Color.rgb(137, 221, 206), false);
        messageCard.addView(localCountView, spaced());

        // کارت‌ها در حالت افقی به دو ستون موزاییکی و در حالت عمودی تک‌ستونه چیده می‌شوند.
        boolean landscape = getResources().getConfiguration().orientation
                == Configuration.ORIENTATION_LANDSCAPE;
        if (landscape) {
            LinearLayout mosaic = new LinearLayout(this);
            mosaic.setOrientation(LinearLayout.HORIZONTAL);
            LinearLayout firstColumn = new LinearLayout(this);
            firstColumn.setOrientation(LinearLayout.VERTICAL);
            LinearLayout secondColumn = new LinearLayout(this);
            secondColumn.setOrientation(LinearLayout.VERTICAL);
            mosaic.addView(firstColumn, new LinearLayout.LayoutParams(0, -2, 1f));
            mosaic.addView(secondColumn, new LinearLayout.LayoutParams(0, -2, 1f));
            addMosaicTile(firstColumn, moduleTile);
            addMosaicTile(firstColumn, messageCard);
            addMosaicTile(secondColumn, connectionCard);
            page.addView(mosaic, pageParams());
        } else {
            page.addView(moduleTile, pageParams());
            page.addView(connectionCard, pageParams());
            page.addView(messageCard, pageParams());
        }

        LinearLayout settingsCard = card();
        addSectionTitle(settingsCard, "تنظیمات رزبری");
        TextView settingsHint = text("آدرس رزبری و پورت API (پیش‌فرض 8080) را تنظیم کنید.",
                14, Color.rgb(191, 207, 219), false);
        settingsCard.addView(settingsHint, spaced());
        Button brokerSettingsButton = new Button(this);
        brokerSettingsButton.setText("تنظیم رزبری و پورت");
        brokerSettingsButton.setTextSize(18);
        brokerSettingsButton.setTextColor(Color.rgb(8, 30, 35));
        brokerSettingsButton.setBackground(round(Color.rgb(26, 195, 174), dp(13), 0x00333333));
        brokerSettingsButton.setOnClickListener(v -> showBrokerSettings());
        LinearLayout.LayoutParams settingsButtonParams = spaced();
        settingsButtonParams.height = dp(52);
        settingsCard.addView(brokerSettingsButton, settingsButtonParams);
        page.addView(settingsCard, pageParams());

        setContentView(scroll);
    }

    private void addMosaicTile(LinearLayout column, LinearLayout tile) {
        LinearLayout.LayoutParams tileParams = params(-1, -2);
        tileParams.setMargins(dp(6), dp(6), dp(6), dp(6));
        column.addView(tile, tileParams);
    }

    private void showFridgeSettings() {
        LinearLayout form = dialogForm();
        EditText requestInput = settingInput("تاپیک درخواست / ارسال", requestTopic,
                android.text.InputType.TYPE_CLASS_TEXT);
        EditText responseInput = settingInput("تاپیک پاسخ / دریافت", responseTopic,
                android.text.InputType.TYPE_CLASS_TEXT);
        EditText intervalInput = settingInput("بازهٔ دریافت اطلاعات (ثانیه)",
                String.valueOf(infoIntervalSeconds), android.text.InputType.TYPE_CLASS_NUMBER);
        EditText tempInput = settingInput("دمای هدف (°C)", formatNumber(fridgeTemp),
                android.text.InputType.TYPE_CLASS_NUMBER
                        | android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL
                        | android.text.InputType.TYPE_NUMBER_FLAG_SIGNED);
        EditText hysteresisInput = settingInput("هیسترزیس (°C)", formatNumber(fridgeHysteresis),
                android.text.InputType.TYPE_CLASS_NUMBER
                        | android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL);
        addLabeledInput(form, "تاپیک درخواست / ارسال", requestInput);
        addLabeledInput(form, "تاپیک پاسخ / دریافت", responseInput);
        addLabeledInput(form, "بازهٔ دریافت اطلاعات (ثانیه)", intervalInput);
        addLabeledInput(form, "دمای هدف (°C)", tempInput);
        addLabeledInput(form, "هیسترزیس (°C)", hysteresisInput);

        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle("تنظیمات یخچال")
                .setView(scrollableSettings(form))
                .setNegativeButton("انصراف", null)
                .setPositiveButton("ذخیره و ارسال", null)
                .create();
        dialog.setOnShowListener(ignored -> dialog.getButton(AlertDialog.BUTTON_POSITIVE)
                .setOnClickListener(v -> {
                    String newRequest = requestInput.getText().toString().trim();
                    String newResponse = responseInput.getText().toString().trim();
                    int newInfoInterval;
                    float newTemp;
                    float newHysteresis;
                    try {
                        newInfoInterval = Integer.parseInt(
                                intervalInput.getText().toString().trim());
                    } catch (NumberFormatException error) {
                        intervalInput.setError("بازه باید یک عدد صحیح باشد");
                        return;
                    }
                    try {
                        newTemp = Float.parseFloat(tempInput.getText().toString().trim());
                        newHysteresis = Float.parseFloat(
                                hysteresisInput.getText().toString().trim());
                    } catch (NumberFormatException error) {
                        tempInput.setError("یک عدد معتبر وارد کن");
                        hysteresisInput.setError("یک عدد معتبر وارد کن");
                        return;
                    }
                    if (newRequest.isEmpty() || newResponse.isEmpty()) {
                        requestInput.setError("تاپیک را وارد کن");
                        responseInput.setError("تاپیک را وارد کن");
                        return;
                    }
                    if (newInfoInterval < 5 || newInfoInterval > 86400) {
                        intervalInput.setError("بازه باید بین ۱ تا ۸۶۴۰۰ ثانیه باشد");
                        return;
                    }
                    if (Float.isNaN(newTemp) || Float.isInfinite(newTemp)
                            || newTemp < -50 || newTemp > 80 || newHysteresis > 30
                            || Float.isNaN(newHysteresis) || Float.isInfinite(newHysteresis)
                            || newHysteresis < 0.1f) {
                        hysteresisInput.setError("هیسترزیس باید صفر یا بیشتر باشد");
                        return;
                    }
                    boolean fridgeParametersChanged = newTemp != fridgeTemp
                            || newHysteresis != fridgeHysteresis;
                    requestTopic = newRequest;
                    responseTopic = newResponse;
                    infoIntervalSeconds = newInfoInterval;
                    fridgeTemp = newTemp;
                    fridgeHysteresis = newHysteresis;
                    hasSavedFridgeSettings = true;
                    fridgeSettingsPending = fridgeSettingsPending || fridgeParametersChanged;
                    saveSettings();
                    dialog.dismiss();
                    saveRemoteFridge(fridgeParametersChanged);
                }));
        showSettingsDialog(dialog);
    }

    private void showBrokerSettings() {
        LinearLayout form = dialogForm();
        EditText host = settingInput("آدرس رزبری", brokerHost,
                android.text.InputType.TYPE_CLASS_TEXT);
        EditText port = settingInput("پورت", String.valueOf(brokerPort),
                android.text.InputType.TYPE_CLASS_NUMBER);
        EditText clientId = settingInput("نام نمایشگر", brokerClientId,
                android.text.InputType.TYPE_CLASS_TEXT);
        addLabeledInput(form, "آدرس رزبری", host);
        addLabeledInput(form, "پورت", port);
        addLabeledInput(form, "نام نمایشگر", clientId);

        AlertDialog dialog = new AlertDialog.Builder(this)
                .setTitle("تنظیمات سرور رزبری")
                .setView(scrollableSettings(form))
                .setNegativeButton("انصراف", null)
                .setPositiveButton("ذخیره و اتصال", null)
                .create();
        dialog.setOnShowListener(ignored -> dialog.getButton(AlertDialog.BUTTON_POSITIVE)
                .setOnClickListener(v -> {
                    String newHost = host.getText().toString().trim();
                    String newClientId = clientId.getText().toString().trim();
                    int newPort;
                    try {
                        newPort = Integer.parseInt(port.getText().toString().trim());
                    } catch (NumberFormatException error) {
                        port.setError("پورت باید عدد باشد");
                        return;
                    }
                    if (newHost.isEmpty() || newClientId.isEmpty()
                            || newPort < 1 || newPort > 65535) {
                        host.setError("آدرس و شناسه را وارد کن");
                        port.setError("پورت معتبر نیست");
                        return;
                    }
                    brokerHost = newHost;
                    brokerPort = newPort;
                    brokerClientId = newClientId;
                    saveSettings();
                    brokerSummaryView.setText(brokerHost + ":" + brokerPort
                            + "  ·  " + brokerClientId);
                    dialog.dismiss();
                    disconnect(false);
                    connect();
                }));
        showSettingsDialog(dialog);
    }

    private LinearLayout dialogForm() {
        LinearLayout form = new LinearLayout(this);
        form.setOrientation(LinearLayout.VERTICAL);
        form.setPadding(dp(20), dp(5), dp(20), dp(5));
        form.setLayoutDirection(LinearLayout.LAYOUT_DIRECTION_RTL);
        return form;
    }

    private void addLabeledInput(LinearLayout form, String labelText, EditText input) {
        // برچسب جداگانه همیشه دیده می‌شود و با واردکردن مقدار ناپدید نمی‌شود.
        LinearLayout field = new LinearLayout(this);
        field.setOrientation(LinearLayout.VERTICAL);
        field.setLayoutDirection(LinearLayout.LAYOUT_DIRECTION_RTL);

        TextView label = text(labelText, 18, Color.rgb(200, 216, 224), false);
        field.addView(label, params(-1, -2));
        field.addView(input, params(-1, -2));
        form.addView(field, spaced());
    }

    private ScrollView scrollableSettings(LinearLayout form) {
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setVerticalScrollBarEnabled(true);
        scroll.addView(form);
        return scroll;
    }

    private void showSettingsDialog(AlertDialog dialog) {
        dialog.show();
        // با بازشدن کیبورد، دیالوگ کوچک و فرم قابل‌اسکرول می‌شوند تا فیلد فعال پوشیده نشود.
        if (dialog.getWindow() != null) {
            dialog.getWindow().setSoftInputMode(
                    WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);
        }
    }

    private EditText settingInput(String hint, String value, int inputType) {
        EditText edit = new EditText(this);
        edit.setSingleLine(true);
        edit.setText(value);
        edit.setHint(hint);
        edit.setTextSize(18);
        edit.setTextDirection(EditText.TEXT_DIRECTION_LTR);
        edit.setGravity(Gravity.CENTER_VERTICAL | Gravity.LEFT);
        edit.setInputType(inputType);
        return edit;
    }

    private String formatNumber(float number) {
        return String.format(Locale.US, "%.2f", number);
    }

    private void saveSettings() {
        getSharedPreferences("homa_mqtt", MODE_PRIVATE).edit()
                .putString("server_host", brokerHost)
                .putInt("server_port", brokerPort)
                .putString("client_id", brokerClientId)
                .putString(module.id() + ".request_topic", requestTopic)
                .putString(module.id() + ".response_topic", responseTopic)
                .putInt(module.id() + ".info_interval_seconds", infoIntervalSeconds)
                // این دو نام قدیمی برای انتقال تنظیمات قبلی همین یخچال نگه داشته شده‌اند.
                .putString("request_topic", requestTopic)
                .putString("response_topic", responseTopic)
                .putFloat(module.id() + ".target_temperature", fridgeTemp)
                .putFloat(module.id() + ".hysteresis", fridgeHysteresis)
                .putBoolean(module.id() + ".has_saved_settings", hasSavedFridgeSettings)
                .putBoolean(module.id() + ".settings_pending", fridgeSettingsPending)
                .putFloat("fridge_temp", fridgeTemp)
                .putFloat("fridge_hysteresis", fridgeHysteresis)
                .putBoolean("has_saved_fridge_settings", hasSavedFridgeSettings)
                .putBoolean("fridge_settings_pending", fridgeSettingsPending)
                .apply();
    }

    // تبلت فقط حافظهٔ آخرین پاسخ رزبری را می‌خواند؛ نه MQTT و نه ثبت تاریخچه دارد.
    private Object serverRequest(String method, String path, JSONObject body) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) new URL("http://" + brokerHost + ":" + brokerPort + path).openConnection();
        connection.setConnectTimeout(6000); connection.setReadTimeout(8000);
        connection.setRequestMethod(method); connection.setRequestProperty("Content-Type", "application/json");
        try {
            if (body != null) {
                byte[] bytes = body.toString().getBytes(StandardCharsets.UTF_8);
                connection.setDoOutput(true); connection.setFixedLengthStreamingMode(bytes.length);
                java.io.OutputStream output = connection.getOutputStream(); output.write(bytes); output.close();
            }
            int code = connection.getResponseCode();
            InputStream input = code < 400 ? connection.getInputStream() : connection.getErrorStream();
            ByteArrayOutputStream bytes = new ByteArrayOutputStream();
            if (input != null) {
                byte[] buffer = new byte[4096]; int count;
                while ((count = input.read(buffer)) != -1) {
                    bytes.write(buffer, 0, count);
                    if (bytes.size() > 1048576) throw new Exception("پاسخ بزرگ‌تر از حد مجاز");
                }
                input.close();
            }
            String text = new String(bytes.toByteArray(), StandardCharsets.UTF_8);
            if (code >= 400) throw new Exception("خطای سرور " + code);
            return text.trim().startsWith("[") ? new JSONArray(text) : new JSONObject(text);
        } finally { connection.disconnect(); }
    }

    private void connect() {
        serverEnabled = true; serverGeneration++;
        handler.removeCallbacks(requestLoop);
        setStatus("در حال دریافت از رزبری…", false);
        refreshFromServer();
    }

    // گزارش خواندنی برای تست از ADB؛ هیچ فرمان دستگاهی اجرا نمی‌کند.
    @Override
    public void dump(String prefix, java.io.FileDescriptor fd, java.io.PrintWriter writer, String[] args) {
        super.dump(prefix, fd, writer, args);
        writer.println(prefix + "Homa transport=raspberry-http modulePolling=false localHistory=false");
        writer.println(prefix + "Homa server=" + brokerHost + ":" + brokerPort + " connected=" + connected);
        JSONObject latest = remoteFridge == null ? null : remoteFridge.optJSONObject("latest");
        writer.println(prefix + "Homa latest_id=" + (latest == null ? -1 : latest.optLong("id", -1)));
    }

    private void refreshFromServer() {
        final int generation = serverGeneration;
        serverExecutor.execute(() -> {
            try {
                JSONArray modules = (JSONArray) serverRequest("GET", "/api/modules", null);
                JSONObject found = null;
                for (int i=0; i<modules.length(); i++) {
                    JSONObject candidate = modules.getJSONObject(i);
                    if (module.id().equals(candidate.optString("id"))) found = candidate;
                }
                final JSONObject data = found;
                runOnUiThread(() -> {
                    if (!serverEnabled || generation != serverGeneration) return;
                    connected = true; connectButton.setText("قطع اتصال");
                    remoteFridge = data;
                    if (data != null) {
                        requestTopic = data.optString("request_topic", requestTopic);
                        responseTopic = data.optString("response_topic", responseTopic);
                        infoIntervalSeconds = data.optInt("interval", infoIntervalSeconds);
                        JSONObject latest = data.optJSONObject("latest");
                        if (latest != null) showMessage(latest.optString("payload", "{}"));
                        setStatus(data.optBoolean("online") ? "متصل به رزبری؛ پاسخ تازه" : "متصل به رزبری؛ آخرین داده قدیمی است", true);
                    } else setStatus("متصل؛ ماژول یخچال روی سرور یافت نشد", false);
                    localCountView.setText("آرشیو اصلی: کامپیوتر · بافر: رزبری · ثبت محلی تبلت غیرفعال");
                    handler.postDelayed(requestLoop, 5000);
                });
            } catch (Exception error) {
                runOnUiThread(() -> {
                    if (!serverEnabled || generation != serverGeneration) return;
                    connected = false; connectButton.setText("اتصال دوباره");
                    setStatus("رزبری در دسترس نیست؛ تلاش مجدد خودکار", false);
                    handler.postDelayed(requestLoop, 5000);
                });
            }
        });
    }

    private void saveRemoteFridge(boolean parametersChanged) {
        if (remoteFridge == null) { setStatus("ابتدا اطلاعات سرور را دریافت کنید", false); return; }
        try {
            final JSONObject data = new JSONObject(remoteFridge.toString());
            data.put("request_topic", requestTopic); data.put("response_topic", responseTopic);
            data.put("interval", infoIntervalSeconds);
            if (parametersChanged) {
                data.put("temperature", fridgeTemp); data.put("hysteresis", fridgeHysteresis);
                data.put("apply_parameters", true);
            }
            serverExecutor.execute(() -> {
                try {
                    JSONObject result = (JSONObject) serverRequest("PUT", "/api/modules", data);
                    runOnUiThread(() -> {
                        fridgeSettingsPending = false; saveSettings();
                        setStatus(result.has("parameters_error") ? "ذخیره شد؛ ارسال ناموفق: " + result.optString("parameters_error") :
                            result.optBoolean("parameters_queued") ? "ذخیره شد؛ تنظیمات در صف ارسال رزبری است" : "تنظیمات سرور ذخیره شد", true);
                    });
                } catch (Exception error) { runOnUiThread(() -> setStatus("ذخیرهٔ سرور ناموفق: " + error.getMessage(), false)); }
            });
        } catch (Exception error) { setStatus("تنظیمات نامعتبر است", false); }
    }

    private void showMessage(String payload) {
        rawMessageView.setText(payload);
        try {
            ModuleMessage parsed = module.parseMessage(payload);
            if (parsed.isCommandAccepted()) {
                setStatus("پیام وضعیت دریافت شد", true);
                return;
            }
            Map<String, String> values = parsed.values();
            insideTempView.setText(valueOrDash(values, "insideTemp"));
            outsideTempView.setText(valueOrDash(values, "outsideTemp"));
            for (String key : new String[]{"targetTemp", "hysteresis", "minTemp",
                    "maxTemp", "onTime", "offTime", "ip"}) {
                moduleTile.setFieldValue(key, valueOrDash(values, key));
            }
            if (!fridgeSettingsPending) {
                fridgeTemp = parseFloatOr(values.get("settingTemp"), fridgeTemp);
                fridgeHysteresis = parseFloatOr(
                        values.get("settingHysteresis"), fridgeHysteresis);
            }
            setStatus("اطلاعات یخچال دریافت شد", true);
        } catch (Exception error) {
            setStatus("پیام رسید، ولی قالب آن JSON معتبر نیست", false);
        }
    }

    private Map<String, String> fridgeSettingsMap() {
        Map<String, String> settings = new HashMap<>();
        settings.put("Temp", String.valueOf(fridgeTemp));
        settings.put("Hyster", String.valueOf(fridgeHysteresis));
        return settings;
    }

    private String valueOrDash(Map<String, String> values, String key) {
        String value = values.get(key);
        return value == null || value.isEmpty() ? "—" : value;
    }

    private float parseFloatOr(String value, float fallback) {
        try {
            return Float.parseFloat(value);
        } catch (Exception ignored) {
            return fallback;
        }
    }

    private void disconnect(boolean showStatus) {
        serverEnabled = false; serverGeneration++;
        handler.removeCallbacks(requestLoop); connected = false;
        if (connectButton != null) connectButton.setText("اتصال");
        if (showStatus) setStatus("ارتباط با سرور قطع شد", false);
    }

    private void setStatus(String message, boolean isConnected) {
        statusView.setText(message);
        statusView.setTextColor(isConnected ? Color.rgb(104, 231, 211) : Color.rgb(255, 211, 137));
    }

    private LinearLayout card() {
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(dp(16), dp(16), dp(16), dp(16));
        layout.setBackground(round(0xEE203342, dp(20), 0x556B8A9A));
        return layout;
    }

    private void addSectionTitle(LinearLayout card, String title) {
        TextView view = text("◆  " + title, 19, Color.rgb(111, 224, 207), true);
        card.addView(view, params(-1, -2));
    }

    private TextView metric(LinearLayout row, String label, String value, int color) {
        LinearLayout tile = new LinearLayout(this);
        tile.setOrientation(LinearLayout.HORIZONTAL);
        tile.setGravity(Gravity.CENTER_VERTICAL);
        tile.setLayoutDirection(LinearLayout.LAYOUT_DIRECTION_LTR);
        tile.setPadding(dp(13), dp(13), dp(13), dp(13));
        tile.setBackground(round(0x3325CDB7, dp(15), 0x5565DCCB));
        TextView valueView = text(value, 27, color, true);
        valueView.setGravity(Gravity.LEFT);
        TextView labelView = text(label, 19, Color.rgb(200, 216, 224), false);
        valueView.setGravity(Gravity.LEFT);
        tile.addView(valueView, new LinearLayout.LayoutParams(-2, -2));
        tile.addView(labelView, new LinearLayout.LayoutParams(0, -2, 1f));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, -2, 1f);
        lp.leftMargin = dp(5);
        lp.rightMargin = dp(5);
        row.addView(tile, lp);
        return valueView;
    }

    private TextView text(String value, int size, int color, boolean bold) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(size);
        view.setTextColor(color);
        view.setGravity(Gravity.RIGHT);
        if (bold) view.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        return view;
    }

    private GradientDrawable round(int color, int radius, int stroke) {
        GradientDrawable shape = new GradientDrawable();
        shape.setColor(color);
        shape.setCornerRadius(radius);
        if (stroke != 0) shape.setStroke(dp(1), stroke);
        return shape;
    }

    private LinearLayout.LayoutParams spaced() {
        LinearLayout.LayoutParams lp = params(-1, -2);
        lp.topMargin = dp(10);
        return lp;
    }

    private LinearLayout.LayoutParams pageParams() {
        LinearLayout.LayoutParams lp = params(-1, -2);
        lp.topMargin = dp(16);
        return lp;
    }

    private LinearLayout.LayoutParams params(int width, int height) {
        return new LinearLayout.LayoutParams(width, height);
    }

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density + 0.5f);
    }

    @Override
    protected void onDestroy() {
        disconnect(false);
        serverExecutor.shutdownNow();
        super.onDestroy();
    }
}
