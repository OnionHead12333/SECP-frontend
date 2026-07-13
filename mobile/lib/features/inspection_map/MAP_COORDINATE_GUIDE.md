# 巡检地图显示与坐标转换说明

## 目的

本文档说明巡检地图在 App 中如何显示，以及 App 屏幕像素坐标、地图图片像素坐标、ROS 小车地图坐标之间如何转换。

后续 Android App 开发时，地图展示、点击设定初始位置、点击导航目标、显示小车实时位置，都应按本文档处理。

## 当前使用的地图

当前地图资源位于：

```text
assets/robot_maps/yahboomcar.png
assets/robot_maps/yahboomcar.pgm
assets/robot_maps/yahboomcar.yaml
assets/robot_maps/map_info.json
```

当前地图参数：

```text
mapName: yahboomcar
frameId: map
width: 864 px
height: 896 px
resolution: 0.05 m/cell
origin: [-22.8, -22.8, 0.0]
```

含义：

```text
width / height
  地图图片像素尺寸。

resolution
  每个像素代表的真实地图距离。当前 1 px = 0.05 m。

origin
  地图图片左下角在 ROS map 坐标系中的位置。
  当前地图左下角 = (-22.8 m, -22.8 m)。

frameId
  小车定位、导航目标、路径都使用 ROS 的 map 坐标系。
```

## 坐标系区别

### 1. 屏幕坐标

用户在手机屏幕上点击的位置。

特点：

```text
原点在屏幕左上角
x 向右增加
y 向下增加
单位是屏幕逻辑像素
会受到缩放、平移、InteractiveViewer 影响
```

屏幕坐标不能直接发给小车。

### 2. 地图图片像素坐标

地图图片内部的像素位置。

特点：

```text
原点在地图图片左上角
x 向右增加
y 向下增加
单位是地图图片像素
范围是：
  x: 0 ~ width
  y: 0 ~ height
```

当前地图范围：

```text
x: 0 ~ 864
y: 0 ~ 896
```

### 3. ROS map 坐标

小车、AMCL、Nav2 使用的真实地图坐标。

特点：

```text
原点由 yaml 的 origin 决定
x/y 单位是米
x 向地图右侧增加
y 向地图上方增加
```

当前地图 ROS 坐标范围：

```text
x_min = -22.8
y_min = -22.8
x_max = -22.8 + 864 * 0.05 = 20.4
y_max = -22.8 + 896 * 0.05 = 22.0
```

所以当前地图覆盖：

```text
x: -22.8 m ~ 20.4 m
y: -22.8 m ~ 22.0 m
```

## 地图像素转 ROS 坐标

当用户在地图图片上点击一个点时，需要先得到地图图片像素坐标：

```text
pixelX
pixelY
```

再转换为 ROS map 坐标：

```text
mapX = originX + pixelX * resolution
mapY = originY + (imageHeight - pixelY) * resolution
```

当前地图代入参数：

```text
mapX = -22.8 + pixelX * 0.05
mapY = -22.8 + (896 - pixelY) * 0.05
```

示例：

```text
用户点击地图中心：
pixelX = 432
pixelY = 448

mapX = -22.8 + 432 * 0.05 = -1.2
mapY = -22.8 + (896 - 448) * 0.05 = -0.4

ROS 坐标约为：
(-1.2, -0.4)
```

## ROS 坐标转地图像素

当 App 收到小车位置 `/amcl_pose` 或路径 `/plan` 时，ROS 坐标需要转回图片像素才能显示。

公式：

```text
pixelX = (mapX - originX) / resolution
pixelY = imageHeight - (mapY - originY) / resolution
```

当前地图代入参数：

```text
pixelX = (mapX + 22.8) / 0.05
pixelY = 896 - (mapY + 22.8) / 0.05
```

示例：

```text
小车 ROS 坐标：
mapX = -1.2
mapY = -0.4

pixelX = (-1.2 + 22.8) / 0.05 = 432
pixelY = 896 - (-0.4 + 22.8) / 0.05 = 448

地图像素约为：
(432, 448)
```

## App 点击导航目标

用户点击地图设置导航目标时，流程应为：

```text
1. 获取用户点击的屏幕坐标
2. 根据当前缩放/平移，转换成地图图片像素坐标
3. 用地图像素转 ROS 坐标公式，得到 mapX/mapY
4. 根据用户选择的方向，计算 yaw
5. 发布 /goal_pose
```

发布的 ROS topic：

```text
/goal_pose
```

消息类型：

```text
geometry_msgs/msg/PoseStamped
```

示例结构：

```json
{
  "header": {
    "frame_id": "map"
  },
  "pose": {
    "position": {
      "x": -1.2,
      "y": -0.4,
      "z": 0.0
    },
    "orientation": {
      "x": 0.0,
      "y": 0.0,
      "z": 0.0,
      "w": 1.0
    }
  }
}
```

