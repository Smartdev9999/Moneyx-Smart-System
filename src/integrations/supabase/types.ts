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
      mt5_accounts: {
        Row: {
          account_number: string
          balance: number | null
          created_at: string
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
          balance?: number | null
          created_at?: string
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
          balance?: number | null
          created_at?: string
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
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      cleanup_old_history: { Args: never; Returns: undefined }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      is_admin: { Args: { _user_id: string }; Returns: boolean }
    }
    Enums: {
      app_role: "super_admin" | "admin" | "user" | "developer"
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
      app_role: ["super_admin", "admin", "user", "developer"],
    },
  },
} as const
