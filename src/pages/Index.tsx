import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { Button } from "@/components/ui/button";
import { Bot, Shield, TrendingUp, Users, Mail, Info, LogIn } from "lucide-react";
import { ThemeToggle } from "@/components/ThemeToggle";
import { LanguageSwitcher } from "@/components/LanguageSwitcher";

const Index = () => {
  const { t } = useTranslation();
  
  return (
    <div className="min-h-screen bg-background">
      {/* Navigation Bar */}
      <nav className="sticky top-0 z-50 w-full border-b border-border/40 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="container flex h-16 items-center justify-between">
          <div className="flex items-center gap-2">
            <Bot className="h-8 w-8 text-primary" />
            <span className="text-xl font-bold text-foreground">MoneyX Trading</span>
          </div>
          
          <div className="flex items-center gap-2">
            <Link to="/about">
              <Button variant="ghost" className="gap-2">
                <Info className="h-4 w-4" />
                <span className="hidden sm:inline">{t('nav.about')}</span>
              </Button>
            </Link>
            <Link to="/contact">
              <Button variant="ghost" className="gap-2">
                <Mail className="h-4 w-4" />
                <span className="hidden sm:inline">{t('nav.contact')}</span>
              </Button>
            </Link>
            <LanguageSwitcher />
            <ThemeToggle />
            <Link to="/auth">
              <Button className="gap-2">
                <LogIn className="h-4 w-4" />
                <span className="hidden sm:inline">{t('nav.login')}</span>
              </Button>
            </Link>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className="container py-24 text-center">
        <h1 className="text-4xl font-bold tracking-tight text-foreground sm:text-6xl">
          {t('index.title')}
        </h1>
        <p className="mx-auto mt-6 max-w-2xl text-lg text-muted-foreground">
          {t('index.subtitle')}
        </p>
        <div className="mt-10 flex items-center justify-center gap-4">
          <Link to="/auth">
            <Button size="lg" className="gap-2">
              <LogIn className="h-5 w-5" />
              {t('nav.getStarted')}
            </Button>
          </Link>
          <Link to="/about">
            <Button size="lg" variant="outline">
              {t('nav.learnMore')}
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
              {t('index.feature1Title')}
            </h3>
            <p className="mt-2 text-muted-foreground">
              {t('index.feature1Desc')}
            </p>
          </div>
          
          <div className="rounded-lg border border-border bg-card p-6 text-center">
            <Shield className="mx-auto h-12 w-12 text-primary" />
            <h3 className="mt-4 text-xl font-semibold text-card-foreground">
              {t('index.feature2Title')}
            </h3>
            <p className="mt-2 text-muted-foreground">
              {t('index.feature2Desc')}
            </p>
          </div>
          
          <div className="rounded-lg border border-border bg-card p-6 text-center">
            <Users className="mx-auto h-12 w-12 text-primary" />
            <h3 className="mt-4 text-xl font-semibold text-card-foreground">
              {t('index.feature3Title')}
            </h3>
            <p className="mt-2 text-muted-foreground">
              {t('index.feature3Desc')}
            </p>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border bg-muted/50">
        <div className="container py-8 text-center text-muted-foreground">
          <p>&copy; 2026 {t('index.copyright')}</p>
        </div>
      </footer>
    </div>
  );
};

export default Index;
