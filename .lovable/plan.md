

## Harmony Dream EA v2.1.9 - Complete

### สิ่งที่แก้ไขแล้ว

| ปัญหา | การแก้ไข |
|-------|----------|
| **Debug Log Spam** | เพิ่ม throttling - แสดง log ครั้งแรก + ทุก 30 วินาที |
| **Order Count ผิด** | ป้องกันการนับ Main order ซ้ำด้วย `mainBuyCounted[]`, `mainSellCounted[]` |

### การเปลี่ยนแปลงหลัก

1. **PairInfo struct** - เพิ่ม `lastBlockReason`, `lastBlockLogTime`
2. **Global variables** - เพิ่ม `g_firstAnalyzeRun`, `DEBUG_LOG_INTERVAL`
3. **OnInit()** - Reset `g_firstAnalyzeRun = true` หลัง restore
4. **RestoreOpenPositions()** - ใช้ array ป้องกันนับ order ซ้ำ
5. **AnalyzeAllPairs()** - Throttle ทุก debug log + reset flag ท้ายฟังก์ชัน

### Version
```cpp
#property version   "2.19"
#property description "v2.1.9: Fix Debug Log Spam + Dashboard Order Count"
```
