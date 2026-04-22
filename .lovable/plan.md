

## v6.62 — Fix: Hedge Comment Filter ใช้ Prefix ผิด ทำให้ Sequential Gate พัง

### Root Cause (จาก screenshot)

ใน screenshot เห็น hedge comment จริงคือ **`GM_HEDGE_6`** (ไม่ใช่ `GM_HD6` ตามที่แผน v6.60/v6.61 สมมติไว้):

```
Ticket 1250  buy  0.05  GM_HEDGE_6   ← hedge order จริง
Ticket 39    buy  0.05  GM_INIT      ← Gen 0 init (bound)
Ticket 277   buy  0.05  GM1_INIT     ← Gen 1 init
Ticket 1132  sell 0.05  GM3_INIT     ← Gen 3 init
...
```

**บั๊กที่เกิด** — ใน `GetSequentialAllowedGeneration()` v6.61:

```cpp
if(StringFind(c, "GM_HD") != 0) continue;   // ← BUG: "GM_HEDGE_6" ก็ขึ้นต้น "GM_HD" → ไม่ continue!
int gen = ParseGenerationFromComment(c);
```

`StringFind("GM_HEDGE_6", "GM_HD") == 0` → true → ผ่าน filter → ParseGen เข้า branch `GM_HD<n>` → `StringSubstr("GM_HEDGE_6", 5)` = `"EDGE_6"` → `StringToInteger("EDGE_6")` = 0 → คืน gen = -1 (เพราะ n < 1)

ผลลัพธ์: ไม่มี hedge ตัวไหนถูก parse สำเร็จ → `oldest = INT_MAX` → return -1 → **gate ถูกปิด** → ทุก hedge set ทำงานพร้อมกัน → user เห็น "ปิดหลาย Hedging set พร้อมกัน"

### แก้ไข

เปลี่ยน prefix ที่ใช้ใน filter + parser จาก `"GM_HD"` → **`"GM_HEDGE_"`** (ตรงกับ comment จริงที่ EA สร้าง line 877, 7796)

#### 1. `ParseGenerationFromComment()` (line 7685–7717)

```cpp
// v6.62: Hedge comment ที่แท้จริงคือ "GM_HEDGE_<n>" → gen = n - 1
if(StringFind(c, "GM_HEDGE_") == 0)
{
   string numStr = StringSubstr(c, 9);   // ตัด "GM_HEDGE_"
   int n = (int)StringToInteger(numStr);
   if(n >= 1) return n - 1;
   return -1;
}
```

(ลบ branch `GM_HD` เก่าออก เพราะไม่มี comment แบบนั้นจริงในระบบ)

#### 2. `GetSequentialAllowedGeneration()` (line 7728–7752)

```cpp
// v6.62: Filter ด้วย hedge prefix จริง
if(StringFind(c, "GM_HEDGE_") != 0) continue;
int gen = ParseGenerationFromComment(c);
if(gen >= 0 && gen < oldest) oldest = gen;
```

#### 3. Dashboard label (line 4217)

```cpp
+ " (GM_HEDGE_" + IntegerToString(allowedGen + 1) + ")"
```

#### 4. Version bump → v6.62 (`#property version`, header, dashboard)

#### 5. อัปเดต `.lovable/plan.md` + memory note

### พฤติกรรมหลังแก้

จาก state ใน screenshot (hedge เดียว = `GM_HEDGE_6`, gen 5):

- `GetSequentialAllowedGeneration()` → scan → เจอ `GM_HEDGE_6` → gen 5 → return **5**
- Set#1–#5 (Gen 0–4) จะ freeze → recovery ไม่รัน
- Set#6 (Gen 5, bound = `GM5_*`) เท่านั้นที่รัน matching/recovery
- ปิด Set#6 หมด → ไม่มี hedge เหลือ → return -1 → trading ปกติ

### สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution / Trading Strategy / Entry / Grid distance / Lot calc — ไม่แก้
- License / News / Time / Data Sync — ไม่แก้
- Triple Gate / Hedge open trigger / Matching Pool (v6.60) — ไม่แก้
- Balance Guard / BB Filter — ไม่แก้
- Initial entry ของ cycle gen ใหม่ (v6.59) — ไม่แก้
- `IsHedgeComment()` helper — ไม่แก้
- Hedge slot persistence (v6.68) / commentPrefix format — ไม่แก้
- `ManageHedgeSets()` freeze logic — ไม่แก้ (รับค่า g_seqAllowedGen ที่ถูกต้องแล้ว)
- `ManageOrphanGrid()` gate — ไม่แก้
- v6.37–v6.61 features — ไม่แก้

### ผลลัพธ์

- `GetSequentialAllowedGeneration()` คืน gen ที่ถูกต้องตาม hedge ที่ active จริง
- Sequential Release ทำงานถูกต้อง — **ทีละ hedge set** ตามลำดับ Gen ต่ำ → สูง
- ไม่มีการปิด/recovery หลาย set พร้อมกันอีก
- `InpHedge_SequentialRelease = false` → behavior เดิม 100%

