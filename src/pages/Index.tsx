import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Bot, Shield, TrendingUp, Users, Mail, Info, LogIn } from "lucide-react";

const Index = () => {
  return (
    <div className="min-h-screen bg-background">
      {/* Navigation Bar */}
      <nav className="sticky top-0 z-50 w-full border-b border-border/40 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="container flex h-16 items-center justify-between">
          <div className="flex items-center gap-2">
            <Bot className="h-8 w-8 text-primary" />
            <span className="text-xl font-bold text-foreground">MoneyX Trading</span>
          </div>
          
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

      {/* Hero Section */}
      <section className="container py-24 text-center">
        <h1 className="text-4xl font-bold tracking-tight text-foreground sm:text-6xl">
          Smart Trading Solutions
        </h1>
        <p className="mx-auto mt-6 max-w-2xl text-lg text-muted-foreground">
          ระบบจัดการ Expert Advisors และ Indicators สำหรับ MetaTrader 5 
          พร้อมระบบ License Management ที่ปลอดภัย
        </p>
        <div className="mt-10 flex items-center justify-center gap-4">
          <Link to="/auth">
            <Button size="lg" className="gap-2">
              <LogIn className="h-5 w-5" />
              เริ่มต้นใช้งาน
            </Button>
          </Link>
          <Link to="/about">
            <Button size="lg" variant="outline">
              เรียนรู้เพิ่มเติม
            </Button>
          </Link>
        </div>
      </section>

      {/* Features Section */}
      <section className="container py-16">
        <div className="grid gap-8 md:grid-cols-3">
          <div className="rounded-lg border border-border bg-card p-6 text-center">
            <TrendingUp className="mx-auto h-12 w-12 text-primary" />
            <h3 className="mt-4 text-xl font-semibold text-card-foreground">
              Expert Advisors
            </h3>
            <p className="mt-2 text-muted-foreground">
              ระบบเทรดอัตโนมัติที่ออกแบบมาเพื่อผลตอบแทนที่ดี
            </p>
          </div>
          
          <div className="rounded-lg border border-border bg-card p-6 text-center">
            <Shield className="mx-auto h-12 w-12 text-primary" />
            <h3 className="mt-4 text-xl font-semibold text-card-foreground">
              License Management
            </h3>
            <p className="mt-2 text-muted-foreground">
              ระบบจัดการ License ที่ปลอดภัยและใช้งานง่าย
            </p>
          </div>
          
          <div className="rounded-lg border border-border bg-card p-6 text-center">
            <Users className="mx-auto h-12 w-12 text-primary" />
            <h3 className="mt-4 text-xl font-semibold text-card-foreground">
              Customer Management
            </h3>
            <p className="mt-2 text-muted-foreground">
              จัดการลูกค้าและบัญชี MT5 ได้อย่างมีประสิทธิภาพ
            </p>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border bg-muted/50">
        <div className="container py-8 text-center text-muted-foreground">
          <p>&copy; 2026 MoneyX Trading. All rights reserved.</p>
        </div>
      </footer>
    </div>
  );
};

export default Index;
