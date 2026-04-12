package com.amap.flutter.location;

import android.content.Context;

import com.amap.api.location.AMapLocation;
import com.amap.api.location.AMapLocationClient;
import com.amap.api.location.AMapLocationClientOption;
import com.amap.api.location.AMapLocationListener;

import java.util.Map;

import io.flutter.plugin.common.EventChannel;

/**
 * @author whm
 * @date 2020-04-16 15:49
 * @mail hongming.whm@alibaba-inc.com
 */
public class AMapLocationClientImpl implements AMapLocationListener {

    private final Context mContext;
    private AMapLocationClientOption locationOption = new AMapLocationClientOption();
    private AMapLocationClient locationClient = null;
    private EventChannel.EventSink mEventSink;

    private final String mPluginKey;

    public AMapLocationClientImpl(Context context, String pluginKey, EventChannel.EventSink eventSink) {
        mContext = context;
        mPluginKey = pluginKey;
        mEventSink = eventSink;
        try {
            if (null == locationClient) {
                locationClient = new AMapLocationClient(context);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * 开始定位
     */
    public void startLocation() {
        ensureLocationClient();
        if (locationClient == null || locationOption == null) {
            return;
        }
        locationClient.setLocationOption(locationOption);
        locationClient.setLocationListener(this);
        locationClient.startLocation();
    }


    /**
     * 停止定位
     */
    public void stopLocation() {
        if (locationClient != null) {
            locationClient.stopLocation();
            locationClient.unRegisterLocationListener(this);
        }
    }

    public void destroy() {
        if (locationClient != null) {
            locationClient.stopLocation();
            locationClient.unRegisterLocationListener(this);
            locationClient.onDestroy();
            locationClient = null;
        }
        mEventSink = null;
    }
    /**
     * 定位回调
     *
     * @param location
     */
    @Override
    public void onLocationChanged(AMapLocation location) {
        if (mEventSink == null) {
            return;
        }
        Map<String, Object> result = Utils.buildLocationResultMap(location);
        result.put("pluginKey", mPluginKey);
        try {
            mEventSink.success(result);
        } catch (Throwable ignored) {
        }
    }

    private void ensureLocationClient() {
        if (locationClient != null) {
            return;
        }
        try {
            locationClient = new AMapLocationClient(mContext);
        } catch (Exception e) {
            locationClient = null;
        }
    }


    /**
     * 设置定位参数
     *
     * @param optionMap
     */
    public void setLocationOption(Map optionMap) {
        if (null == locationOption) {
            locationOption = new AMapLocationClientOption();
        }

        if (optionMap.containsKey("locationInterval")) {
            locationOption.setInterval(((Integer) optionMap.get("locationInterval")).longValue());
        }

        if (optionMap.containsKey("needAddress")) {
            locationOption.setNeedAddress((boolean) optionMap.get("needAddress"));
        }

        if (optionMap.containsKey("locationMode")) {
            try {
                locationOption.setLocationMode(AMapLocationClientOption.AMapLocationMode.values()[(int) optionMap.get("locationMode")]);
            } catch (Throwable e) {
            }
        }

        if (optionMap.containsKey("geoLanguage")) {
            locationOption.setGeoLanguage(AMapLocationClientOption.GeoLanguage.values()[(int) optionMap.get("geoLanguage")]);
        }

        if (optionMap.containsKey("onceLocation")) {
            locationOption.setOnceLocation((boolean) optionMap.get("onceLocation"));
        }

        if (null != locationClient) {
            locationClient.setLocationOption(locationOption);
        }
    }
}
