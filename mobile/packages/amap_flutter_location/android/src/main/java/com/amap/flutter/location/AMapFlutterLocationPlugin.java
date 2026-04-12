package com.amap.flutter.location;

import android.content.Context;
import android.text.TextUtils;

import androidx.annotation.NonNull;

import com.amap.api.location.AMapLocationClient;

import java.lang.reflect.Method;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** 高德地图定位sdkFlutterPlugin */
public class AMapFlutterLocationPlugin implements FlutterPlugin, MethodCallHandler,
        EventChannel.StreamHandler {
  private static final String CHANNEL_METHOD_LOCATION = "amap_flutter_location";
  private static final String CHANNEL_STREAM_LOCATION = "amap_flutter_location_stream";

  private Context mContext = null;

  public static EventChannel.EventSink mEventSink = null;

  private MethodChannel methodChannel;
  private EventChannel eventChannel;

  private Map<String, AMapLocationClientImpl> locationClientMap = new ConcurrentHashMap<String, AMapLocationClientImpl>(8);

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "updatePrivacyStatement":
        updatePrivacyStatement((Map) call.arguments);
        result.success(null);
        break;
      case "setApiKey":
        setApiKey((Map) call.arguments);
        result.success(null);
        break;
      case "setLocationOption":
        setLocationOption((Map) call.arguments);
        result.success(null);
        break;
      case "startLocation":
        startLocation((Map) call.arguments);
        result.success(null);
        break;
      case "stopLocation":
        stopLocation((Map) call.arguments);
        result.success(null);
        break;
      case "destroy":
        destroy((Map) call.arguments);
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  @Override
  public void onListen(Object o, EventChannel.EventSink eventSink) {
    mEventSink = eventSink;
  }

  @Override
  public void onCancel(Object o) {
    for (Map.Entry<String, AMapLocationClientImpl> entry : locationClientMap.entrySet()) {
      entry.getValue().stopLocation();
    }
  }

  /**
   * 开始定位
   */
  private void startLocation(Map argsMap) {
    AMapLocationClientImpl locationClientImp = getLocationClientImp(argsMap);
    if (null != locationClientImp) {
      locationClientImp.startLocation();
    }
  }


  /**
   * 停止定位
   */
  private void stopLocation(Map argsMap) {
    AMapLocationClientImpl locationClientImp = getLocationClientImp(argsMap);
    if (null != locationClientImp) {
      locationClientImp.stopLocation();
    }
  }

  /**
   * 销毁
   *
   * @param argsMap
   */
  private void destroy(Map argsMap) {
    AMapLocationClientImpl locationClientImp = getLocationClientImp(argsMap);
    if (null != locationClientImp) {
      locationClientImp.destroy();

      locationClientMap.remove(getPluginKeyFromArgs(argsMap));
    }
  }

  /**
   * 设置apikey
   *
   * @param apiKeyMap
   */
  private void setApiKey(Map apiKeyMap) {
    if (null != apiKeyMap) {
      if (apiKeyMap.containsKey("android")
              && !TextUtils.isEmpty((String) apiKeyMap.get("android"))) {
        AMapLocationClient.setApiKey((String) apiKeyMap.get("android"));
      }
    }
  }

  private void updatePrivacyStatement(Map privacyShowMap) {
    if (null != privacyShowMap) {
      Class<AMapLocationClient> locationClazz = AMapLocationClient.class;

      if (privacyShowMap.containsKey("hasContains") && privacyShowMap.containsKey("hasShow")) {
        boolean hasContains = (boolean) privacyShowMap.get("hasContains");
        boolean hasShow = (boolean) privacyShowMap.get("hasShow");
        try {
          Method showMethod = locationClazz.getMethod("updatePrivacyShow", Context.class, boolean.class, boolean.class);;
          showMethod.invoke(null, mContext, hasContains, hasShow);
        } catch (Throwable e) {
//          e.printStackTrace();
        }
      }

      if (privacyShowMap.containsKey("hasAgree")) {
        boolean hasAgree = (boolean) privacyShowMap.get("hasAgree");
        try {
          Method agreeMethod = locationClazz.getMethod("updatePrivacyAgree", Context.class, boolean.class);
          agreeMethod.invoke(null, mContext, hasAgree);
        } catch (Throwable e) {
//            e.printStackTrace();
        }
      }
    }
  }

  /**
   * 设置定位参数
   *
   * @param argsMap
   */
  private void setLocationOption(Map argsMap) {
    AMapLocationClientImpl locationClientImp = getLocationClientImp(argsMap);
    if (null != locationClientImp) {
      locationClientImp.setLocationOption(argsMap);
    }
  }


  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    mContext = binding.getApplicationContext();

    BinaryMessenger messenger = binding.getBinaryMessenger();
    methodChannel = new MethodChannel(messenger, CHANNEL_METHOD_LOCATION);
    methodChannel.setMethodCallHandler(this);

    eventChannel = new EventChannel(messenger, CHANNEL_STREAM_LOCATION);
    eventChannel.setStreamHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    for (Map.Entry<String, AMapLocationClientImpl> entry : locationClientMap.entrySet()) {
      entry.getValue().destroy();
    }
    locationClientMap.clear();
    mEventSink = null;
    if (methodChannel != null) {
      methodChannel.setMethodCallHandler(null);
      methodChannel = null;
    }
    if (eventChannel != null) {
      eventChannel.setStreamHandler(null);
      eventChannel = null;
    }
    mContext = null;
  }

  private AMapLocationClientImpl getLocationClientImp(Map argsMap) {
    if (null == locationClientMap) {
      locationClientMap = new ConcurrentHashMap<String, AMapLocationClientImpl>(8);
    }

    String pluginKey = getPluginKeyFromArgs(argsMap);
    if (TextUtils.isEmpty(pluginKey)) {
      return null;
    }

    if (!locationClientMap.containsKey(pluginKey)) {
      AMapLocationClientImpl locationClientImp = new AMapLocationClientImpl(mContext, pluginKey, mEventSink);
      locationClientMap.put(pluginKey, locationClientImp);
    }
    return locationClientMap.get(pluginKey);
  }

  private String getPluginKeyFromArgs(Map argsMap) {
    String pluginKey = null;
    try {
      if (null != argsMap) {
        pluginKey = (String) argsMap.get("pluginKey");
      }
    } catch (Throwable e) {
      e.printStackTrace();
    }
    return pluginKey;
  }
}
