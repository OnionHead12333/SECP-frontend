-- ======================================================
-- 保留现有数据升级到 V14
-- 适用场景：已有 elder 数据库，不想删库重建，也不想执行 initial_v14.sql 的 TRUNCATE。
--
-- 本脚本只做结构补齐：
--   1) 补齐 V14 兴趣社群 / 私聊相关表；
--   2) 补齐 medical_documents 的结构化 OCR 展示字段；
--   3) 不删除表、不清空表、不覆盖现有业务数据。
--
-- 注意：该脚本针对当前已检查到的本机 elder 库差异生成。
-- 如需重复执行，CREATE TABLE IF NOT EXISTS 是安全的；
-- medical_documents 的 ADD COLUMN 在列已存在时会报错，请勿重复执行该段。
-- ======================================================

USE elder;
SET NAMES utf8mb4;

-- 1. 补齐医疗 OCR 归档单据表中缺失的结构化字段
ALTER TABLE medical_documents
  ADD COLUMN structured_error VARCHAR(512) DEFAULT NULL COMMENT '结构化失败原因' AFTER structured_route_source,
  ADD COLUMN display_blocks_json LONGTEXT COMMENT '前端结构化展示块 JSON' AFTER specialized_raw_json,
  ADD COLUMN structured_fields_json LONGTEXT COMMENT '扁平化结构化字段 JSON' AFTER display_blocks_json;

