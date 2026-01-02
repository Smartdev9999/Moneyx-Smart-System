import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Bot, Target, Users, Award, ArrowLeft, Mail, Info, LogIn } from "lucide-react";

const About = () => {
  return (
    <div className="min-h-screen bg-background">
      {/* Navigation Bar */}
      <nav className="sticky top-0 z-50 w-full border-b border-border/40 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="container flex h-16 items-center justify-between">
          <Link to="/" className="flex items-center gap-2">
            <Bot className="h-8 w-8 text-primary" />
            <span className="text-xl font-bold text-foreground">MoneyX Trading</span>
          </Link>
          
          <div className="flex items-center gap-4">
            <Link to="/about">
              <Button variant="ghost" className="gap-2">
                <Info className="h-4 w-4" />
                About Us
              </Button>
            </Link>
            <Link to="/contact">
              <Button variant="ghost" className="gap-2">
                <Mail className="h-4 w-4" />
                Contact Us
              </Button>
            </Link>
            <Link to="/auth">
              <Button className="gap-2">
                <LogIn className="h-4 w-4" />
                Login
              </Button>
            </Link>
          </div>
        </div>
      </nav>

      {/* Content */}
      <div className="container py-16">
        <Link to="/">
          <Button variant="ghost" className="mb-8 gap-2">
            <ArrowLeft className="h-4 w-4" />
            กลับหน้าหลัก
          </Button>
        </Link>

        <h1 className="text-4xl font-bold text-foreground">About Us</h1>
        <p className="mt-4 text-lg text-muted-foreground">
          เรียนรู้เพิ่มเติมเกี่ยวกับ MoneyX Trading
        </p>

        {/* Mission & Vision */}
        <div className="mt-12 grid gap-8 md:grid-cols-2">
          <div className="rounded-lg border border-border bg-card p-8">
            <Target className="h-12 w-12 text-primary" />
            <h2 className="mt-4 text-2xl font-semibold text-card-foreground">Mission</h2>
            <p className="mt-4 text-muted-foreground">
              เรามุ่งมั่นที่จะพัฒนาระบบเทรดอัตโนมัติที่มีประสิทธิภาพและเชื่อถือได้ 
              เพื่อช่วยให้นักลงทุนสามารถบริหารพอร์ตการลงทุนได้อย่างมีประสิทธิภาพ
            </p>
          </div>
          
          <div className="rounded-lg border border-border bg-card p-8">
            <Award className="h-12 w-12 text-primary" />
            <h2 className="mt-4 text-2xl font-semibold text-card-foreground">Vision</h2>
            <p className="mt-4 text-muted-foreground">
              เป็นผู้นำด้านการพัฒนา Expert Advisors และเครื่องมือการเทรดสำหรับ MetaTrader 5 
              ที่ได้รับความไว้วางใจจากนักลงทุนทั่วโลก
            </p>
          </div>
        </div>

        {/* Team */}
        <div className="mt-16">
          <h2 className="text-2xl font-semibold text-foreground">Our Team</h2>
          <div className="mt-8 grid gap-6 md:grid-cols-3">
            <div className="rounded-lg border border-border bg-card p-6 text-center">
              <Users className="mx-auto h-16 w-16 text-primary" />
              <h3 className="mt-4 font-semibold text-card-foreground">Development Team</h3>
              <p className="mt-2 text-sm text-muted-foreground">
                ทีมพัฒนาที่มีประสบการณ์ด้าน MQL5 และ Algorithmic Trading
              </p>
            </div>
            
            <div className="rounded-lg border border-border bg-card p-6 text-center">
              <Users className="mx-auto h-16 w-16 text-primary" />
              <h3 className="mt-4 font-semibold text-card-foreground">Support Team</h3>
              <p className="mt-2 text-sm text-muted-foreground">
                ทีมซัพพอร์ตที่พร้อมให้ความช่วยเหลือตลอด 24 ชั่วโมง
              </p>
            </div>
            
            <div className="rounded-lg border border-border bg-card p-6 text-center">
              <Users className="mx-auto h-16 w-16 text-primary" />
              <h3 className="mt-4 font-semibold text-card-foreground">Research Team</h3>
              <p className="mt-2 text-sm text-muted-foreground">
                ทีมวิจัยที่คอยพัฒนากลยุทธ์การเทรดใหม่ๆ อย่างต่อเนื่อง
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Footer */}
      <footer className="border-t border-border bg-muted/50">
        <div className="container py-8 text-center text-muted-foreground">
          <p>&copy; 2026 MoneyX Trading. All rights reserved.</p>
        </div>
      </footer>
    </div>
  );
};

export default About;
