

## v6.62 — เริ่ม Comment ที่ GM1 + ผูก Hedge ตามรุ่น Bound (GM_Hedge_D{gen})

### สรุปการเปลี่ยนชื่อ Comment

ระบบเดิม (v6.61):
- รุ่นแรกใช้ `GM_INIT`, `GM_GL#1`, ... → รุ่นถัดไปจึงเป็น `GM1_`, `GM2_`
- Hedge ใช้เลข **slot index** (`GM_HEDGE_1`, `GM_HEDGE_D2`) → ไม่ผูกกับรุ่นของ bound group

ระบบใหม่ (v6.62) — ตามที่คุณต้องการ:
- รุ่นแรกใช้ **`GM1_INIT`**, `GM1_GL#1`, ...  → ถัดไป `GM2_`, `GM3_`, ...
- Hedge ผูกกับรุ่นของ bound group:  
  - บล็อก `GM1` → `GM_Hedge_D1` (DD trigger) / `GM_Hedge_E1` (Expansion trigger)  
  - บล็อก `GM2` → `GM_Hedge_D2` / `GM_Hedge_E2`  
  - ฯลฯ
- เมื่อปิดออเดอร์ทั้งหมด → reset กลับไปเริ่มที่ **GM1** วนซ้ำ (ไม่ใช่ GM)

ตัวเลขท้าย Hedge = **boundGeneration ของกลุ่มนั้น**, ไม่ใช่ slot index → ไม่สับสน ไม่เปิดซ้อน

---

### จุดที่ต้องแก้ใน `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1) Version bump → v6.62 (header / `#property` / dashboard / log)

#### 2) เปลี่ยน base generation จาก 0 → 1

| ฟังก์ชัน / ตัวแปร | เดิม | ใหม่ |
|---|---|---|
| `g_cycleGeneration` ค่าเริ่มต้น | `0` | `1` |
| `GenPrefix(0)` | `"GM"` | (ไม่ใช้แล้ว) |
| `GenPrefix(gen)` ทุกค่า | `gen==0?"GM":"GM"+gen` | `"GM" + IntegerToString(gen)` (เริ่มที่ 1 เสมอ) |
| `GetCommentPrefix()` | คืน `"GM"` ตอน gen=0 | คืน `"GM"+gen` เสมอ (ขั้นต่ำ GM1) |
| `ExtractGeneration("GM_...")` (legacy) | คืน 0 | คงไว้เพื่อ backward-compat อ่าน order เก่าได้ — แต่ไม่ใช้สร้างใหม่ |
| `TryResetCycleStateIfFlat()` | ตั้ง `g_cycleGeneration = 0` | ตั้ง `g_cycleGeneration = 1` |
| `RecoverHedgeSets()` flat-branch | reset เป็น 0 | reset เป็น 1 |
| `LoadCycleGeneration()` ตอนยังไม่มีค่า | `-1` | คงเดิม แต่หลัง init ถ้า ≤0 ให้ปรับเป็น 1 |
| `g_cycleGeneration++` (2 จุดในฟังก์ชันเปิด hedge) | คงเดิม | คงเดิม (ตอนนี้จะเริ่มจาก 1 → 2 → 3) |

#### 3) เปลี่ยน Hedge Comment ให้ผูกกับ bound generation

ที่ `OpenHedge()` (บรรทัด ~8273) และ `OpenDDHedge()` (บรรทัด ~8520):

```cpp
// เดิม: string comment = "GM_HEDGE_"  + IntegerToString(slot + 1);
// เดิม: string comment = "GM_HEDGE_D" + IntegerToString(slot + 1);

// ใหม่ v6.62: ผูกกับ bound generation (= g_cycleGeneration ปัจจุบัน ก่อน ++)
int bindGenForComment = g_cycleGeneration;  // จะกลายเป็น boundGeneration ของ set นี้
string comment = "GM_Hedge_E" + IntegerToString(bindGenForComment);  // Expansion trigger
// หรือ
string comment = "GM_Hedge_D" + IntegerToString(bindGenForComment);  // DD trigger
```

→ ผลลัพธ์: บล็อก `GM1_*` ถูกล็อกด้วย `GM_Hedge_D1` หรือ `GM_Hedge_E1` เท่านั้น  
→ บล็อก `GM2_*` ถูกล็อกด้วย `GM_Hedge_D2` หรือ `GM_Hedge_E2` ฯลฯ

#### 4) อัปเดต `IsHedgeComment()` ให้รับชื่อใหม่และเก่า (backward-compat)

