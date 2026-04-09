# 老人端与统一登录协作说明

## 当前使用方式

- 登录：使用统一登录页
- 老人注册：使用老人端自己的 `ElderRegisterPage`
- 登录成功后：进入老人端首页承接页 `ElderHomePage`

---

## 我这边已整理好的老人端页面

### 老人注册承接页
- `mobile/lib/features/elder/presentation/elder_register_page.dart`

### 老人认领确认页
- `mobile/lib/features/elder/presentation/elder_claim_page.dart`

### 老人首页承接页
- `mobile/lib/features/elder/presentation/elder_home_page.dart`

### 家属绑定详情页
- `mobile/lib/features/elder/presentation/elder_binding_status_page.dart`

### 老人端路由常量
- `mobile/lib/features/elder/elder_module_routes.dart`

---

## 老人端当前内部流程

### 老人注册
填写手机号和密码后，系统会继续执行：
- 资料识别
- 若识别到已有老人资料，则进入认领确认
- 若没有已有资料，则直接进入老人首页

### 老人登录成功后
统一登录侧只要把老人用户送进老人端首页承接页即可。
老人首页内部可继续进入：
- 家属绑定详情
- 后续更多老人服务页面

---

## 对统一登录同学的要求

### 1. 登录继续走统一登录页
这一点保持不变。

### 2. 老人注册入口请接到老人端注册承接页
不要继续停留在通用老人注册提交逻辑里。

### 3. 老人登录成功后不要再跳旧的 `/home`
当前老人端已经整理出独立首页承接方式，应直接进入老人端首页承接页。

### 4. 子女端逻辑不需要受老人端这边影响
子女注册和子女登录继续按现有方案处理即可。
