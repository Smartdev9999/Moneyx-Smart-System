export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.1"
  }
  public: {
    Tables: {
      account_history: {
        Row: {
          balance: number | null
          drawdown: number | null
          equity: number | null
          id: string
          margin_level: number | null
          mt5_account_id: string
          profit_loss: number | null
          recorded_at: string
        }
        Insert: {
          balance?: number | null
          drawdown?: number | null
          equity?: number | null
          id?: string
          margin_level?: number | null
          mt5_account_id: string
          profit_loss?: number | null
          recorded_at?: string
        }
        Update: {
          balance?: number | null
          drawdown?: number | null
          equity?: number | null
          id?: string
          margin_level?: number | null
          mt5_account_id?: string
          profit_loss?: number | null
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "account_history_mt5_account_id_fkey"
            columns: ["mt5_account_id"]
            isOneToOne: false
            referencedRelation: "mt5_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      account_summary: {
        Row: {
          avg_balance: number | null
          avg_drawdown: number | null
          avg_equity: number | null
          created_at: string | null
          id: string
          max_balance: number | null
          min_balance: number | null
          mt5_account_id: string
          summary_date: string
          sync_count: number | null
          total_profit: number | null
        }
        Insert: {
          avg_balance?: number | null
          avg_drawdown?: number | null
          avg_equity?: number | null
          created_at?: string | null
          id?: string
          max_balance?: number | null
          min_balance?: number | null
          mt5_account_id: string
          summary_date: string
          sync_count?: number | null
          total_profit?: number | null
        }
        Update: {
          avg_balance?: number | null
          avg_drawdown?: number | null
          avg_equity?: number | null
          created_at?: string | null
          id?: string
          max_balance?: number | null
          min_balance?: number | null
          mt5_account_id?: string
          summary_date?: string
          sync_count?: number | null
          total_profit?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "account_summary_mt5_account_id_fkey"
            columns: ["mt5_account_id"]
            isOneToOne: false
            referencedRelation: "mt5_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_analysis_cache: {
        Row: {
          analysis_data: Json
          bearish_probability: number | null
          bullish_probability: number | null
          candle_time: string
          confidence: number | null
          created_at: string
          dominant_bias: string | null
          entry_price: number | null
          expires_at: string
          id: string
          key_levels: Json | null
          market_structure: string | null
          patterns: string | null
          reasoning: string | null
          sideways_probability: number | null
          signal: string | null
          stop_loss: number | null
          symbol: string
          take_profit: number | null
          threshold_met: boolean | null
          timeframe: string
          trend: string | null
          trend_daily: string | null
          trend_h4: string | null
        }
        Insert: {
          analysis_data: Json
          bearish_probability?: number | null
          bullish_probability?: number | null
          candle_time: string
          confidence?: number | null
          created_at?: string
          dominant_bias?: string | null
          entry_price?: number | null
          expires_at?: string
          id?: string
          key_levels?: Json | null
          market_structure?: string | null
          patterns?: string | null
          reasoning?: string | null
          sideways_probability?: number | null
          signal?: string | null
          stop_loss?: number | null
          symbol: string
          take_profit?: number | null
          threshold_met?: boolean | null
          timeframe: string
          trend?: string | null
          trend_daily?: string | null
          trend_h4?: string | null
        }
        Update: {
          analysis_data?: Json
          bearish_probability?: number | null
          bullish_probability?: number | null
          candle_time?: string
          confidence?: number | null
          created_at?: string
          dominant_bias?: string | null
          entry_price?: number | null
          expires_at?: string
          id?: string
          key_levels?: Json | null
          market_structure?: string | null
          patterns?: string | null
          reasoning?: string | null
          sideways_probability?: number | null
          signal?: string | null
          stop_loss?: number | null
          symbol?: string
          take_profit?: number | null
          threshold_met?: boolean | null
          timeframe?: string
          trend?: string | null
          trend_daily?: string | null
          trend_h4?: string | null
        }
        Relationships: []
      }
      ai_candle_history: {
        Row: {
          candle_time: string
          close_price: number
          high_price: number
          id: string
          low_price: number
          open_price: number
          recorded_at: string | null
          symbol: string
          timeframe: string
          volume: number | null
        }
        Insert: {
          candle_time: string
          close_price: number
          high_price: number
          id?: string
          low_price: number
          open_price: number
          recorded_at?: string | null
          symbol: string
          timeframe: string
          volume?: number | null
        }
        Update: {
          candle_time?: string
          close_price?: number
          high_price?: number
          id?: string
          low_price?: number
          open_price?: number
          recorded_at?: string | null
          symbol?: string
          timeframe?: string
          volume?: number | null
        }
        Relationships: []
      }
      ai_indicator_history: {
        Row: {
          atr: number | null
          candle_time: string
          created_at: string | null
          ema20: number | null
          ema50: number | null
          id: string
          macd_histogram: number | null
          macd_main: number | null
          macd_signal: number | null
          rsi: number | null
          symbol: string
          timeframe: string
        }
        Insert: {
          atr?: number | null
          candle_time: string
          created_at?: string | null
          ema20?: number | null
          ema50?: number | null
          id?: string
          macd_histogram?: number | null
          macd_main?: number | null
          macd_signal?: number | null
          rsi?: number | null
          symbol: string
          timeframe: string
        }
        Update: {
          atr?: number | null
          candle_time?: string
          created_at?: string | null
          ema20?: number | null
          ema50?: number | null
          id?: string
          macd_histogram?: number | null
          macd_main?: number | null
          macd_signal?: number | null
          rsi?: number | null
          symbol?: string
          timeframe?: string
        }
        Relationships: []
      }
      customer_users: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          created_at: string | null
          customer_id: string
          id: string
          status: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string | null
          customer_id: string
          id?: string
          status?: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string | null
          customer_id?: string
          id?: string
          status?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_users_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: true
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
        ]
      }
      customers: {
        Row: {
          broker: string | null
          created_at: string
          customer_id: string
          email: string
          id: string
          name: string
          notes: string | null
          phone: string | null
          status: string
          updated_at: string
        }
        Insert: {
          broker?: string | null
          created_at?: string
          customer_id: string
          email: string
          id?: string
          name: string
          notes?: string | null
          phone?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          broker?: string | null
          created_at?: string
          customer_id?: string
          email?: string
          id?: string
          name?: string
          notes?: string | null
          phone?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      economic_news_cache: {
        Row: {
          actual: string | null
          country: string
          created_at: string
          event_date: string
          forecast: string | null
          id: string
          impact: string
          previous: string | null
          source: string | null
          title: string
          updated_at: string
        }
        Insert: {
          actual?: string | null
          country: string
          created_at?: string
          event_date: string
          forecast?: string | null
          id?: string
          impact: string
          previous?: string | null
          source?: string | null
          title: string
          updated_at?: string
        }
        Update: {
          actual?: string | null
          country?: string
          created_at?: string
          event_date?: string
          forecast?: string | null
          id?: string
          impact?: string
          previous?: string | null
          source?: string | null
          title?: string
          updated_at?: string
        }
        Relationships: []
      }
      economic_news_metadata: {
        Row: {
          error_message: string | null
          event_count: number | null
          id: string
          last_source: string | null
          last_updated: string
        }
        Insert: {
          error_message?: string | null
          event_count?: number | null
          id?: string
          last_source?: string | null
          last_updated?: string
        }
        Update: {
          error_message?: string | null
          event_count?: number | null
          id?: string
          last_source?: string | null
          last_updated?: string
        }
        Relationships: []
      }
      fund_allocations: {
        Row: {
          allocated_amount: number
          allocation_date: string | null
          current_value: number
          customer_id: string
          id: string
          last_updated: string | null
          mt5_account_id: string | null
          notes: string | null
          profit_loss: number
          roi_percent: number | null
          trading_system_id: string
        }
        Insert: {
          allocated_amount?: number
          allocation_date?: string | null
          current_value?: number
          customer_id: string
          id?: string
          last_updated?: string | null
          mt5_account_id?: string | null
          notes?: string | null
          profit_loss?: number
          roi_percent?: number | null
          trading_system_id: string
        }
        Update: {
          allocated_amount?: number
          allocation_date?: string | null
          current_value?: number
          customer_id?: string
          id?: string
          last_updated?: string | null
          mt5_account_id?: string | null
          notes?: string | null
          profit_loss?: number
          roi_percent?: number | null
          trading_system_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fund_allocations_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fund_allocations_mt5_account_id_fkey"
            columns: ["mt5_account_id"]
            isOneToOne: false
            referencedRelation: "mt5_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fund_allocations_trading_system_id_fkey"
            columns: ["trading_system_id"]
            isOneToOne: false
            referencedRelation: "trading_systems"
            referencedColumns: ["id"]
          },
        ]
      }
      fund_wallets: {
        Row: {
          created_at: string | null
          customer_id: string
          id: string
          is_active: boolean | null
          label: string | null
          last_sync: string | null
          network: string
          updated_at: string | null
          wallet_address: string
        }
        Insert: {
          created_at?: string | null
          customer_id: string
          id?: string
          is_active?: boolean | null
          label?: string | null
          last_sync?: string | null
          network: string
          updated_at?: string | null
          wallet_address: string
        }
        Update: {
          created_at?: string | null
          customer_id?: string
          id?: string
          is_active?: boolean | null
          label?: string | null
          last_sync?: string | null
          network?: string
          updated_at?: string | null
          wallet_address?: string
        }
        Relationships: [
          {
            foreignKeyName: "fund_wallets_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
        ]
      }
      mt5_accounts: {
        Row: {
          account_number: string
          account_type: string | null
          balance: number | null
          created_at: string
          currency: string | null
          customer_id: string
          drawdown: number | null
          ea_status: string | null
          equity: number | null
          expiry_date: string | null
          floating_pl: number | null
          id: string
          initial_balance: number | null
          is_lifetime: boolean
          last_sync: string | null
          loss_trades: number | null
          margin_level: number | null
          max_drawdown: number | null
          open_orders: number | null
          package_type: string
          profit_loss: number | null
          start_date: string
          status: string
          total_deposit: number | null
          total_profit: number | null
          total_trades: number | null
          total_withdrawal: number | null
          trading_system_id: string | null
          updated_at: string
          win_trades: number | null
        }
        Insert: {
          account_number: string
          account_type?: string | null
          balance?: number | null
          created_at?: string
          currency?: string | null
          customer_id: string
          drawdown?: number | null
          ea_status?: string | null
          equity?: number | null
          expiry_date?: string | null
          floating_pl?: number | null
          id?: string
          initial_balance?: number | null
          is_lifetime?: boolean
          last_sync?: string | null
          loss_trades?: number | null
          margin_level?: number | null
          max_drawdown?: number | null
          open_orders?: number | null
          package_type: string
          profit_loss?: number | null
          start_date?: string
          status?: string
          total_deposit?: number | null
          total_profit?: number | null
          total_trades?: number | null
          total_withdrawal?: number | null
          trading_system_id?: string | null
          updated_at?: string
          win_trades?: number | null
        }
        Update: {
          account_number?: string
          account_type?: string | null
          balance?: number | null
          created_at?: string
          currency?: string | null
          customer_id?: string
          drawdown?: number | null
          ea_status?: string | null
          equity?: number | null
          expiry_date?: string | null
          floating_pl?: number | null
          id?: string
          initial_balance?: number | null
          is_lifetime?: boolean
          last_sync?: string | null
          loss_trades?: number | null
          margin_level?: number | null
          max_drawdown?: number | null
          open_orders?: number | null
          package_type?: string
          profit_loss?: number | null
          start_date?: string
          status?: string
          total_deposit?: number | null
          total_profit?: number | null
          total_trades?: number | null
          total_withdrawal?: number | null
          trading_system_id?: string | null
          updated_at?: string
          win_trades?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "mt5_accounts_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "mt5_accounts_trading_system_id_fkey"
            columns: ["trading_system_id"]
            isOneToOne: false
            referencedRelation: "trading_systems"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          email: string | null
          full_name: string | null
          id: string
          updated_at: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          email?: string | null
          full_name?: string | null
          id: string
          updated_at?: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          email?: string | null
          full_name?: string | null
          id?: string
          updated_at?: string
        }
        Relationships: []
      }
      tracked_ea_sessions: {
        Row: {
          account_number: string | null
          broker: string | null
          created_at: string
          ea_magic_number: number
          end_time: string | null
          generated_ea_code: string | null
          id: string
          last_heartbeat: string | null
          notes: string | null
          session_name: string
          start_time: string | null
          status: string
          strategy_prompt: string | null
          strategy_summary: string | null
          symbols: string[] | null
          timeframe: string | null
          total_orders: number | null
        }
        Insert: {
          account_number?: string | null
          broker?: string | null
          created_at?: string
          ea_magic_number?: number
          end_time?: string | null
          generated_ea_code?: string | null
          id?: string
          last_heartbeat?: string | null
          notes?: string | null
          session_name: string
          start_time?: string | null
          status?: string
          strategy_prompt?: string | null
          strategy_summary?: string | null
          symbols?: string[] | null
          timeframe?: string | null
          total_orders?: number | null
        }
        Update: {
          account_number?: string | null
          broker?: string | null
          created_at?: string
          ea_magic_number?: number
          end_time?: string | null
          generated_ea_code?: string | null
          id?: string
          last_heartbeat?: string | null
          notes?: string | null
          session_name?: string
          start_time?: string | null
          status?: string
          strategy_prompt?: string | null
          strategy_summary?: string | null
          symbols?: string[] | null
          timeframe?: string | null
          total_orders?: number | null
        }
        Relationships: []
      }
      tracked_orders: {
        Row: {
          close_price: number | null
          close_time: string | null
          comment: string | null
          commission: number | null
          created_at: string
          event_type: string
          holding_time_seconds: number | null
          id: string
          magic_number: number | null
          market_data: Json | null
          open_price: number | null
          open_time: string | null
          order_type: string
          profit: number | null
          session_id: string
          sl: number | null
          swap: number | null
          symbol: string
          ticket: number
          tp: number | null
          volume: number | null
        }
        Insert: {
          close_price?: number | null
          close_time?: string | null
          comment?: string | null
          commission?: number | null
          created_at?: string
          event_type?: string
          holding_time_seconds?: number | null
          id?: string
          magic_number?: number | null
          market_data?: Json | null
          open_price?: number | null
          open_time?: string | null
          order_type: string
          profit?: number | null
          session_id: string
          sl?: number | null
          swap?: number | null
          symbol: string
          ticket: number
          tp?: number | null
          volume?: number | null
        }
        Update: {
          close_price?: number | null
          close_time?: string | null
          comment?: string | null
          commission?: number | null
          created_at?: string
          event_type?: string
          holding_time_seconds?: number | null
          id?: string
          magic_number?: number | null
          market_data?: Json | null
          open_price?: number | null
          open_time?: string | null
          order_type?: string
          profit?: number | null
          session_id?: string
          sl?: number | null
          swap?: number | null
          symbol?: string
          ticket?: number
          tp?: number | null
          volume?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "tracked_orders_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "tracked_ea_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      trade_history: {
        Row: {
          close_price: number | null
          close_time: string | null
          comment: string | null
          commission: number | null
          created_at: string
          deal_ticket: number
          deal_type: string
          entry_type: string
          id: string
          magic_number: number | null
          mt5_account_id: string
          open_price: number | null
          open_time: string | null
          order_ticket: number | null
          profit: number | null
          sl: number | null
          swap: number | null
          symbol: string
          tp: number | null
          volume: number | null
        }
        Insert: {
          close_price?: number | null
          close_time?: string | null
          comment?: string | null
          commission?: number | null
          created_at?: string
          deal_ticket: number
          deal_type: string
          entry_type: string
          id?: string
          magic_number?: number | null
          mt5_account_id: string
          open_price?: number | null
          open_time?: string | null
          order_ticket?: number | null
          profit?: number | null
          sl?: number | null
          swap?: number | null
          symbol: string
          tp?: number | null
          volume?: number | null
        }
        Update: {
          close_price?: number | null
          close_time?: string | null
          comment?: string | null
          commission?: number | null
          created_at?: string
          deal_ticket?: number
          deal_type?: string
          entry_type?: string
          id?: string
          magic_number?: number | null
          mt5_account_id?: string
          open_price?: number | null
          open_time?: string | null
          order_ticket?: number | null
          profit?: number | null
          sl?: number | null
          swap?: number | null
          symbol?: string
          tp?: number | null
          volume?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "trade_history_mt5_account_id_fkey"
            columns: ["mt5_account_id"]
            isOneToOne: false
            referencedRelation: "mt5_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      trading_systems: {
        Row: {
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          name: string
          updated_at: string
          version: string | null
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name: string
          updated_at?: string
          version?: string | null
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name?: string
          updated_at?: string
          version?: string | null
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          created_at: string
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
      wallet_transactions: {
        Row: {
          amount: number
          block_time: string
          classification: string | null
          classified_at: string | null
          classified_by: string | null
          created_at: string | null
          from_address: string | null
          id: string
          notes: string | null
          raw_data: Json | null
          target_system_id: string | null
          to_address: string | null
          token_symbol: string | null
          tx_hash: string
          tx_type: string
          wallet_id: string
        }
        Insert: {
          amount: number
          block_time: string
          classification?: string | null
          classified_at?: string | null
          classified_by?: string | null
          created_at?: string | null
          from_address?: string | null
          id?: string
          notes?: string | null
          raw_data?: Json | null
          target_system_id?: string | null
          to_address?: string | null
          token_symbol?: string | null
          tx_hash: string
          tx_type: string
          wallet_id: string
        }
        Update: {
          amount?: number
          block_time?: string
          classification?: string | null
          classified_at?: string | null
          classified_by?: string | null
          created_at?: string | null
          from_address?: string | null
          id?: string
          notes?: string | null
          raw_data?: Json | null
          target_system_id?: string | null
          to_address?: string | null
          token_symbol?: string | null
          tx_hash?: string
          tx_type?: string
          wallet_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "wallet_transactions_target_system_id_fkey"
            columns: ["target_system_id"]
            isOneToOne: false
            referencedRelation: "trading_systems"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_transactions_wallet_id_fkey"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "fund_wallets"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      cleanup_old_candle_data: { Args: never; Returns: undefined }
      cleanup_old_history: { Args: never; Returns: undefined }
      get_customer_id_for_user: { Args: { _user_id: string }; Returns: string }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      is_admin: { Args: { _user_id: string }; Returns: boolean }
      is_approved_customer: { Args: { _user_id: string }; Returns: boolean }
      is_customer: { Args: { _user_id: string }; Returns: boolean }
    }
    Enums: {
      app_role: "super_admin" | "admin" | "user" | "developer" | "customer"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["super_admin", "admin", "user", "developer", "customer"],
    },
  },
} as const
