/// 主动消息 / 朋友圈规则的执行守卫（纯函数，便于测试）。
library;

/// 判断 [now] 是否处于安静时段 [startHour, endHour)。
/// 支持跨天区间（如 23→7 表示 23:00-次日 7:00）；
/// startHour == endHour 视为无安静时段。
bool isInQuietHours(DateTime now, int startHour, int endHour) {
  if (startHour == endHour) return false;
  final hour = now.hour;
  if (startHour < endHour) {
    return hour >= startHour && hour < endHour;
  }
  // 跨天：startHour <= hour < 24 或 0 <= hour < endHour
  return hour >= startHour || hour < endHour;
}
