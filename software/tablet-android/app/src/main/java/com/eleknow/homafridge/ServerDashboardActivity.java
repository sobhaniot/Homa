package com.eleknow.homafridge;

import android.app.Activity;
import android.app.AlertDialog;
import android.os.Bundle;
import android.os.Handler;
import android.os.SystemClock;
import android.graphics.Color;
import android.text.InputType;
import android.view.Gravity;
import android.view.WindowManager;
import android.widget.*;
import org.json.*;
import java.net.*;
import java.io.*;
import java.util.*;
import java.util.concurrent.*;

/** نمایشگر عمومی Android 4.4؛ تعریف کارت و فرم تنها از رزبری می‌آید. */
public class ServerDashboardActivity extends Activity {
    private final Handler handler=new Handler();
    private final ExecutorService executor=Executors.newSingleThreadExecutor();
    private LinearLayout cards;
    private TextView status;
    private String host;
    private int port,generation;
    private boolean active;
    private long lastBack;
    private final Runnable refreshTask=()->refresh();

    @Override public void onCreate(Bundle state){
        super.onCreate(state);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        host=getSharedPreferences("homa_mqtt",MODE_PRIVATE).getString("server_host","192.168.1.55");
        port=getSharedPreferences("homa_mqtt",MODE_PRIVATE).getInt("server_port",8080);
        ScrollView scroll=new ScrollView(this);scroll.setBackgroundColor(Color.rgb(14,29,42));
        LinearLayout page=column();page.setPadding(dp(18),dp(20),dp(18),dp(30));page.setLayoutDirection(LinearLayout.LAYOUT_DIRECTION_RTL);scroll.addView(page);
        page.addView(text("هما • مانیتور خانه",28));status=text("در انتظار فهرست رزبری…",18);page.addView(status);
        Button connection=new Button(this);connection.setText("اتصال به رزبری");connection.setOnClickListener(v->connectionDialog());page.addView(connection);
        cards=column();page.addView(cards);setContentView(scroll);
    }
    @Override public void onStart(){super.onStart();active=true;refresh();}
    @Override public void onStop(){active=false;generation++;handler.removeCallbacks(refreshTask);super.onStop();}
    @Override public void onDestroy(){executor.shutdownNow();super.onDestroy();}
    @Override public void onBackPressed(){long now=SystemClock.elapsedRealtime();if(lastBack>0&&now-lastBack<2000)super.onBackPressed();else{lastBack=now;toast("برای خروج دوباره Back را بزنید");}}

