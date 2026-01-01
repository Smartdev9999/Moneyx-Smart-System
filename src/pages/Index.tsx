import { Link } from 'react-router-dom';
import { Layers, Settings2, ArrowDownUp, Palette, RefreshCw, Hash, Code2, ArrowRight, FileCode, TrendingUp } from 'lucide-react';
import ZigZagChart from '@/components/ZigZagChart';
import ParameterCard from '@/components/ParameterCard';
import PatternBadge from '@/components/PatternBadge';
import TradingSignal from '@/components/TradingSignal';

const Index = () => {
  return (
    <div className="min-h-screen bg-background">
      {/* Hero Section */}
      <header className="relative overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-b from-primary/5 via-transparent to-transparent" />
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-primary/10 rounded-full blur-[120px]" />
        
        <div className="container relative pt-16 pb-12">
          <div className="text-center max-w-3xl mx-auto animate-fade-in-up">
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-primary/10 border border-primary/30 mb-6">
              <Layers className="w-4 h-4 text-primary" />
              <span className="text-sm font-mono text-primary">Moneyx Smart System</span>
            </div>
            
            <h1 className="text-4xl md:text-5xl font-bold text-foreground mb-4">
              ZigCycle<span className="text-primary">BarCount</span>
            </h1>
            
            <p className="text-lg text-muted-foreground leading-relaxed">
              Indicator ที่รวม ZigZag กับการนับจำนวนแท่งเทียนระหว่าง Swing Points
              <br />
              ช่วยวิเคราะห์โครงสร้างตลาดและระบุ Higher High, Higher Low, Lower High, Lower Low
            </p>
          </div>
        </div>
      </header>

      {/* Chart Section */}
      <section className="container py-8">
        <div className="glass-card rounded-2xl p-6 animate-fade-in-up" style={{ animationDelay: '0.2s' }}>
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-semibold text-foreground">ตัวอย่าง Chart</h2>
            <div className="flex items-center gap-4 text-sm">
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-bull" />
                <span className="text-muted-foreground">Bullish</span>
              </div>
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-bear" />
                <span className="text-muted-foreground">Bearish</span>
              </div>
            </div>
          </div>
          <ZigZagChart />
        </div>
      </section>

      {/* Parameters Section */}
      <section className="container py-12">
        <h2 className="text-2xl font-bold text-foreground mb-8 text-center">
          พารามิเตอร์หลัก
        </h2>
        
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
          <ParameterCard
            name="Depth"
            value={12}
            description="จำนวนแท่งเทียนที่ใช้คำนวณหา High/Low ค่ายิ่งสูง swing points ยิ่งน้อย"
            icon={<Layers className="w-5 h-5" />}
          />
          <ParameterCard
            name="Deviation"
            value={5}
            description="ค่าเบี่ยงเบนขั้นต่ำ (ใน ticks) ที่จะถือว่าเป็น swing point ใหม่"
            icon={<ArrowDownUp className="w-5 h-5" />}
          />
          <ParameterCard
            name="Backstep"
            value={3}
            description="จำนวนแท่งเทียนย้อนหลังที่ต้องไม่มี swing point เดิม"
            icon={<RefreshCw className="w-5 h-5" />}
          />
          <ParameterCard
            name="Line Thickness"
            value={2}
            description="ความหนาของเส้น ZigZag (1-4)"
            icon={<Settings2 className="w-5 h-5" />}
          />
          <ParameterCard
            name="Bull/Bear Color"
            value="Aqua/Red"
            description="สีของเส้น ZigZag ขาขึ้น (Bull) และขาลง (Bear)"
            icon={<Palette className="w-5 h-5" />}
          />
          <ParameterCard
            name="Bar Count (C)"
            value="Auto"
            description="จำนวนแท่งเทียนระหว่าง swing points ช่วยวัด cycle"
            icon={<Hash className="w-5 h-5" />}
          />
        </div>
      </section>

      {/* Pattern Explanation */}
      <section className="container py-12">
        <h2 className="text-2xl font-bold text-foreground mb-8 text-center">
          รูปแบบโครงสร้างตลาด
        </h2>
        
        <div className="grid md:grid-cols-2 gap-4 max-w-4xl mx-auto">
          <PatternBadge
            pattern="HH"
            description="จุดสูงสุดใหม่สูงกว่าจุดสูงสุดก่อนหน้า → แนวโน้มขาขึ้นแข็งแรง"
          />
          <PatternBadge
            pattern="HL"
            description="จุดต่ำสุดใหม่สูงกว่าจุดต่ำสุดก่อนหน้า → ยืนยันแนวโน้มขาขึ้น"
          />
          <PatternBadge
            pattern="LH"
            description="จุดสูงสุดใหม่ต่ำกว่าจุดสูงสุดก่อนหน้า → เริ่มอ่อนแรง/กลับตัว"
          />
          <PatternBadge
            pattern="LL"
            description="จุดต่ำสุดใหม่ต่ำกว่าจุดต่ำสุดก่อนหน้า → แนวโน้มขาลง"
          />
        </div>
      </section>

      {/* Trading Strategy */}
      <section className="container py-12">
        <h2 className="text-2xl font-bold text-foreground mb-8 text-center">
          วิธีใช้ในการเทรด
        </h2>
        
        <div className="grid md:grid-cols-2 gap-6 max-w-5xl mx-auto">
          <TradingSignal
            type="bullish"
            title="สัญญาณซื้อ (Long)"
            conditions={[
              'เห็น HH ตามด้วย HL → โครงสร้างขาขึ้น',
              'รอ pullback ไปยังบริเวณ HL ก่อนเข้าซื้อ',
              'Bar Count (C) สม่ำเสมอ → cycle ปกติ',
              'ตั้ง Stop Loss ใต้ HL ล่าสุด',
            ]}
          />
          <TradingSignal
            type="bearish"
            title="สัญญาณขาย (Short)"
            conditions={[
              'เห็น LL ตามด้วย LH → โครงสร้างขาลง',
              'รอ bounce ไปยังบริเวณ LH ก่อนเข้าขาย',
              'HH ที่ไม่ผ่านจุดเดิม → อ่อนแรง',
              'ตั้ง Stop Loss เหนือ LH ล่าสุด',
            ]}
          />
        </div>

        {/* Bar Count Usage */}
        <div className="mt-8 max-w-3xl mx-auto">
          <div className="glass-card rounded-xl p-6">
            <h3 className="text-lg font-semibold text-foreground mb-4 flex items-center gap-2">
              <Hash className="w-5 h-5 text-primary" />
              การใช้ Bar Count (C)
            </h3>
            <ul className="space-y-3 text-muted-foreground">
              <li className="flex items-start gap-3">
                <span className="w-6 h-6 rounded-full bg-primary/20 text-primary flex items-center justify-center text-sm font-mono shrink-0">1</span>
                <span><strong className="text-foreground">วัด Cycle:</strong> ถ้า C มีค่าคงที่ (เช่น 4-5 แท่ง) แสดงว่าตลาดมี rhythm ที่สม่ำเสมอ</span>
              </li>
              <li className="flex items-start gap-3">
                <span className="w-6 h-6 rounded-full bg-primary/20 text-primary flex items-center justify-center text-sm font-mono shrink-0">2</span>
                <span><strong className="text-foreground">คาดการณ์:</strong> ใช้ค่าเฉลี่ย C เพื่อคาดเดาเวลาที่จะเกิด swing point ถัดไป</span>
              </li>
              <li className="flex items-start gap-3">
                <span className="w-6 h-6 rounded-full bg-primary/20 text-primary flex items-center justify-center text-sm font-mono shrink-0">3</span>
                <span><strong className="text-foreground">สัญญาณเตือน:</strong> C ที่เปลี่ยนแปลงมาก อาจบ่งบอกการเปลี่ยน momentum</span>
              </li>
            </ul>
          </div>
        </div>
      </section>

      {/* Trading Bot Guide CTA */}
      <section className="container py-12">
        <div className="max-w-3xl mx-auto space-y-4">
          <Link 
            to="/trading-bot-guide"
            className="block glass-card rounded-2xl p-8 border-2 border-primary/30 hover:border-primary/60 transition-all duration-300 group"
          >
            <div className="flex items-center gap-6">
              <div className="p-4 rounded-xl bg-primary/20 text-primary group-hover:scale-110 transition-transform">
                <Code2 className="w-8 h-8" />
              </div>
              <div className="flex-1">
                <h3 className="text-xl font-bold text-foreground mb-2">
                  คู่มือโค้ด Trading Bot ฉบับเต็ม
                </h3>
                <p className="text-muted-foreground">
                  ดูโค้ดทุกขั้นตอนพร้อมคำอธิบายละเอียด สำหรับสร้างระบบเทรดอัตโนมัติ
                </p>
              </div>
              <ArrowRight className="w-6 h-6 text-primary group-hover:translate-x-2 transition-transform" />
            </div>
          </Link>

          <Link 
            to="/mt5-ea-guide"
            className="block glass-card rounded-2xl p-8 border-2 border-cyan-500/30 hover:border-cyan-500/60 transition-all duration-300 group"
          >
            <div className="flex items-center gap-6">
              <div className="p-4 rounded-xl bg-cyan-500/20 text-cyan-400 group-hover:scale-110 transition-transform">
                <FileCode className="w-8 h-8" />
              </div>
              <div className="flex-1">
                <h3 className="text-xl font-bold text-foreground mb-2">
                  Moneyx Smart Gold System (MT5 EA)
                </h3>
                <p className="text-muted-foreground">
                  โค้ด EA ฉบับเต็มสำหรับ MetaTrader 5 พร้อม Dashboard และ Grid Trading
                </p>
              </div>
              <ArrowRight className="w-6 h-6 text-cyan-400 group-hover:translate-x-2 transition-transform" />
            </div>
          </Link>

          <Link 
            to="/mt5-indicator-guide"
            className="block glass-card rounded-2xl p-8 border-2 border-green-500/30 hover:border-green-500/60 transition-all duration-300 group"
          >
            <div className="flex items-center gap-6">
              <div className="p-4 rounded-xl bg-green-500/20 text-green-400 group-hover:scale-110 transition-transform">
                <TrendingUp className="w-8 h-8" />
              </div>
              <div className="flex-1">
                <h3 className="text-xl font-bold text-foreground mb-2">
                  MT5 Indicator (EMA, BB, ZigZag, PA, CDC)
                </h3>
                <p className="text-muted-foreground">
                  รวม 5 Indicators ในตัวเดียว พร้อม Settings เลือกเปิด/ปิดแต่ละตัว
                </p>
              </div>
              <ArrowRight className="w-6 h-6 text-green-400 group-hover:translate-x-2 transition-transform" />
            </div>
          </Link>
        </div>
      </section>

      {/* Alert Conditions */}
      <section className="container py-12 pb-20">
        <h2 className="text-2xl font-bold text-foreground mb-8 text-center">
          Alert Conditions
        </h2>
        
        <div className="grid md:grid-cols-3 gap-4 max-w-4xl mx-auto">
          <div className="glass-card rounded-xl p-5 text-center">
            <div className="w-10 h-10 rounded-full bg-secondary mx-auto mb-3 flex items-center justify-center">
              <RefreshCw className="w-5 h-5 text-muted-foreground" />
            </div>
            <h4 className="font-semibold text-foreground mb-1">Direction Changed</h4>
            <p className="text-sm text-muted-foreground">แจ้งเตือนเมื่อทิศทางเปลี่ยน</p>
          </div>
          <div className="glass-card rounded-xl p-5 text-center border-bull/30 bg-bull/5">
            <div className="w-10 h-10 rounded-full bg-bull/20 mx-auto mb-3 flex items-center justify-center">
              <span className="text-bull text-lg">↑</span>
            </div>
            <h4 className="font-semibold text-bull mb-1">Bullish Direction</h4>
            <p className="text-sm text-muted-foreground">แจ้งเตือนเมื่อเปลี่ยนเป็นขาขึ้น</p>
          </div>
          <div className="glass-card rounded-xl p-5 text-center border-bear/30 bg-bear/5">
            <div className="w-10 h-10 rounded-full bg-bear/20 mx-auto mb-3 flex items-center justify-center">
              <span className="text-bear text-lg">↓</span>
            </div>
            <h4 className="font-semibold text-bear mb-1">Bearish Direction</h4>
            <p className="text-sm text-muted-foreground">แจ้งเตือนเมื่อเปลี่ยนเป็นขาลง</p>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border py-8">
        <div className="container text-center text-sm text-muted-foreground">
          <p>Indicator by © Trader_Morry | Visualization Example</p>
        </div>
      </footer>
    </div>
  );
};

export default Index;