-- 2. 兴趣社群目录（前端 CommunityCatalog）
CREATE TABLE IF NOT EXISTS interest_communities (
  id VARCHAR(32) PRIMARY KEY COMMENT '社群标识，如 taiji/calligraphy/fitness/travel',
  name VARCHAR(64) NOT NULL COMMENT '社群名称',
  short_description VARCHAR(512) NOT NULL COMMENT '简介',
  preview_icon VARCHAR(16) NOT NULL COMMENT '列表图标 emoji',
  member_hint VARCHAR(64) DEFAULT '' COMMENT '成员规模展示文案',
  sort_order INT NOT NULL DEFAULT 0 COMMENT '排序',
  is_active TINYINT(1) NOT NULL DEFAULT 1 COMMENT '是否开放',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  KEY idx_sort_active (sort_order, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='兴趣社群目录表';

-- 2.1 演示群友 / 可发现好友目录（前端 FriendDiscoverCatalog）
CREATE TABLE IF NOT EXISTS community_demo_peer_profiles (
  scope_key VARCHAR(64) PRIMARY KEY COMMENT '演示 scopeKey，如 demo_peer_wang',
  display_name VARCHAR(64) NOT NULL COMMENT '展示姓名',
  phone VARCHAR(20) NOT NULL COMMENT '演示手机号',
  hint VARCHAR(255) DEFAULT '' COMMENT '推荐说明',
  emoji VARCHAR(16) DEFAULT NULL COMMENT '默认头像 emoji',
  linked_elder_profile_id BIGINT DEFAULT NULL COMMENT '若映射真实老人档案',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  UNIQUE KEY uk_demo_peer_phone (phone),
  KEY idx_demo_peer_linked_elder (linked_elder_profile_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='兴趣社群演示群友目录表';

-- 2.2 老人入群记录（前端 CommunityMembershipRepository）
CREATE TABLE IF NOT EXISTS interest_community_memberships (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '成员关系ID',
  elder_profile_id BIGINT NOT NULL COMMENT '老人档案ID（逻辑关联 elder_profiles.id）',
  community_id VARCHAR(32) NOT NULL COMMENT '社群ID（逻辑关联 interest_communities.id）',
  scope_key VARCHAR(64) NOT NULL COMMENT '入群时 scopeKey，如 phone_13800138001',
  status ENUM('active','left') NOT NULL DEFAULT 'active' COMMENT '成员状态',
  joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入群时间',
  left_at DATETIME DEFAULT NULL COMMENT '退群时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  UNIQUE KEY uk_elder_community (elder_profile_id, community_id),
  KEY idx_community_status (community_id, status),
  KEY idx_membership_scope (scope_key),
  KEY idx_membership_elder_status (elder_profile_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='兴趣社群成员关系表';

-- 2.3 群聊消息（对齐 POST/GET .../interest-communities/{id}/messages）
CREATE TABLE IF NOT EXISTS interest_community_messages (
  id VARCHAR(64) PRIMARY KEY COMMENT '消息ID',
  community_id VARCHAR(32) NOT NULL COMMENT '社群ID（逻辑关联 interest_communities.id）',
  sender_scope_key VARCHAR(64) NOT NULL COMMENT '发送者 scopeKey；system 为群助手',
  sender_elder_profile_id BIGINT DEFAULT NULL COMMENT '发送者老人档案ID（系统消息为空）',
  sender_display_name VARCHAR(64) NOT NULL COMMENT '气泡展示名',
  sender_role ENUM('elder','child') NOT NULL DEFAULT 'elder' COMMENT '发送角色',
  message_kind ENUM('voice','text','image') NOT NULL DEFAULT 'text' COMMENT '消息类型：语音/文字/图片',
  text_content TEXT DEFAULT NULL COMMENT '文字内容（kind=text 时）',
  audio_url VARCHAR(512) DEFAULT NULL COMMENT '语音 URL（kind=voice；GET /v1/community-voice/{id}/file）',
  image_url VARCHAR(512) DEFAULT NULL COMMENT '图片 URL（kind=image；GET /v1/community-image/{id}/file）',
  duration_ms INT NOT NULL DEFAULT 0 COMMENT '语音时长毫秒（kind=voice）',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '发送时间',
  KEY idx_comm_msg_community_created (community_id, created_at),
  KEY idx_comm_msg_sender_scope (sender_scope_key),
  KEY idx_comm_msg_sender_elder (sender_elder_profile_id),
  KEY idx_comm_msg_kind (message_kind)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='兴趣社群群聊消息表';

-- 2.4 群聊清空记录（DELETE .../messages 软清空，按查看者 scope 隐藏历史）
CREATE TABLE IF NOT EXISTS interest_community_chat_clear (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '记录ID',
  viewer_scope_key VARCHAR(64) NOT NULL COMMENT '查看者 scopeKey：老人 phone_xxx / 子女 child_preview_{elderScope}',
  viewer_user_id BIGINT DEFAULT NULL COMMENT '操作者 users.id（老人或子女；便于审计）',
  elder_profile_id BIGINT NOT NULL COMMENT '所属老人档案ID（群归属；子女预览时为父母档案）',
  community_id VARCHAR(32) NOT NULL COMMENT '社群ID',
  clear_before_millis BIGINT NOT NULL COMMENT '此时间及前的消息对该查看者不可见（毫秒时间戳）',
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '最近清空时间',
  UNIQUE KEY uk_clear_viewer_community (viewer_scope_key, community_id),
  KEY idx_clear_elder_community (elder_profile_id, community_id),
  KEY idx_clear_viewer_user (viewer_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='兴趣社群群聊清空记录（按用户视角，不删消息行）';

-- 2.5 演示群友消息播种标记（前端 interest_comm_peer_seeded_v1_{communityId}）
CREATE TABLE IF NOT EXISTS community_peer_seed_log (
  community_id VARCHAR(32) PRIMARY KEY COMMENT '社群ID',
  seeded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '播种时间'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='兴趣社群演示消息播种记录表';

-- 2.6 老人好友（前端 CommunityFriendRepository，单向通讯录）
CREATE TABLE IF NOT EXISTS elder_friends (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '好友记录ID',
  owner_elder_profile_id BIGINT NOT NULL COMMENT '好友列表拥有者档案ID',
  owner_scope_key VARCHAR(64) NOT NULL COMMENT '拥有者 scopeKey',
  friend_scope_key VARCHAR(64) NOT NULL COMMENT '好友 scopeKey',
  friend_elder_profile_id BIGINT DEFAULT NULL COMMENT '好友档案ID（若已注册）',
  display_name VARCHAR(64) NOT NULL COMMENT '展示姓名',
  phone VARCHAR(20) NOT NULL COMMENT '手机号',
  hint VARCHAR(255) DEFAULT '' COMMENT '来源说明',
  emoji VARCHAR(16) DEFAULT '👤' COMMENT '默认头像 emoji',
  added_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '添加时间',
  UNIQUE KEY uk_owner_friend_scope (owner_elder_profile_id, friend_scope_key),
  UNIQUE KEY uk_owner_friend_phone (owner_elder_profile_id, phone),
  KEY idx_friends_owner_added (owner_elder_profile_id, added_at),
  KEY idx_friends_friend_scope (friend_scope_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='老人好友表';

-- 2.7 一对一私聊线程（前端 CommunityDirectRepository 线程键）
CREATE TABLE IF NOT EXISTS direct_message_threads (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '私聊线程ID',
  participant_a_scope_key VARCHAR(64) NOT NULL COMMENT '字典序较小 scopeKey',
  participant_b_scope_key VARCHAR(64) NOT NULL COMMENT '字典序较大 scopeKey',
  participant_a_elder_profile_id BIGINT DEFAULT NULL COMMENT '参与者 A 档案ID',
  participant_b_elder_profile_id BIGINT DEFAULT NULL COMMENT '参与者 B 档案ID',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '最近消息时间',
  UNIQUE KEY uk_direct_thread_participants (participant_a_scope_key, participant_b_scope_key),
  KEY idx_direct_thread_a (participant_a_elder_profile_id),
  KEY idx_direct_thread_b (participant_b_elder_profile_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='老人一对一私聊线程表';

-- 2.8 私聊消息（message_kind 与群聊对齐，便于后续扩展图片）
CREATE TABLE IF NOT EXISTS direct_messages (
  id VARCHAR(64) PRIMARY KEY COMMENT '消息ID',
  thread_id BIGINT NOT NULL COMMENT '线程ID（逻辑关联 direct_message_threads.id）',
  sender_scope_key VARCHAR(64) NOT NULL COMMENT '发送者 scopeKey',
  sender_elder_profile_id BIGINT DEFAULT NULL COMMENT '发送者档案ID',
  sender_display_name VARCHAR(64) NOT NULL COMMENT '展示姓名',
  sender_role ENUM('elder','child') NOT NULL DEFAULT 'elder' COMMENT '发送角色',
  message_kind ENUM('voice','text','image') NOT NULL DEFAULT 'voice' COMMENT '消息类型',
  text_content TEXT DEFAULT NULL COMMENT '文字内容',
  audio_url VARCHAR(512) DEFAULT NULL COMMENT '语音文件 URL',
  image_url VARCHAR(512) DEFAULT NULL COMMENT '图片 URL',
  duration_ms INT NOT NULL DEFAULT 0 COMMENT '语音时长毫秒',
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '发送时间',
  KEY idx_direct_msg_thread_created (thread_id, created_at),
  KEY idx_direct_msg_sender_scope (sender_scope_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='老人一对一私聊消息表';

-- 2.9 私聊清空记录（DELETE .../messages 软清空，按查看者 scope 隐藏历史）
CREATE TABLE IF NOT EXISTS direct_message_clear (
  id BIGINT PRIMARY KEY AUTO_INCREMENT COMMENT '清空记录ID',
  thread_id BIGINT NOT NULL COMMENT '线程ID（逻辑关联 direct_message_threads.id）',
  scope_key VARCHAR(64) NOT NULL COMMENT '执行清空的用户 scopeKey',
  elder_profile_id BIGINT DEFAULT NULL COMMENT '执行清空的老人档案ID',
  clear_before_millis BIGINT NOT NULL COMMENT '清空该时刻及前的消息（毫秒时间戳）',
  updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '最近清空时间',
  UNIQUE KEY uk_thread_scope (thread_id, scope_key),
  KEY idx_updated_at (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='老人一对一私聊清空记录（按用户视角，不删消息行）';