    private void refresh(){
        if(!active)return;final int current=++generation;
        executor.execute(()->{try{
            JSONArray modules=new JSONArray(request("/api/modules",null));
            handler.post(()->{if(!active||current!=generation)return;render(modules);status.setText("متصل به رزبری • "+host+":"+port);handler.postDelayed(refreshTask,5000);});
        }catch(Exception e){handler.post(()->{if(!active||current!=generation)return;status.setText("اتصال ناموفق: "+e.getMessage());handler.postDelayed(refreshTask,5000);});}});
    }
    private void render(JSONArray modules){
        cards.removeAllViews();int count=0;
        for(int i=0;i<modules.length();i++){
            JSONObject m=modules.optJSONObject(i);if(m==null||!m.optBoolean("enabled"))continue;
            count++;LinearLayout card=column();card.setPadding(dp(14),dp(14),dp(14),dp(16));card.setBackgroundColor(Color.rgb(27,49,61));
            LinearLayout.LayoutParams outer=new LinearLayout.LayoutParams(-1,-2);outer.topMargin=dp(18);cards.addView(card,outer);
            LinearLayout heading=new LinearLayout(this);heading.setGravity(Gravity.CENTER_VERTICAL);TextView title=text(m.optString("name"),26);heading.addView(title,new LinearLayout.LayoutParams(0,-2,1));
            Button gear=new Button(this);gear.setText("⚙");gear.setTextSize(24);gear.setOnClickListener(v->settingsDialog(m));heading.addView(gear);card.addView(heading);
            card.addView(text(m.optBoolean("online")?"پاسخ تازه موجود است":"بدون پاسخ تازه",16));
            JSONObject ui=m.optJSONObject("ui");JSONArray fields=ui==null?null:ui.optJSONArray("fields");
            if(fields==null){card.addView(text("تعریف کارت را در رزبری تکمیل کنید",20));continue;}
            int columns=Math.max(1,Math.min(2,ui.optInt("columns",2))),visible=0;LinearLayout row=null;
            for(int n=0;n<fields.length();n++){
                JSONObject f=fields.optJSONObject(n);if(f==null||!f.optBoolean("visible"))continue;
                if(visible++%columns==0){row=new LinearLayout(this);card.addView(row);}
                LinearLayout cell=new LinearLayout(this);cell.setGravity(Gravity.CENTER_VERTICAL);cell.setPadding(dp(8),dp(10),dp(8),dp(10));
                TextView label=text(f.optString("label"),22),value=text(display(f.opt("value"))+" "+f.optString("unit"),24);value.setTextColor(Color.rgb(96,224,205));value.setGravity(Gravity.LEFT);
                cell.addView(label,new LinearLayout.LayoutParams(0,-2,1));cell.addView(value);row.addView(cell,new LinearLayout.LayoutParams(0,-2,1));
            }
            if(visible%columns!=0&&row!=null)row.addView(new TextView(this),new LinearLayout.LayoutParams(0,1,1));
        }
        if(count==0)cards.addView(text("ماژول فعالی در رزبری تعریف نشده است",22));
    }
    private void settingsDialog(JSONObject module){
        JSONObject ui=module.optJSONObject("ui");JSONArray fields=ui==null?null:ui.optJSONArray("fields");if(fields==null){toast("تعریف فرم موجود نیست");return;}
        LinearLayout form=column();form.setPadding(dp(18),dp(10),dp(18),dp(10));form.setLayoutDirection(LinearLayout.LAYOUT_DIRECTION_RTL);
        Map<String,EditText> inputs=new HashMap<>();Map<String,CheckBox> switches=new HashMap<>();List<JSONObject> editable=new ArrayList<>();
        for(int i=0;i<fields.length();i++){
            JSONObject f=fields.optJSONObject(i);if(f==null||!f.optBoolean("editable"))continue;editable.add(f);String key=f.optString("key"),type=f.optString("type");
            if(type.equals("boolean")){CheckBox check=new CheckBox(this);check.setText(f.optString("label"));check.setTextSize(22);check.setChecked(f.optBoolean("value"));switches.put(key,check);form.addView(check);continue;}
            form.addView(text(f.optString("label")+" "+f.optString("unit"),20));EditText input=new EditText(this);input.setTextSize(24);
            if(type.equals("text"))input.setInputType(InputType.TYPE_CLASS_TEXT);else input.setInputType(InputType.TYPE_CLASS_NUMBER|InputType.TYPE_NUMBER_FLAG_SIGNED|(type.equals("integer")?0:InputType.TYPE_NUMBER_FLAG_DECIMAL));
            input.setText(f.isNull("value")?"":f.optString("value"));inputs.put(key,input);form.addView(input);
        }
        if(editable.isEmpty()){toast("در رزبری فیلد قابل تنظیمی تعریف نشده است");return;}
        form.addView(text("ارسال، تنظیم واقعی دستگاه را تغییر می‌دهد. پذیرش سرور به معنی تأیید دستگاه نیست.",16));
        ScrollView scroll=new ScrollView(this);scroll.addView(form);
        AlertDialog dialog=new AlertDialog.Builder(this).setTitle("تنظیمات "+module.optString("name")).setView(scroll).setNegativeButton("انصراف",null).setPositiveButton("ارسال به دستگاه",null).create();
        dialog.setOnShowListener(v->{dialog.getWindow().setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);dialog.getButton(-1).setOnClickListener(button->{
            JSONObject values=new JSONObject();try{for(JSONObject f:editable){String key=f.optString("key"),type=f.optString("type");Object value;
                if(type.equals("boolean"))value=switches.get(key).isChecked();else if(type.equals("text"))value=inputs.get(key).getText().toString();else{
                    double number=Double.parseDouble(latin(inputs.get(key).getText().toString()));
                    if(Double.isNaN(number)||Double.isInfinite(number)||(type.equals("integer")&&Math.rint(number)!=number)||number<f.optDouble("min",-1e12)||number>f.optDouble("max",1e12))throw new Exception("مقدار "+f.optString("label")+" نامعتبر است");value=number;}
                Object previous=type.equals("boolean")?f.optBoolean("value"):f.opt("value");boolean same=value instanceof Number&&previous instanceof Number?Double.compare(((Number)value).doubleValue(),((Number)previous).doubleValue())==0:value.equals(previous);
                if(!same)values.put(key,value);
            }
            if(values.length()==0){toast("مقداری تغییر نکرده است");return;}
            JSONObject body=new JSONObject().put("confirm",true).put("schema_revision",ui.optString("revision")).put("values",values);dialog.getButton(-1).setEnabled(false);
            executor.execute(()->{try{request("/api/modules/"+module.optString("id")+"/settings",body);handler.post(()->{if(!active)return;dialog.dismiss();toast("در صف ارسال قرار گرفت؛ منتظر گزارش دستگاه باشید.");});}
              catch(Exception e){handler.post(()->{if(dialog.isShowing()){dialog.getButton(-1).setEnabled(true);toast("نتیجهٔ ارسال را بررسی کنید: "+e.getMessage());}});}});
            }catch(Exception e){toast(e.getMessage());}
        });});dialog.show();
    }
    private String request(String path,JSONObject body)throws Exception{
        HttpURLConnection c=(HttpURLConnection)new URL("http",host,port,path).openConnection();c.setConnectTimeout(6000);c.setReadTimeout(8000);
        try{if(body!=null){c.setRequestMethod("POST");c.setDoOutput(true);c.setRequestProperty("Content-Type","application/json");byte[] bytes=body.toString().getBytes("UTF-8");c.setFixedLengthStreamingMode(bytes.length);try(OutputStream out=c.getOutputStream()){out.write(bytes);}}
            int code=c.getResponseCode();InputStream in=code>=300?c.getErrorStream():c.getInputStream();ByteArrayOutputStream output=new ByteArrayOutputStream();byte[] buffer=new byte[4096];int length;
            if(in!=null){while((length=in.read(buffer))!=-1)output.write(buffer,0,length);in.close();}String result=output.toString("UTF-8");if(code>=300)throw new Exception(new JSONObject(result).optString("error","خطای سرور"));return result;
        }finally{c.disconnect();}
    }
    private void connectionDialog(){LinearLayout box=column();EditText address=new EditText(this),number=new EditText(this);address.setText(host);number.setText(""+port);number.setInputType(InputType.TYPE_CLASS_NUMBER);box.addView(text("آدرس رزبری",20));box.addView(address);box.addView(text("پورت پنل",20));box.addView(number);
        new AlertDialog.Builder(this).setTitle("اتصال اولیه").setView(box).setNegativeButton("انصراف",null).setPositiveButton("ذخیره",(d,w)->{try{int p=Integer.parseInt(number.getText().toString());String h=address.getText().toString().trim();if(p<1||p>65535||!h.matches("[A-Za-z0-9.:-]+"))throw new Exception();host=h;port=p;getSharedPreferences("homa_mqtt",MODE_PRIVATE).edit().putString("server_host",host).putInt("server_port",port).apply();generation++;handler.removeCallbacks(refreshTask);refresh();}catch(Exception e){toast("آدرس یا پورت نامعتبر است");}}).show();}
    private String latin(String value){for(int i=0;i<10;i++)value=value.replace((char)('۰'+i),(char)('0'+i)).replace((char)('٠'+i),(char)('0'+i));return value.replace('٫','.').replace('−','-').trim();}
    private String display(Object value){if(value==null||value==JSONObject.NULL)return "—";if(value instanceof Boolean)return (Boolean)value?"روشن":"خاموش";return String.valueOf(value);}
    private LinearLayout column(){LinearLayout v=new LinearLayout(this);v.setOrientation(LinearLayout.VERTICAL);return v;}
    private TextView text(String value,int size){TextView v=new TextView(this);v.setText(value);v.setTextSize(size);v.setTextColor(Color.WHITE);v.setPadding(0,dp(6),0,dp(6));return v;}
    private int dp(int value){return (int)(value*getResources().getDisplayMetrics().density+.5f);}
    private void toast(String message){Toast.makeText(this,message,Toast.LENGTH_LONG).show();}
}