```cpp
bool IsHedgeComment(string comment) {
   return (StringFind(comment, "GM_Hedge_")  >= 0   // v6.62 ใหม่ (E/D + gen)
        || StringFind(comment, "GM_HEDGE")   >= 0   // legacy v6.61
        || StringFind(comment, "GM_HG")      >= 0
        || IsReverseHedgeComment(comment));
}
```

#### 5) อัปเดต `RecoverHedgeSets()` (~บรรทัด 8685–8723)

เพิ่ม pattern ใหม่ในการสแกน:
- เดิม: `GM_HEDGE_<slot>` / `GM_HEDGE_D<slot>`
- เพิ่ม: `GM_Hedge_E<gen>` / `GM_Hedge_D<gen>` (v6.62)

วิธี recover slot/boundGeneration จาก comment ใหม่:
- ดึงตัวเลขท้าย → คือ **boundGeneration**
- หา free slot ปกติ → bind boundGeneration ไปยัง slot นั้น
- triggerType: `E` → 0 (Expansion), `D` → 1 (DD)

#### 6) อัปเดตจุดที่กรอง/นับ generation

`CountSequentialOwnerOrders()` (~7517) และทุกจุดที่ทำ:
```cpp
string genPrefix = (gen == 0) ? "GM_" : ("GM" + IntegerToString(gen) + "_");
```
→ เปลี่ยนเป็น:
```cpp
string genPrefix = "GM" + IntegerToString(gen) + "_";  // v6.62: เริ่มที่ GM1 เสมอ
```
(ลบ branch `gen==0` ออก เพราะไม่มีรุ่น 0 อีกต่อไป)

ใน `ExtractGeneration()` คงไว้ตามเดิม → ยังอ่าน `GM_INIT` ของออเดอร์เก่าได้ (คืนค่า 0) → ระบบ recovery ของ generation 0 ที่ค้างจาก v6.61 จะยังถูกจัดการครบก่อน reset

#### 7) Dashboard / Log

- Dashboard แสดง: `Active Cycle: GM1` (แทน `GM`)
- Log เปลี่ยนข้อความ:
  - `v6.62 INIT: Cycle generation starts at GM1`
  - `v6.62 HEDGE OPEN: GM_Hedge_D2 bound to GM2 group (slot=1)`
  - `v6.62 RESET: Account flat → cycleGen back to 1 (GM1)`

#### 8) Migration เคสมีออเดอร์เก่า `GM_*` ค้างอยู่

- ถ้า `RecoverHedgeSets()` พบ `GM_INIT` ออเดอร์เก่า (gen 0) → set `g_cycleGeneration = max(1, recoveredMaxGen)` (กันไม่ให้เริ่มที่ 0 อีก)
- ระหว่างที่ออเดอร์ gen 0 ยังมีอยู่ ระบบ orphan recovery + sequential owner v6.59/v6.60 จะจัดการให้ปิดครบก่อน
- เมื่อ flat → reset → รุ่นถัดไปเริ่ม `GM1` ตามปกติ

---

### สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)

- `trade.Buy / trade.Sell / trade.PositionClose / PositionClosePartial` — ไม่แก้
- Trading strategy, signal, grid logic, TP/SL — ไม่แก้
- `IsHedgeCloseAllowed()` Triple Gate — ไม่แก้
- Sequential owner lock v6.59/v6.60 — ไม่แก้ (แค่ปรับ prefix string)
- Shred/Match/Partial close v6.61 — ไม่แก้ logic, ปรับเฉพาะการอ่าน comment
- Recovery seed registry v6.61 — ไม่แก้
- BB filter v6.56 / IsPrevHedgedTicket v6.58 — ไม่แก้
- License / News / Time filter / Sync — ไม่แก้

### ผลลัพธ์ที่คาดหวัง

1. ออเดอร์ใหม่หลัง init / reset เริ่มต้นที่ `GM1_INIT`, `GM1_GL#1`, ...
2. เมื่อเปิด hedge ของบล็อก GM1 → comment = `GM_Hedge_D1` หรือ `GM_Hedge_E1`
3. ออเดอร์รุ่นถัดไปคือ `GM2_*` พร้อม hedge ของมันเองคือ `GM_Hedge_D2`
4. ไม่มีกรณี `GM_Hedge_*` ตัวเดียวกันถูกมอง bind ผิดบล็อก เพราะเลขท้าย = bound generation จริง
5. ปิดออเดอร์ครบทั้งหมด → reset → รอบใหม่เริ่มที่ `GM1` วนซ้ำตามที่กำหนด
6. ออเดอร์เก่า `GM_*` (ถ้ามีค้าง) ยังถูกจัดการครบก่อน reset (backward-compat)