其中 orientation 由 yaw 转 quaternion。

二维导航只需要绕 z 轴旋转：

```text
z = sin(yaw / 2)
w = cos(yaw / 2)
```

## App 设置小车初始位置

小车刚启动或 AMCL 未收敛时，需要用户设置初始位置。

流程和设置目标类似：

```text
1. 用户选择 Start 模式
2. 点击地图上的小车真实位置
3. 调整车头方向 yaw
4. 发布 /initialpose
5. 等待 /scan 和地图墙体基本重合
6. 粒子云收敛后再允许导航
```

发布的 ROS topic：

```text
/initialpose
```

消息类型：

```text
geometry_msgs/msg/PoseWithCovarianceStamped
```

关键字段：

```text
header.frame_id = map
pose.pose.position.x = mapX
pose.pose.position.y = mapY
pose.pose.orientation = yaw quaternion
pose.covariance = 36 个数字
```

建议协方差：

```text
x/y 方差可设置为 0.25 左右
yaw 方差可设置为 0.0685 左右
```

## 显示小车当前位置

小车当前位置来自：

```text
/amcl_pose
```

消息类型：

```text
geometry_msgs/msg/PoseWithCovarianceStamped
```

App 应读取：

```text
position.x
position.y
orientation
```

然后：

```text
1. quaternion 转 yaw
2. ROS 坐标转地图像素
3. 在地图像素位置绘制小车
4. 用 yaw 绘制车头方向
```

## 显示雷达

雷达来自：

```text
/scan
```

消息类型：

```text
sensor_msgs/msg/LaserScan
```

雷达点不能直接画在地图上，需要通过 TF 转换。

需要订阅：

```text
/tf
/tf_static
```

典型 TF 链：

```text
map -> odom -> base_footprint -> base_link -> laser
```

流程：

```text
1. 根据 /scan 的 angle_min、angle_increment、ranges 计算 laser 坐标点
2. 用 TF 把 laser 坐标点转换到 map 坐标系
3. 用 ROS 坐标转地图像素公式绘制
```

如果雷达点和地图墙体明显不重合，说明小车定位不准，不建议导航。

## 显示路径和 costmap

全局路径：

```text
/plan
```

局部路径：

```text
/local_plan
```

路径消息中的每个 pose 都是 ROS 坐标，需要逐点转换成地图像素。

global costmap：

```text
/global_costmap/costmap
```

local costmap：

```text
/local_costmap/costmap
```

costmap 本身也是 OccupancyGrid，有自己的：

```text
width
height
resolution
origin
```

显示 costmap 时，不要简单铺满整张地图。应使用 costmap 的 origin 和 resolution，把它放到地图对应位置。

左上角计算方式：

```text
topLeftMapX = costmap.origin.x
topLeftMapY = costmap.origin.y + costmap.height * costmap.resolution
```

再用 ROS 坐标转地图像素公式转换为屏幕上的左上角。

## 总控需要的坐标

如果要把小车位置传给总控，不要传屏幕像素坐标。

建议传 ROS map 坐标：

```json
{
  "robotId": "yahboom-x3-001",
  "mapId": "yahboomcar",
  "frameId": "map",
  "x": -1.2,
  "y": -0.4,
  "yaw": 1.57,
  "stamp": 1783930980.29,
  "source": "amcl_pose"
}
```

同时总控必须知道地图元数据：

```json
{
  "mapId": "yahboomcar",
  "width": 864,
  "height": 896,
  "resolution": 0.05,
  "origin": [-22.8, -22.8, 0.0],
  "frameId": "map"
}
```

总控显示地图时，再用同样公式把 ROS 坐标转成像素。

## 导航前的定位检查

不要只要能发 `/goal_pose` 就开始导航。

建议 App 在允许 Navigate 前检查：

```text
1. 已经收到 /map
2. 已经收到 /amcl_pose
3. 已经收到 /scan
4. /scan 与地图墙体大致重合
5. /particlecloud 粒子云已收敛
6. 用户已确认 Start 初始位置
```

如果定位不准，Nav2 会基于错误位置规划，表现为：

```text
路线跳动
小车乱转
costmap 出现在地图外侧
导航目标方向异常
```

## 当前 Flutter 代码中的对应工具

当前代码已有转换工具：

```text
lib/features/inspection_map/utils/coordinate_converter.dart
```

核心函数：

```text
pixelToMap(pixelX, pixelY, mapInfo)
mapToPixel(mapX, mapY, mapInfo)
```

后续 App 开发应复用这两个函数，不要在页面里重新写一套坐标转换公式。

