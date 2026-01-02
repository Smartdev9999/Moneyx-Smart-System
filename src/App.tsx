import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AuthProvider } from "@/hooks/useAuth";
import Auth from "./pages/Auth";
import Admin from "./pages/Admin";
import Developer from "./pages/Developer";
import MT5EAGuide from "./pages/MT5EAGuide";
import MT5IndicatorGuide from "./pages/MT5IndicatorGuide";
import Customers from "./pages/admin/Customers";
import NewCustomer from "./pages/admin/NewCustomer";
import CustomerDetail from "./pages/admin/CustomerDetail";
import AccountPortfolio from "./pages/admin/AccountPortfolio";
import Accounts from "./pages/admin/Accounts";
import TradingSystems from "./pages/admin/TradingSystems";
import UserManagement from "./pages/admin/UserManagement";
import NotFound from "./pages/NotFound";

const queryClient = new QueryClient();

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <BrowserRouter>
        <AuthProvider>
          <Toaster />
          <Sonner />
          <Routes>
            <Route path="/" element={<Auth />} />
            <Route path="/auth" element={<Auth />} />
            <Route path="/admin" element={<Admin />} />
            <Route path="/admin/customers" element={<Customers />} />
            <Route path="/admin/customers/new" element={<NewCustomer />} />
            <Route path="/admin/customers/:id" element={<CustomerDetail />} />
            <Route path="/admin/accounts" element={<Accounts />} />
            <Route path="/admin/accounts/:id/portfolio" element={<AccountPortfolio />} />
            <Route path="/admin/systems" element={<TradingSystems />} />
            <Route path="/admin/users" element={<UserManagement />} />
            <Route path="/developer" element={<Developer />} />
            <Route path="/mt5-ea-guide" element={<MT5EAGuide />} />
            <Route path="/mt5-indicator-guide" element={<MT5IndicatorGuide />} />
            {/* ADD ALL CUSTOM ROUTES ABOVE THE CATCH-ALL "*" ROUTE */}
            <Route path="*" element={<NotFound />} />
          </Routes>
        </AuthProvider>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
