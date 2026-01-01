import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AuthProvider } from "@/hooks/useAuth";
import Index from "./pages/Index";
import TradingBotGuide from "./pages/TradingBotGuide";
import MT5EAGuide from "./pages/MT5EAGuide";
import MT5IndicatorGuide from "./pages/MT5IndicatorGuide";
import Auth from "./pages/Auth";
import Admin from "./pages/Admin";
import Customers from "./pages/admin/Customers";
import NewCustomer from "./pages/admin/NewCustomer";
import CustomerDetail from "./pages/admin/CustomerDetail";
import NotFound from "./pages/NotFound";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <AuthProvider>
        <Toaster />
        <Sonner />
        <BrowserRouter>
          <Routes>
            <Route path="/" element={<Index />} />
            <Route path="/trading-bot-guide" element={<TradingBotGuide />} />
            <Route path="/mt5-ea-guide" element={<MT5EAGuide />} />
            <Route path="/mt5-indicator-guide" element={<MT5IndicatorGuide />} />
            <Route path="/auth" element={<Auth />} />
            <Route path="/admin" element={<Admin />} />
            <Route path="/admin/customers" element={<Customers />} />
            <Route path="/admin/customers/new" element={<NewCustomer />} />
            <Route path="/admin/customers/:id" element={<CustomerDetail />} />
            {/* ADD ALL CUSTOM ROUTES ABOVE THE CATCH-ALL "*" ROUTE */}
            <Route path="*" element={<NotFound />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
