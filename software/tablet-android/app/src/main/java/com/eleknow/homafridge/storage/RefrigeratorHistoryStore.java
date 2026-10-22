package com.eleknow.homafridge.storage;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/** نگهداری محلی پاسخ‌های یخچال روی تبلت Android 4.4. */
public final class RefrigeratorHistoryStore extends SQLiteOpenHelper {
    private static final String DATABASE_NAME = "homa_history.db";
    private static final int DATABASE_VERSION = 1;
    private static final String TABLE = "refrigerator_samples";

    public RefrigeratorHistoryStore(Context context) {
        super(context.getApplicationContext(), DATABASE_NAME, null, DATABASE_VERSION);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE " + TABLE + " ("
                + "id INTEGER PRIMARY KEY AUTOINCREMENT, "
                + "received_at_ms INTEGER NOT NULL, "
                + "payload TEXT NOT NULL, "
                + "UNIQUE(received_at_ms, payload))");
        db.execSQL("CREATE INDEX refrigerator_samples_time "
                + "ON " + TABLE + "(received_at_ms)");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        // در نسخه‌های بعدی مهاجرت جدول‌ها را اضافه می‌کنیم و تاریخچه را پاک نمی‌کنیم.
    }

    /** هر پیام معتبر را با زمان دریافت روی همین تبلت ذخیره می‌کند. */
    public synchronized long save(String payload, long receivedAtMs) {
        ContentValues values = new ContentValues();
        values.put("received_at_ms", receivedAtMs);
        values.put("payload", payload);
        return getWritableDatabase().insertWithOnConflict(
                TABLE, null, values, SQLiteDatabase.CONFLICT_IGNORE);
    }

    /** تعداد رکوردهای بایگانی‌شده برای نمایش وضعیت محلی را برمی‌گرداند. */
    public synchronized long count() {
        Cursor cursor = getReadableDatabase().rawQuery(
                "SELECT COUNT(*) FROM " + TABLE, null);
        try {
            return cursor.moveToFirst() ? cursor.getLong(0) : 0;
        } finally {
            cursor.close();
        }
    }

    /** یک صفحه از داده‌های بازهٔ درخواستی را برای اپ ویندوز می‌سازد. */
    public synchronized JSONObject readPage(long fromMs, long toMs,
                                             int offset, int limit,
                                             String requestId) throws JSONException {
        JSONArray items = new JSONArray();
        Cursor cursor = getReadableDatabase().rawQuery(
                "SELECT received_at_ms, payload FROM " + TABLE
                        + " WHERE received_at_ms >= ? AND received_at_ms <= ?"
                        + " ORDER BY received_at_ms ASC, id ASC LIMIT ? OFFSET ?",
                new String[]{String.valueOf(fromMs), String.valueOf(toMs),
                        String.valueOf(limit + 1), String.valueOf(offset)});
        boolean hasMore;
        try {
            hasMore = cursor.getCount() > limit;
            int added = 0;
            while (added < limit && cursor.moveToNext()) {
                JSONObject item = new JSONObject();
                item.put("receivedAt", cursor.getLong(0));
                item.put("payload", new JSONObject(cursor.getString(1)));
                items.put(item);
                added++;
            }
        } finally {
            cursor.close();
        }

        JSONObject page = new JSONObject();
        page.put("type", "HistoryBatch");
        page.put("requestId", requestId);
        page.put("offset", offset);
        page.put("nextOffset", offset + items.length());
        page.put("hasMore", hasMore);
        page.put("items", items);
        return page;
    }
}
