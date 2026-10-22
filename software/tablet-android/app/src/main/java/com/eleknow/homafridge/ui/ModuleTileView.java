package com.eleknow.homafridge.ui;

import android.content.Context;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.widget.ImageButton;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.eleknow.homafridge.modules.ModuleField;
import com.eleknow.homafridge.modules.MqttModule;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** کارت مشترک ماژول‌ها: عنوان، چرخ‌دندهٔ تنظیمات و شبکهٔ دو ستونهٔ داده‌ها. */
public final class ModuleTileView extends LinearLayout {
    private final Context context;
    private final LinearLayout customContent;
    private final Map<String, TextView> values = new HashMap<>();

    public ModuleTileView(Context context, MqttModule module, Runnable onSettings) {
        super(context);
        this.context = context;
        setOrientation(VERTICAL);
        setPadding(dp(16), dp(16), dp(16), dp(16));
        setBackground(round(0xEE203342, dp(20), 0x556B8A9A));

        LinearLayout header = new LinearLayout(context);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setLayoutDirection(LAYOUT_DIRECTION_LTR);

        ImageButton gear = new ImageButton(context);
        gear.setImageResource(android.R.drawable.ic_menu_preferences);
        gear.setColorFilter(Color.WHITE);
        gear.setScaleType(android.widget.ImageView.ScaleType.CENTER_INSIDE);
        gear.setContentDescription("تنظیمات " + module.title());
        gear.setBackground(round(0x3325CDB7, dp(12), 0x5565DCCB));
        gear.setOnClickListener(view -> onSettings.run());
        header.addView(gear, new LayoutParams(dp(46), dp(42)));

        TextView title = text(module.title(), 19, Color.rgb(111, 224, 207), true);
        header.addView(title, new LayoutParams(0, -2, 1f));
        addView(header, new LayoutParams(-1, -2));

        customContent = new LinearLayout(context);
        customContent.setOrientation(VERTICAL);
        LayoutParams customParams = new LayoutParams(-1, -2);
        customParams.topMargin = dp(10);
        addView(customContent, customParams);

        LinearLayout fieldGrid = new LinearLayout(context);
        fieldGrid.setOrientation(VERTICAL);
        LayoutParams gridParams = new LayoutParams(-1, -2);
        gridParams.topMargin = dp(7);
        addView(fieldGrid, gridParams);
        populateFields(fieldGrid, module.displayFields());
    }

    public void addCustomContent(android.view.View view) {
        customContent.addView(view, new LayoutParams(-1, -2));
    }

    public void setFieldValue(String key, String value) {
        TextView field = values.get(key);
        if (field != null) field.setText(value == null ? "—" : value);
    }

    private void populateFields(LinearLayout grid, List<ModuleField> fields) {
        LinearLayout row = null;
        int inRow = 0;
        for (ModuleField field : fields) {
            if (field.fullWidth) {
                if (inRow != 0) {
                    addViewToGrid(grid, row, inRow == 1);
                    row = null;
                    inRow = 0;
                }
                grid.addView(createField(field), itemParams(-1, 1f));
                continue;
            }
            if (row == null) {
                row = new LinearLayout(context);
                row.setOrientation(HORIZONTAL);
                row.setLayoutDirection(LAYOUT_DIRECTION_RTL);
            }
            row.addView(createField(field), itemParams(0, 1f));
            inRow++;
            if (inRow == 2) {
                grid.addView(row, new LayoutParams(-1, -2));
                row = null;
                inRow = 0;
            }
        }
        if (inRow != 0) addViewToGrid(grid, row, true);
    }

    private void addViewToGrid(LinearLayout grid, LinearLayout row, boolean addSpacer) {
        if (addSpacer) row.addView(new android.view.View(context), itemParams(0, 1f));
        grid.addView(row, new LayoutParams(-1, -2));
    }

    private LayoutParams itemParams(int width, float weight) {
        LayoutParams params = new LayoutParams(width, -2, weight);
        params.setMargins(dp(3), dp(3), dp(3), dp(3));
        return params;
    }

    private LinearLayout createField(ModuleField field) {
        LinearLayout item = new LinearLayout(context);
        item.setOrientation(HORIZONTAL);
        item.setGravity(android.view.Gravity.CENTER_VERTICAL);
        item.setLayoutDirection(LAYOUT_DIRECTION_LTR);
        item.setPadding(dp(10), dp(8), dp(10), dp(8));
        item.setBackground(round(0x33203142, dp(11), 0x334B7184));
        TextView label = text(field.label, 22, Color.rgb(170, 193, 205), false);
        TextView value = text("—", 17, Color.WHITE, true);
        value.setTextDirection(TextView.TEXT_DIRECTION_LTR);
        value.setGravity(Gravity.LEFT);
        item.addView(value, new LayoutParams(-2, -2));
        item.addView(label, new LayoutParams(0, -2, 1f));
        values.put(field.key, value);
        return item;
    }

    private TextView text(String value, int size, int color, boolean bold) {
        TextView view = new TextView(context);
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

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density + 0.5f);
    }
}
