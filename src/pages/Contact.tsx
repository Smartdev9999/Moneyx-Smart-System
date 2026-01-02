import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Bot, Mail, Phone, MapPin, ArrowLeft, Info, LogIn } from "lucide-react";
import { useState } from "react";
import { useToast } from "@/hooks/use-toast";

const Contact = () => {
  const { toast } = useToast();
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    
    // Simulate form submission
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    toast({
      title: "ส่งข้อความสำเร็จ",
      description: "เราจะติดต่อกลับโดยเร็วที่สุด",
    });
    
    setIsSubmitting(false);
    (e.target as HTMLFormElement).reset();
  };

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

        <h1 className="text-4xl font-bold text-foreground">Contact Us</h1>
        <p className="mt-4 text-lg text-muted-foreground">
          ติดต่อเราได้ที่ช่องทางด้านล่าง
        </p>

        <div className="mt-12 grid gap-12 lg:grid-cols-2">
          {/* Contact Form */}
          <div className="rounded-lg border border-border bg-card p-8">
            <h2 className="text-2xl font-semibold text-card-foreground">ส่งข้อความถึงเรา</h2>
            
            <form onSubmit={handleSubmit} className="mt-6 space-y-6">
              <div className="space-y-2">
                <Label htmlFor="name">ชื่อ</Label>
                <Input id="name" placeholder="กรอกชื่อของคุณ" required />
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="email">อีเมล</Label>
                <Input id="email" type="email" placeholder="your@email.com" required />
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="subject">หัวข้อ</Label>
                <Input id="subject" placeholder="หัวข้อที่ต้องการติดต่อ" required />
              </div>
              
              <div className="space-y-2">
                <Label htmlFor="message">ข้อความ</Label>
                <Textarea 
                  id="message" 
                  placeholder="รายละเอียดที่ต้องการสอบถาม" 
                  rows={5}
                  required 
                />
              </div>
              
              <Button type="submit" className="w-full" disabled={isSubmitting}>
                {isSubmitting ? "กำลังส่ง..." : "ส่งข้อความ"}
              </Button>
            </form>
          </div>

          {/* Contact Info */}
          <div className="space-y-8">
            <div className="rounded-lg border border-border bg-card p-6">
              <div className="flex items-center gap-4">
                <Mail className="h-8 w-8 text-primary" />
                <div>
                  <h3 className="font-semibold text-card-foreground">Email</h3>
                  <p className="text-muted-foreground">support@moneyx-trading.com</p>
                </div>
              </div>
            </div>
            
            <div className="rounded-lg border border-border bg-card p-6">
              <div className="flex items-center gap-4">
                <Phone className="h-8 w-8 text-primary" />
                <div>
                  <h3 className="font-semibold text-card-foreground">Phone</h3>
                  <p className="text-muted-foreground">+66 XX XXX XXXX</p>
                </div>
              </div>
            </div>
            
            <div className="rounded-lg border border-border bg-card p-6">
              <div className="flex items-center gap-4">
                <MapPin className="h-8 w-8 text-primary" />
                <div>
                  <h3 className="font-semibold text-card-foreground">Address</h3>
                  <p className="text-muted-foreground">Bangkok, Thailand</p>
                </div>
              </div>
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

export default Contact;
