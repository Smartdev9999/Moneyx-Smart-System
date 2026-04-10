

## v6.49 — Fix: Broker TP/SL Delay เกิดจาก Sync Data บล็อก OnTick

### สาเหตุจริง

จากภาพ log:
```
17:48:41.530  Order opened: GM_INIT Lots=0.03 Price=4757.71
17:48:41.530  [Sync] Order opened - syncing data...
17:48:43.585  [Sync] Data synced successfully (event: order_open)
17:49:30.691  v6.48 BrokerTP: SET BUY #721680171 TP=4762.71 SL=0.0
```

- เปิดออเดอร์ → `OnTradeTransaction()` ถูกเรียกทันที → `SyncAccountDataWithEvent()` ทำ **blocking HTTP WebRequest** ไปยัง server
- ระหว่าง WebRequest ทำงาน (~2-49 วินาที) → EA ถูกบล็อกทั้งหมด → ไม่มี OnTick ทำงาน → `SyncBrokerTPSL()` ไม่ได้รัน
- พอ sync เสร็จ tick ถัดไปถึงจะ set TP ได้ = **delay ตามเวลาที่ WebRequest ใช้**

### แผนแก้ไข

**หลักการ**: เปลี่ยนจาก sync ทันทีใน `OnTradeTransaction` → เป็น **deferred sync** โดยตั้ง flag ไว้แล้วให้ sync ทำงานท้าย `OnTick()` หลังจาก TP/SL ถูกจัดการเสร็จแล้ว

#### 1. เพิ่ม global variables สำหรับ deferred sync
```cpp
bool g_pendingSyncOrderOpen = false;
bool g_pendingSyncOrderClose = false;
```

#### 2. แก้ `OnTradeTransaction()` — ไม่ sync ทันที แค่ตั้ง flag
```cpp
if(dealEntry == DEAL_ENTRY_IN) {
   g_pendingSyncOrderOpen = true;   // Defer to end of OnTick
}
else if(dealEntry == DEAL_ENTRY_OUT || ...) {
   g_pendingSyncOrderClose = true;  // Defer to end of OnTick
}
```

#### 3. แก้ `OnTick()` — เพิ่ม deferred sync ท้ายสุด (หลัง SyncBrokerTPSL)
```cpp
// === EXISTING: Broker TP/SL sync ===
SyncBrokerTPSL();

// ... existing code ...

// === NEW: Deferred Data Sync (v6.49) — runs AFTER TP/SL is set ===
if(g_pendingSyncOrderOpen) {
   Print("[Sync] Order opened - syncing data...");
   SyncAccountDataWithEvent(SYNC_ORDER_OPEN);
   g_pendingSyncOrderOpen = false;
}
if(g_pendingSyncOrderClose) {
   Print("[Sync] Order closed - syncing data...");
   SyncAccountDataWithEvent(SYNC_ORDER_CLOSE);
   g_pendingSyncOrderClose = false;
}
```

#### 4. Version bump → v6.49

### ผลลัพธ์ที่คาดหวัง
- เปิดออเดอร์ → tick ถัดไป: คำนวณ TP → set TP ทันที → **แล้วค่อย sync** ข้อมูล
- ลำดับใหม่: `Order opened` → `BrokerTP: SET` → `[Sync] syncing data...`
- TP ปรากฏภายใน 1-2 ticks ไม่ต้องรอ HTTP response

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- SyncBrokerTPSL calculation — ไม่แก้
- ข้อมูลที่ sync ยัง sync เหมือนเดิม แค่เปลี่ยนจังหวะ
- v6.37-v6.48 features — ไม่แก้

